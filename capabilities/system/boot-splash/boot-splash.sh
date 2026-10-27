#!/usr/bin/bash
# shellcheck disable=SC2034 # BS_* results are consumed by the system/boot-splash apply that sources this file.
# shellcheck disable=SC2015 # "checks && checks || report" deliberately reports when any of the checks fails.
# Boot-splash helpers local to the system/boot-splash step and sourced by its apply. They recognize the shipped
# MirrorOS boot configuration, derive the bounded Plymouth overlay (a mkinitcpio hook drop-in and the quiet and splash
# kernel parameters), regenerate through the installed native tools, and verify the generated boot artifacts.
#
# Inspected configuration is parsed as data and never sourced. Paths are read and written on the live side through
# cfg_path, so both contexts behave alike; writes go through cfg_run_host. Commands of the installed system (image
# regeneration and listing, tool lookup) go through cfg_run or cfg_exec, inside arch-chroot in target context.
# Nothing here reads /proc/cmdline, restarts a service, reboots, or replaces a boot loader.

readonly BS_THEME=/usr/share/plymouth/themes/mirroros
readonly BS_DAEMON=/etc/plymouth/plymouthd.conf
readonly BS_IMAGE=/usr/share/mirroros/branding/mirroros-symbol.png
readonly BS_MKINITCPIO=/etc/mkinitcpio.conf
readonly BS_DROPINS=/etc/mkinitcpio.conf.d
readonly BS_HOOKS_DROPIN=/etc/mkinitcpio.conf.d/90-mirroros-plymouth.conf
readonly BS_STATE=/var/lib/mirroros/configure/boot-splash.state
# systemd-boot structures written by the installation engine (contracts/installation-engine.md, "Boot").
readonly BS_LOADER=/boot/loader/loader.conf
readonly BS_ENTRY=/boot/loader/entries/mirroros.conf
readonly BS_FALLBACK=/boot/loader/entries/mirroros-fallback.conf
readonly BS_PRESET=/etc/mkinitcpio.d/linux.preset
readonly BS_PRESET_CONTENT='ALL_kver="/boot/vmlinuz-linux"
PRESETS=("default" "fallback")
default_image="/boot/initramfs-linux.img"
fallback_image="/boot/initramfs-linux-fallback.img"
fallback_options="-S autodetect"'
# Limine structures written by the installation engine (contracts/installation-engine.md, "Limine").
readonly BS_LIMINE_DEFAULTS=/etc/default/limine
readonly BS_LIMINE_CONFIG=/boot/limine.conf
readonly BS_LIMINE_DROPIN=/etc/mkinitcpio.conf.d/10-mirroros-limine.conf
readonly BS_LIMINE_HOOKS='HOOKS=(base systemd autodetect microcode modconf kms keyboard sd-vconsole block filesystems sd-btrfs-overlayfs fsck)'
# Entries that only exist in an initramfs built by the plymouth hook with this theme selected.
readonly BS_IMAGE_ENTRIES=(
  usr/lib/plymouth/script.so
  etc/plymouth/plymouthd.conf
  usr/share/plymouth/themes/mirroros/mirroros.plymouth
  usr/share/plymouth/themes/mirroros/mirroros.script
  usr/share/mirroros/branding/mirroros-symbol.png
)

BS_SCHEME=''
BS_HOOKS_LINE=''
BS_CMDLINE=''
BS_NEW_CMDLINE=''

bs_conflict() {
  printf 'Conflict: %s\n' "$*" >&2
  exit 4
}

bs_exists() { [[ -e "$(cfg_path "$1")" || -L "$(cfg_path "$1")" ]]; }
bs_regular() { [[ -f "$(cfg_path "$1")" && ! -L "$(cfg_path "$1")" ]]; }
bs_digest() { sha256sum < "$(cfg_path "$1")" | cut -d' ' -f1; }

# Kernel parameters MirrorOS writes are plain tokens; anything else is not a recognized MirrorOS command line.
bs_tokens_valid() { [[ "$1" =~ ^[A-Za-z0-9_.,:=@/+\ -]+$ ]]; }

bs_count() {
  local words=() word count=0
  read -ra words <<< "$1"
  for word in "${words[@]}"; do [[ "$word" != "$2" ]] || count=$((count + 1)); done
  printf '%s\n' "$count"
}

bs_has_prefix() {
  local words=() word
  read -ra words <<< "$1"
  for word in "${words[@]}"; do [[ "$word" != "$2"* ]] || return 0; done
  return 1
}

# The command line with each missing overlay token appended; every other token keeps its value and position.
bs_with_splash() {
  local tokens="$1" word
  for word in quiet splash; do
    case "$(bs_count "$tokens" "$word")" in
      0) tokens+=" $word" ;;
      1) ;;
      *) return 1 ;;
    esac
  done
  printf '%s\n' "$tokens"
}

bs_without_splash() {
  local words=() word kept=()
  read -ra words <<< "$1"
  for word in "${words[@]}"; do [[ "$word" == quiet || "$word" == splash ]] || kept+=("$word"); done
  printf '%s\n' "${kept[*]}"
}

bs_has_splash() { [[ "$(bs_count "$1" quiet)" == 1 && "$(bs_count "$1" splash)" == 1 ]]; }

bs_scheme() {
  local systemd_boot=0 limine=0
  if bs_exists "$BS_ENTRY" || bs_exists "$BS_LOADER"; then systemd_boot=1; fi
  if bs_exists "$BS_LIMINE_DEFAULTS" || bs_exists "$BS_LIMINE_CONFIG"; then limine=1; fi
  case "$systemd_boot$limine" in
    10) BS_SCHEME=systemd-boot ;;
    01) BS_SCHEME=limine ;;
    11) bs_conflict "both systemd-boot ($BS_LOADER) and Limine ($BS_LIMINE_DEFAULTS) configurations exist; the boot loader is ambiguous. Configure supports only the shipped MirrorOS boot layouts." ;;
    *) bs_conflict "no MirrorOS boot configuration ($BS_ENTRY or $BS_LIMINE_DEFAULTS) was found; configure supports only the shipped MirrorOS boot layouts." ;;
  esac
}

# shellcheck disable=SC2016 # The installed system's Bash resolves its own tool path from the positional argument.
bs_tool() { cfg_exec bash -c 'command -v "$1"' bash "$1" > /dev/null 2>&1; }

bs_require_tools() {
  local tool tools=(mkinitcpio lsinitcpio)
  [[ "$BS_SCHEME" != limine ]] || tools+=(limine-update)
  for tool in "${tools[@]}"; do
    bs_tool "$tool" || bs_conflict "$tool is not installed in the configured system; it is required to rebuild and inspect the boot images."
  done
}

# The ESP holds every boot image and entry; it must be mounted and writable before anything reads or rebuilds them.
bs_esp_ready() {
  local esp
  esp="$(cfg_path /boot)"
  if ! mountpoint -q -- "$esp" || [[ ! -d "$esp" || ! -w "$esp" ]]; then
    printf 'The ESP is not mounted and writable at %s; mount it, then rerun configure.\n' "$esp" >&2
    return 1
  fi
}

# One systemd-boot entry with exactly the engine's four lines; BS_CMDLINE receives its options.
bs_entry_read() {
  local path="$1" title="$2" initrd="$3" lines=()
  bs_regular "$path" || return 1
  mapfile -t lines < "$(cfg_path "$path")"
  (( ${#lines[@]} == 4 )) && [[ "${lines[0]}" == "title $title" && "${lines[1]}" == 'linux /vmlinuz-linux' &&
    "${lines[2]}" == "initrd $initrd" && "${lines[3]}" == options\ * ]] || return 1
  BS_CMDLINE="${lines[3]#options }"
  bs_tokens_valid "$BS_CMDLINE" && bs_has_prefix "$BS_CMDLINE" root=UUID=
}

bs_systemd_boot_inspect() {
  local options
  bs_regular "$BS_LOADER" && grep -qxF 'default mirroros.conf' "$(cfg_path "$BS_LOADER")" ||
    bs_conflict "$BS_LOADER does not select mirroros.conf; it differs from the shipped MirrorOS loader configuration."
  bs_entry_read "$BS_ENTRY" MirrorOS /initramfs-linux.img ||
    bs_conflict "$BS_ENTRY differs from the shipped MirrorOS entry structure; restore it or apply the splash manually."
  options="$BS_CMDLINE"
  BS_NEW_CMDLINE="$(bs_with_splash "$options")" ||
    bs_conflict "$BS_ENTRY repeats quiet or splash; remove the duplicates, then rerun configure."
  if bs_exists "$BS_FALLBACK"; then
    bs_entry_read "$BS_FALLBACK" 'MirrorOS (fallback initramfs)' /initramfs-linux-fallback.img ||
      bs_conflict "$BS_FALLBACK differs from the shipped MirrorOS fallback entry structure."
    # The fallback entry keeps the base command line: it is the menu path that boots without the splash.
    [[ "$BS_CMDLINE" == "$(bs_without_splash "$options")" ]] ||
      bs_conflict "$BS_FALLBACK options differ from the normal entry beyond quiet and splash; restore them, then rerun configure."
  fi
  bs_regular "$BS_PRESET" && [[ "$(< "$(cfg_path "$BS_PRESET")")" == "$BS_PRESET_CONTENT" ]] ||
    bs_conflict "$BS_PRESET differs from the preset written by the MirrorOS installer; restore it, then rerun configure."
  BS_CMDLINE="$options"
}

# Reads /etc/default/limine as data: comments, blank lines and plain KEY=value assignments, ESP_PATH="/boot" and
# exactly one KERNEL_CMDLINE[default]="..." entry. BS_CMDLINE receives that command line.
bs_limine_defaults_read() {
  local line count=0 esp=0 cmdline='^KERNEL_CMDLINE\[default\]="([^"]*)"$' assignment='^[A-Z_][A-Z0-9_]*=[^$`]*$'
  bs_regular "$BS_LIMINE_DEFAULTS" || return 1
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -n "${line//[[:space:]]/}" && ! "$line" =~ ^[[:space:]]*# ]] || continue
    if [[ "$line" =~ $cmdline ]]; then
      BS_CMDLINE="${BASH_REMATCH[1]}"
      count=$((count + 1))
      continue
    fi
    [[ "$line" != *KERNEL_CMDLINE* ]] || return 1
    if [[ "$line" == 'ESP_PATH="/boot"' ]]; then esp=1; continue; fi
    [[ "$line" != ESP_PATH=* && "$line" =~ $assignment ]] || return 1
  done < "$(cfg_path "$BS_LIMINE_DEFAULTS")"
  (( count == 1 && esp == 1 )) && bs_tokens_valid "$BS_CMDLINE" && bs_has_prefix "$BS_CMDLINE" root=UUID= &&
    [[ "$(bs_count "$BS_CMDLINE" rootflags=subvol=@)" == 1 ]]
}

bs_limine_inspect() {
  bs_limine_defaults_read ||
    bs_conflict "$BS_LIMINE_DEFAULTS differs from the shipped MirrorOS structure (ESP_PATH=\"/boot\" and one KERNEL_CMDLINE[default] of plain parameters)."
  BS_NEW_CMDLINE="$(bs_with_splash "$BS_CMDLINE")" ||
    bs_conflict "$BS_LIMINE_DEFAULTS repeats quiet or splash; remove the duplicates, then rerun configure."
  bs_regular "$BS_LIMINE_CONFIG" ||
    bs_conflict "$BS_LIMINE_CONFIG is missing or not a regular file; Limine is not configured as MirrorOS installs it."
}

# A configuration file's single-line HOOKS=(...) assignment, in BS_FOUND (count in BS_FOUND_COUNT). Any other form
# mentioning HOOKS (append, multi-line, expansion) is not recognized.
bs_conf_hooks() {
  local line assignment='^HOOKS=\(([a-z0-9_ -]*)\)[[:space:]]*$'
  BS_FOUND=''
  BS_FOUND_COUNT=0
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line#"${line%%[![:space:]]*}"}"
    [[ -n "$line" && "$line" != \#* && "$line" == *HOOKS* ]] || continue
    [[ "$line" =~ $assignment ]] || return 1
    BS_FOUND="${BASH_REMATCH[1]}"
    BS_FOUND_COUNT=$((BS_FOUND_COUNT + 1))
  done < "$1"
  (( BS_FOUND_COUNT <= 1 ))
}

# The recognized effective hook sequence with plymouth inserted after systemd (or udev) and before filesystems.
bs_hooks_inspect() {
  local base='' file name words=() word anchor='' placed=0 out=() limine_dropin=0
  bs_regular "$BS_MKINITCPIO" && bs_conf_hooks "$(cfg_path "$BS_MKINITCPIO")" && (( BS_FOUND_COUNT == 1 )) ||
    bs_conflict "$BS_MKINITCPIO has no single-line HOOKS=(...) assignment; configure does not guess a hook sequence."
  base="$BS_FOUND"
  if [[ -e "$(cfg_path "$BS_DROPINS")" || -L "$(cfg_path "$BS_DROPINS")" ]]; then
    [[ -d "$(cfg_path "$BS_DROPINS")" && ! -L "$(cfg_path "$BS_DROPINS")" ]] ||
      bs_conflict "$BS_DROPINS is not a directory."
    while IFS= read -r -d '' file; do
      name="${file##*/}"
      [[ "$BS_DROPINS/$name" != "$BS_HOOKS_DROPIN" ]] || continue
      [[ -f "$file" && ! -L "$file" ]] || bs_conflict "$BS_DROPINS/$name is not a regular file."
      if [[ "$BS_SCHEME" == limine && "$BS_DROPINS/$name" == "$BS_LIMINE_DROPIN" ]]; then
        [[ "$(< "$file")" == "$BS_LIMINE_HOOKS" ]] ||
          bs_conflict "$BS_LIMINE_DROPIN differs from the hook drop-in written by the MirrorOS installer."
        base="${BS_LIMINE_HOOKS#HOOKS=(}"
        base="${base%)}"
        limine_dropin=1
        continue
      fi
      bs_conf_hooks "$file" && (( BS_FOUND_COUNT == 0 )) ||
        bs_conflict "$BS_DROPINS/$name overrides HOOKS; configure does not combine unknown hook overrides."
    done < <(find "$(cfg_path "$BS_DROPINS")" -mindepth 1 -maxdepth 1 -name '*.conf' -print0 | sort -z)
  fi
  if [[ "$BS_SCHEME" == limine ]] && (( ! limine_dropin )); then
    bs_conflict "$BS_LIMINE_DROPIN is missing; the Limine hook sequence written by the MirrorOS installer is required."
  fi
  read -ra words <<< "$base"
  [[ "${words[0]:-}" == base ]] || bs_conflict "the hook sequence does not start with base: ${base}"
  for word in "${words[@]}"; do
    [[ "$word" != plymouth ]] || bs_conflict "the hook sequence already lists plymouth outside $BS_HOOKS_DROPIN: ${base}"
    if [[ "$word" == systemd ]]; then anchor=systemd; elif [[ "$word" == udev && -z "$anchor" ]]; then anchor=udev; fi
  done
  [[ -n "$anchor" ]] || bs_conflict "the hook sequence has neither systemd nor udev: ${base}"
  for word in "${words[@]}"; do
    [[ "$word" != filesystems ]] || (( placed )) || bs_conflict "filesystems precedes $anchor in the hook sequence: ${base}"
    out+=("$word")
    if [[ "$word" == "$anchor" ]] && (( ! placed )); then out+=(plymouth); placed=1; fi
  done
  BS_HOOKS_LINE="HOOKS=(${out[*]})"
}

bs_inspect() {
  bs_scheme
  bs_esp_ready || exit 4
  bs_require_tools
  if [[ "$BS_SCHEME" == systemd-boot ]]; then bs_systemd_boot_inspect; else bs_limine_inspect; fi
  bs_hooks_inspect
}

bs_hooks_dropin() {
  printf '# managed by MirrorOS configure\n# The recognized MirrorOS hook sequence with plymouth added for the boot splash (system/boot-splash).\n%s\n' \
    "$BS_HOOKS_LINE" > "$1"
}

# Adds only the missing overlay tokens to the authoritative boot setting; nothing is written when both are present.
bs_cmdline_apply() {
  local file owner group mode new="$CFG_OUTPUT/.boot-splash-cmdline" line cmdline='^KERNEL_CMDLINE\[default\]="'
  [[ "$BS_NEW_CMDLINE" != "$BS_CMDLINE" ]] || return 0
  if [[ "$BS_SCHEME" == systemd-boot ]]; then
    file="$(cfg_path "$BS_ENTRY")"
    printf 'title MirrorOS\nlinux /vmlinuz-linux\ninitrd /initramfs-linux.img\noptions %s\n' "$BS_NEW_CMDLINE" > "$new"
    # The ESP is VFAT: no mode or owner is applied; the replacement is renamed over the entry.
    cfg_run_host cp -- "$new" "$file.mirroros-new"
    cfg_run_host mv -f -- "$file.mirroros-new" "$file"
  else
    file="$(cfg_path "$BS_LIMINE_DEFAULTS")"
    while IFS= read -r line || [[ -n "$line" ]]; do
      if [[ "$line" =~ $cmdline ]]; then line="KERNEL_CMDLINE[default]=\"$BS_NEW_CMDLINE\""; fi
      printf '%s\n' "$line"
    done < "$file" > "$new"
    owner="$(stat -c %u -- "$file")"
    group="$(stat -c %g -- "$file")"
    mode="$(stat -c %a -- "$file")"
    cfg_run_host install -o "$owner" -g "$group" -m "$mode" -- "$new" "$file"
  fi
  rm -f -- "$new"
  BS_CMDLINE="$BS_NEW_CMDLINE"
  cfg_changed
}

# The identity of every managed regeneration input, as delivered.
bs_identity() {
  local path
  {
    printf 'scheme %s\n' "$BS_SCHEME"
    for path in "$BS_THEME/mirroros.plymouth" "$BS_THEME/mirroros.script" "$BS_DAEMON" "$BS_HOOKS_DROPIN" "$BS_IMAGE"; do
      printf '%s %s\n' "$path" "$(bs_digest "$path")"
    done
    printf 'cmdline %s\n' "$BS_NEW_CMDLINE"
  } | sha256sum | cut -d' ' -f1
}

bs_state_is() {
  bs_regular "$BS_STATE" && [[ "$(< "$(cfg_path "$BS_STATE")")" == "$1 $2" ]]
}

bs_state_write() {
  local file="$CFG_OUTPUT/.boot-splash-state"
  printf '%s %s\n' "$1" "$2" > "$file"
  cfg_run_host install -d -m 0755 -- "$(dirname -- "$(cfg_path "$BS_STATE")")"
  cfg_run_host install -o "$(stat -c %u -- "$(cfg_path /)")" -g "$(stat -c %g -- "$(cfg_path /)")" -m 0644 -- \
    "$file" "$(cfg_path "$BS_STATE")"
  rm -f -- "$file"
}

bs_regenerate() {
  if [[ "$BS_SCHEME" == systemd-boot ]]; then
    # The engine's preset regenerates the default image and its existing fallback image.
    cfg_run mkinitcpio -p linux
  else
    # The installed Limine tools rebuild the initramfs and rewrite the normal entries from /etc/default/limine;
    # snapshot entries stay with limine-snapper-sync. Its status alone is not trusted: bs_verify inspects the result.
    cfg_run limine-update
  fi
}

# Normal-entry lines of limine.conf (above //Snapshots), one per line.
bs_limine_normal() {
  local line
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ ! "$line" =~ ^[[:space:]]*//Snapshots[[:space:]]*$ ]] || break
    printf '%s\n' "$line"
  done < "$(cfg_path "$BS_LIMINE_CONFIG")"
}

# The boot images that the normal boot path uses, one absolute installed-system path per line.
bs_images() {
  local line reference found=0 entry='^[[:space:]]*module_path:[[:space:]]*boot\(\):(/[^#[:space:]]+)'
  if [[ "$BS_SCHEME" == systemd-boot ]]; then
    printf '%s\n' /boot/initramfs-linux.img
    if bs_exists "$BS_FALLBACK"; then printf '%s\n' /boot/initramfs-linux-fallback.img; fi
    return 0
  fi
  while IFS= read -r line; do
    if [[ "$line" =~ $entry ]]; then
      reference="${BASH_REMATCH[1]}"
      [[ "$reference" != *..* && "${reference##*/}" == initramfs* ]] || continue
      printf '/boot%s\n' "$reference"
      found=1
    fi
  done < <(bs_limine_normal)
  (( found ))
}

bs_image_has_theme() {
  local image="$1" listing entry
  listing="$(cfg_exec lsinitcpio -l -- "$image" | sed 's#^\./##')" || return 1
  for entry in "${BS_IMAGE_ENTRIES[@]}"; do
    grep -qxF -- "$entry" <<< "$listing" || { printf 'The boot image %s lacks %s.\n' "$image" "$entry" >&2; return 1; }
  done
}

bs_verify_cmdline() {
  local line found=0 reference references=0
  local cmdline='^[[:space:]]*cmdline:[[:space:]]*(.*)$' path='^[[:space:]]*(module_)?path:[[:space:]]*boot\(\):(/[^#[:space:]]+)'
  if [[ "$BS_SCHEME" == systemd-boot ]]; then
    bs_entry_read "$BS_ENTRY" MirrorOS /initramfs-linux.img && bs_has_splash "$BS_CMDLINE" ||
      { printf '%s does not carry quiet and splash exactly once.\n' "$BS_ENTRY" >&2; return 1; }
    if bs_exists "$BS_FALLBACK"; then
      bs_entry_read "$BS_FALLBACK" 'MirrorOS (fallback initramfs)' /initramfs-linux-fallback.img &&
        [[ "$(bs_count "$BS_CMDLINE" splash)" == 0 ]] ||
        { printf '%s is not the no-splash fallback entry.\n' "$BS_FALLBACK" >&2; return 1; }
    fi
    [[ -s "$(cfg_path /boot/vmlinuz-linux)" ]] || { printf 'The kernel /boot/vmlinuz-linux is missing.\n' >&2; return 1; }
    return 0
  fi
  bs_limine_defaults_read && bs_has_splash "$BS_CMDLINE" ||
    { printf '%s does not carry quiet and splash exactly once.\n' "$BS_LIMINE_DEFAULTS" >&2; return 1; }
  while IFS= read -r line; do
    if [[ "$line" =~ $cmdline ]]; then
      found=1
      bs_has_splash "${BASH_REMATCH[1]}" ||
        { printf 'A normal Limine entry lacks quiet and splash exactly once: %s\n' "${BASH_REMATCH[1]}" >&2; return 1; }
    elif [[ "$line" =~ $path ]]; then
      reference="${BASH_REMATCH[2]}"
      [[ "$reference" != *..* && -s "$(cfg_path "/boot$reference")" ]] ||
        { printf 'A normal Limine entry references %s, which is not on the ESP.\n' "$reference" >&2; return 1; }
      references=$((references + 1))
    fi
  done < <(bs_limine_normal)
  (( found )) || { printf '%s has no normal entry with a command line.\n' "$BS_LIMINE_CONFIG" >&2; return 1; }
  (( references >= 2 )) || { printf 'The normal Limine entries do not reference a kernel and an initramfs.\n' >&2; return 1; }
}

# Effective parameters, referenced boot files and the theme inside every normal boot image.
bs_verify() {
  local images=() image
  bs_verify_cmdline || return 1
  mapfile -t images < <(bs_images) && (( ${#images[@]} )) ||
    { printf 'No initramfs of the normal boot entry was found.\n' >&2; return 1; }
  for image in "${images[@]}"; do
    [[ -s "$(cfg_path "$image")" ]] || { printf 'The boot image %s is missing.\n' "$image" >&2; return 1; }
    bs_image_has_theme "$image" || return 1
  done
}

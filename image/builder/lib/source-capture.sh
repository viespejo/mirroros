#!/usr/bin/bash

SOURCE_CAPTURE_COMMIT=''
# shellcheck disable=SC2034 # Consumed by build-artifact metadata collection.
SOURCE_CAPTURE_PROFILE_IDENTITY=''
# shellcheck disable=SC2034 # Consumed by build-artifact container setup.
SOURCE_CAPTURE_PROFILE_PATH=''
SOURCE_CAPTURE_DIRTY=0
SOURCE_CAPTURE_DIRTY_PATHS=()

source_capture_check_entry_type() {
  local path="$1"
  local entry_type="$2"

  case "$entry_type" in
    'directory'|'regular file'|'symbolic link')
      return 0
      ;;
    *)
      printf 'MirrorOS build: unsupported profile entry type (%s): %s\n' "$entry_type" "$path" >&2
      return 2
      ;;
  esac
}

source_capture_add_dirty_path() {
  local candidate="$1"
  local existing

  [[ "$candidate" == image/archiso/* ]] || return 0
  for existing in "${SOURCE_CAPTURE_DIRTY_PATHS[@]}"; do
    [[ "$existing" == "$candidate" ]] && return 0
  done
  SOURCE_CAPTURE_DIRTY_PATHS+=("$candidate")
}

source_capture_read_profile_dirty_paths() {
  local status_file="$1"
  local record
  local status_code
  local path
  local renamed_path

  SOURCE_CAPTURE_DIRTY_PATHS=()
  while IFS= read -r -d '' record; do
    if [[ "${#record}" -lt 4 ]]; then
      printf '%s\n' 'MirrorOS build: could not parse Git profile status.' >&2
      return 2
    fi
    status_code="${record:0:2}"
    path="${record:3}"
    source_capture_add_dirty_path "$path"
    if [[ "$status_code" == *R* || "$status_code" == *C* ]]; then
      if ! IFS= read -r -d '' renamed_path; then
        printf '%s\n' 'MirrorOS build: could not parse a renamed Git profile path.' >&2
        return 2
      fi
      source_capture_add_dirty_path "$renamed_path"
    fi
  done < "$status_file"
}

source_capture_validate_working_entries() {
  local repository_root="$1"
  local profile_directory="$2"
  local entries_file="$3"
  local filesystem_path
  local repository_path
  local entry_type
  local ignore_status
  local validation_status=0

  if ! find "$profile_directory" -mindepth 1 -print0 > "$entries_file"; then
    printf 'MirrorOS build: could not inspect profile entry types: %s\n' "$profile_directory" >&2
    rm -f -- "$entries_file"
    return 2
  fi

  while IFS= read -r -d '' filesystem_path; do
    repository_path="image/archiso/${filesystem_path#"${profile_directory}/"}"
    if git -C "$repository_root" check-ignore -q -- "$repository_path"; then
      continue
    else
      ignore_status=$?
    fi
    if [[ "$ignore_status" -ne 1 ]]; then
      printf 'MirrorOS build: could not inspect ignore status for profile path: %s\n' "$repository_path" >&2
      validation_status=2
      break
    fi
    if ! entry_type="$(stat -c '%F' -- "$filesystem_path")" || \
      ! source_capture_check_entry_type "$repository_path" "$entry_type"; then
      validation_status=2
      break
    fi
  done < "$entries_file"

  rm -f -- "$entries_file"
  [[ "$validation_status" -eq 0 ]] || return "$validation_status"
}

source_capture_check_parent_directories() {
  local repository_root="$1"
  local repository_path="$2"
  local relative_path="${repository_path#image/archiso/}"
  local parent_path='image/archiso'
  local remainder="$relative_path"
  local component
  local source_path

  while [[ "$remainder" == */* ]]; do
    component="${remainder%%/*}"
    parent_path="${parent_path}/${component}"
    source_path="${repository_root}/${parent_path}"
    if [[ -L "$source_path" || ! -d "$source_path" ]]; then
      printf 'MirrorOS build: unsupported profile parent path: %s\n' "$parent_path" >&2
      return 2
    fi
    remainder="${remainder#*/}"
  done
}

source_capture_restore_parent_modes() {
  local repository_root="$1"
  local destination_root="$2"
  local repository_path="$3"
  local relative_path="${repository_path#image/archiso/}"
  local parent_relative
  local source_path
  local destination_path

  while [[ "$relative_path" == */* ]]; do
    parent_relative="${relative_path%/*}"
    source_path="${repository_root}/image/archiso/${parent_relative}"
    destination_path="${destination_root}/image/archiso/${parent_relative}"
    if [[ -d "$source_path" && ! -L "$source_path" ]]; then
      chmod --reference="$source_path" -- "$destination_path" || return 2
    fi
    relative_path="$parent_relative"
  done
}

source_capture_profile() {
  local repository_root="$1"
  local destination_root="$2"
  local profile_root="${destination_root}/image/archiso"
  local status_file="${destination_root}.status.$$"
  local profile_status_file="${destination_root}.profile-status.$$"
  local ignored_file="${destination_root}.ignored.$$"
  local index_file="${destination_root}.index.$$"
  local files_file="${destination_root}.files.$$"
  local tree_file="${destination_root}.tree.$$"
  local ignored_path
  local index_record
  local index_mode
  local index_path
  local submodule_path=''
  local repository_path
  local source_path
  local target_path
  local entry_type
  local -a capture_paths=()

  if [[ -e "$destination_root" || -L "$destination_root" ]]; then
    printf 'MirrorOS build: refusing existing profile capture path: %s\n' "$destination_root" >&2
    return 2
  fi
  if [[ ! -d "${repository_root}/image/archiso" || -L "${repository_root}/image/archiso" ]]; then
    printf 'MirrorOS build: image/archiso is missing or is not a real directory: %s\n' "${repository_root}/image/archiso" >&2
    return 2
  fi

  if ! git -C "$repository_root" ls-files -ci --exclude-standard -z -- image/archiso > "$ignored_file"; then
    printf '%s\n' 'MirrorOS build: could not inspect tracked profile ignore conflicts.' >&2
    return 2
  fi
  if IFS= read -r -d '' ignored_path < "$ignored_file"; then
    printf 'MirrorOS build: profile path is both tracked and ignored: %s\n' "$ignored_path" >&2
    rm -f -- "$ignored_file"
    return 2
  fi
  rm -f -- "$ignored_file"

  if ! git -C "$repository_root" ls-files -s -z -- image/archiso > "$index_file"; then
    printf '%s\n' 'MirrorOS build: could not inspect profile index entries.' >&2
    return 2
  fi
  while IFS= read -r -d '' index_record; do
    index_mode="${index_record%% *}"
    index_path="${index_record#*$'\t'}"
    if [[ "$index_mode" == '160000' ]]; then
      submodule_path="$index_path"
      break
    fi
  done < "$index_file"
  rm -f -- "$index_file"
  if [[ -n "$submodule_path" ]]; then
    printf 'MirrorOS build: Git submodules are unsupported in the profile: %s\n' "$submodule_path" >&2
    return 2
  fi

  if ! git -C "$repository_root" status --porcelain=v1 -z --untracked-files=all > "$status_file"; then
    printf '%s\n' 'MirrorOS build: could not determine repository dirty state.' >&2
    return 2
  fi
  if [[ -s "$status_file" ]]; then
    SOURCE_CAPTURE_DIRTY=1
  else
    SOURCE_CAPTURE_DIRTY=0
  fi

  if ! git -C "$repository_root" status --porcelain=v1 -z --untracked-files=all -- image/archiso > "$profile_status_file"; then
    printf '%s\n' 'MirrorOS build: could not determine profile dirty paths.' >&2
    rm -f -- "$status_file"
    return 2
  fi
  if ! source_capture_read_profile_dirty_paths "$profile_status_file"; then
    rm -f -- "$status_file" "$profile_status_file"
    return 2
  fi
  if ! source_capture_validate_working_entries \
    "$repository_root" "${repository_root}/image/archiso" "$tree_file"; then
    rm -f -- "$status_file" "$profile_status_file"
    return 2
  fi

  if ! git -C "$repository_root" ls-files -co --exclude-standard -z -- image/archiso > "$files_file"; then
    printf '%s\n' 'MirrorOS build: could not enumerate profile files.' >&2
    rm -f -- "$status_file" "$profile_status_file" "$files_file"
    return 2
  fi
  while IFS= read -r -d '' repository_path; do
    capture_paths+=("$repository_path")
  done < "$files_file"
  rm -f -- "$files_file"
  rm -f -- "$status_file" "$profile_status_file"

  if ! git -C "$repository_root" rev-parse HEAD > /dev/null 2>&1 || \
    ! SOURCE_CAPTURE_COMMIT="$(git -C "$repository_root" rev-parse HEAD)"; then
    printf '%s\n' 'MirrorOS build: could not identify the source commit.' >&2
    return 2
  fi

  if [[ "$SOURCE_CAPTURE_DIRTY" -eq 0 ]]; then
    if ! SOURCE_CAPTURE_PROFILE_IDENTITY="$(git -C "$repository_root" rev-parse HEAD:image/archiso)"; then
      printf '%s\n' 'MirrorOS build: could not identify the committed image/archiso tree.' >&2
      return 2
    fi
  else
    # shellcheck disable=SC2034 # Consumed by build-artifact metadata collection.
    SOURCE_CAPTURE_PROFILE_IDENTITY='dirty-path-list'
  fi

  umask 077
  if ! mkdir -m 700 -- "$destination_root"; then
    printf 'MirrorOS build: could not create private profile capture area: %s\n' "$destination_root" >&2
    return 2
  fi
  if ! mkdir -p -- "${destination_root}/image" || ! mkdir -m 700 -- "$profile_root"; then
    printf 'MirrorOS build: could not create captured profile directory: %s\n' "$profile_root" >&2
    return 2
  fi

  if [[ "$SOURCE_CAPTURE_DIRTY" -eq 0 ]]; then
    if ! git -C "$repository_root" archive --format=tar "${SOURCE_CAPTURE_COMMIT}:image/archiso" | \
      tar -xf - -C "$profile_root"; then
      printf '%s\n' 'MirrorOS build: could not materialize the committed Archiso profile.' >&2
      return 2
    fi
  else
    for repository_path in "${capture_paths[@]}"; do
      source_path="${repository_root}/${repository_path}"
      if [[ ! -e "$source_path" && ! -L "$source_path" ]]; then
        continue
      fi
      if ! source_capture_check_parent_directories "$repository_root" "$repository_path"; then
        return 2
      fi
      if ! entry_type="$(stat -c '%F' -- "$source_path")" || \
        ! source_capture_check_entry_type "$repository_path" "$entry_type"; then
        return 2
      fi
      target_path="${destination_root}/${repository_path}"
      if ! mkdir -p -- "${destination_root}/$(dirname -- "$repository_path")"; then
        printf 'MirrorOS build: could not create private profile parents for: %s\n' "$repository_path" >&2
        return 2
      fi
      if ! (cd -- "$repository_root" && cp -a --parents -- "$repository_path" "$destination_root"); then
        printf 'MirrorOS build: could not copy profile path: %s\n' "$repository_path" >&2
        return 2
      fi
      if [[ -L "$source_path" && ! -L "$target_path" ]]; then
        printf 'MirrorOS build: symbolic link was not preserved literally: %s\n' "$repository_path" >&2
        return 2
      fi
    done
    for repository_path in "${capture_paths[@]}"; do
      if ! source_capture_restore_parent_modes "$repository_root" "$destination_root" "$repository_path"; then
        printf 'MirrorOS build: could not preserve profile directory modes for: %s\n' "$repository_path" >&2
        return 2
      fi
    done
  fi

  chmod --reference="${repository_root}/image/archiso" -- "$profile_root" || {
    printf '%s\n' 'MirrorOS build: could not preserve the profile root mode.' >&2
    return 2
  }
  # shellcheck disable=SC2034 # Consumed by build-artifact container setup.
  SOURCE_CAPTURE_PROFILE_PATH="$profile_root"
}

source_capture_scan() {
  local profile_path="$1"
  local report_path="$2"
  local scanner_status

  if ! command -v gitleaks >/dev/null 2>&1; then
    printf '%s\n' 'MirrorOS build: gitleaks is missing; profile secret scan prerequisite is unmet.' >&2
    return 2
  fi

  umask 077
  if gitleaks dir --redact --no-banner --report-format json --report-path "$report_path" "$profile_path"; then
    [[ ! -e "$report_path" ]] || chmod 600 -- "$report_path"
    return 0
  else
    scanner_status=$?
  fi

  [[ ! -e "$report_path" ]] || chmod 600 -- "$report_path"
  if [[ "$scanner_status" -eq 1 ]]; then
    printf 'MirrorOS build: Gitleaks detected a secret in the captured profile; report preserved at %s.\n' "$report_path" >&2
    return 2
  fi

  printf 'MirrorOS build: Gitleaks profile scan failed with original status %s.\n' "$scanner_status" >&2
  return 5
}

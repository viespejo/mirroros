#!/usr/bin/env bash
# shellcheck disable=SC2034

iso_name="mirroros"
iso_label="MIRROROS_$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y%m)"
iso_publisher="MirrorOS"
iso_application="MirrorOS Live/Rescue"
iso_version="$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y.%m.%d)"
install_dir="arch"
bootmodes=('uefi.systemd-boot')
pacman_conf="pacman.conf"
airootfs_image_type="squashfs"
airootfs_image_tool_options=('-comp' 'xz' '-Xbcj' 'x86,arm64' '-b' '1M' '-Xdict-size' '1M')
bootstrap_tarball_compression=('zstd' '-c' '-T0' '--auto-threads=logical' '--long' '-19')
kernel_params_aarch64="clk_ignore_unused pd_ignore_unused arm64.nopauth"
file_permissions=(
  ["/etc/shadow"]="0:0:400"
  ["/root"]="0:0:750"
  ["/root/.automated_script.sh"]="0:0:755"
  ["/root/.gnupg"]="0:0:700"
  ["/usr/local/bin/choose-mirror"]="0:0:755"
  ["/usr/local/lib/mirroros/operations/install"]="0:0:755"
  ["/usr/local/lib/mirroros/operations/configure"]="0:0:755"
  ["/usr/local/lib/mirroros/operations/boot-first"]="0:0:755"
  ["/usr/local/lib/mirroros/operations/lib/uefi-boot-entry.sh"]="0:0:644"
  ["/usr/local/lib/mirroros/install/discovery/discover"]="0:0:755"
  ["/usr/local/lib/mirroros/install/discovery/discover-firmware"]="0:0:755"
  ["/usr/local/lib/mirroros/install/discovery/discover-hardware"]="0:0:755"
  ["/usr/local/lib/mirroros/install/discovery/discover-network"]="0:0:755"
  ["/usr/local/lib/mirroros/install/discovery/discover-storage"]="0:0:755"
  ["/usr/local/lib/mirroros/install/engine/apply"]="0:0:755"
  ["/usr/local/lib/mirroros/install/postconditions/check"]="0:0:755"
  ["/usr/local/lib/mirroros/install/plan/plan"]="0:0:755"
  ["/usr/local/lib/mirroros/install/confirmation/confirm-plan"]="0:0:755"
  ["/usr/local/lib/mirroros/install/confirmation/live-startup"]="0:0:755"
  ["/usr/local/lib/mirroros/capabilities/desktop/shell/services/hidden-entries.sh"]="0:0:755"
  ["/usr/local/lib/mirroros/capabilities/desktop/compositor/providers/hyprland/greeter/layout-indicator"]="0:0:755"
  ["/usr/local/lib/mirroros/capabilities/desktop/lock/lock-screen"]="0:0:755"
)

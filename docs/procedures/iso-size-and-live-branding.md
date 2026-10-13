# ISO size and live branding

## Scope and review state

This procedure audits the x86_64 live installation medium before profile reduction. It does not change installed-system policy, SSH startup/authentication/credentials, installer authorization, or reference-VM qualification configuration. Architecture and accepted ADRs remain normative; interview DEC-001 through DEC-011 define this delivery's reviewed scope.

**Package-review state: approved.** The maintainer explicitly approved the remaining 62 removal proposals and their associated paths with `yes`, after retaining dmidecode and wpa_supplicant. No package or overlay has been removed in Task 1. Task 2 may implement the reviewed table after its own Apply decision. Corrections must be recorded here before application. A newly unresolved removal remains blocked; retaining a component is preferable to guessing.

Approved exact-path scope amendments during Task 1:

- `image/archiso/airootfs/root/.zlogin`: remove only the inherited screen-reader conditional; preserve automated-script and MirrorOS startup calls. Maintainer response: `yes`.
- `image/archiso/airootfs/usr/local/share/livecd-sound/asound.conf.in`: remove the dedicated sound-helper template with its consumer. Maintainer response: `yes`.
- `tests/vm/reference/launch.contract.bats`: remove archinstall from the guest doubles and test the retained native-tool requirements. Maintainer response: `yes`.

These approvals authorize those paths only, not the pending package proposals. No build, package installation, service operation, or VM run is authorized by this audit.

## Evidence and reproducibility

Audit inspection date: 2026-10-13. Source commit: `34b37f07380e8bbb35962dcd6efd13433164b400`. The working tree also contains unrelated untracked assets and interview documents; they are not changed by this task.

The declaration contains **131 packages**, in the order used below. Its SHA-256 is `2296c35e859c64643a3219ae9fbe14897e2bc4a9756afa450b8fdd7de047c72a`.

Evidence identifiers used in the table:

| ID | Inspected evidence and boundary |
| --- | --- |
| M | Read-only `LC_ALL=C pacman -Si PACKAGE` against existing local sync databases: description, version, Depends On, Provides, and optional dependencies. This is dependency evidence, not proof of runtime usage or a frozen build resolver. |
| D | `install/discovery/discover-{firmware,hardware,network,storage}`, `install/discovery/lib/collect.sh`: bootctl, systemd-detect-virt, lsblk, ip, getent, curl, readlink, shell/core utilities, sysfs and procfs. Hardware collection reads sysfs; it does not require dmidecode. |
| P | `install/plan/*.mjs`, `install/plan/plan`, `install/confirmation/{confirm-plan,assistant.mjs}`, `install/confirmation/lib/{flow,live,ui,screens}.sh`: Node.js, Gum major 2, shell/core utilities, flock, loadkeys, timedatectl, systemctl, ip, getent, curl. Wi-Fi instructions explicitly use iwctl and rfkill. |
| E | `install/engine/lib/{precheck,storage,btrfs,common}.sh`: live-side flock, blockdev, wipefs, sfdisk, partprobe, udevadm, FAT/ext4/Btrfs formatting, blkid, mount/umount/mountpoint, pacstrap, genfstab, arch-chroot, filefrag, mkswap and btrfs swapfile tools. |
| T | `install/engine/lib/{accounts,system,boot,limine,btrfs}.sh`: commands explicitly inside arch-chroot, including useradd, chpasswd, passwd, locale-gen, hwclock, visudo, systemctl, bootctl, pacman, snapper and limine-snapper-sync. Target packages are not live-package justification by themselves. |
| V | `vm/reference/guest/{bootstrap-checks.sh,discovery-trigger.sh,install-trigger.sh}` and `vm/reference/lib/nocloud.sh`: native tools, shell, ip/getent/curl, Node.js/PTTY support, sgdisk fixture mutation, udevadm and storage inspection. NoCloud requires cloud-init; no guest agent is used for the serial-report protocol. |
| B | `image/builder/lib/container.sh`, `image/archiso/profiledef.sh`, and privately retained Archiso 91-1 script `evidence/archiso-build/20261005T013354Z-d80eaada-a140-4cb4-a444-fa36845c820d/iso-capture/executed-mkarchiso.sh`: host/container build tools are separate from live packages. UEFI systemd-boot copies EFI binaries from the live root, but uses mtools on the build host. Non-GRUB media still copies loopback.cfg. |
| O | `image/archiso/airootfs/`, boot configurations, symlinks and profile file_permissions: concrete consumers listed in the configuration map below. |
| R | DEC-002 minimal rescue: inspect disks, mount supported FAT/ext4/Btrfs targets, use arch-chroot, inspect logs/configuration and repair configuration with Vim. Does not promise forensic recovery, arbitrary filesystem repair or every storage transport. |
| N | Ethernet/Wi-Fi: systemd-networkd/resolved/timesyncd, iwd, iw, rfkill, iputils/iproute2/curl, firmware and existing live network overlays. No ordinary QEMU Ethernet test qualifies physical Wi-Fi. |

Local sync database SHA-256 values:

- core.db: `015d34bc1196dd13f98bd58e301d566f45b16f656bbb8be3def91b3725496ecd`
- extra.db: `1841fe68022eee4353b3ad57ad657617ecae1b9f75141d1f846664a3bae3f352`

The inspected baseline bundle is `dist/20261012T234437Z-1e6dbbfd-61ef-4ef7-b0a9-c7b59bd3bc85/`, including `pkglist.x86_64.txt`. Its observed ISO is **1,682,014,208 bytes**. The bundle manifest is actual resolved baseline evidence; local sync metadata is only a planning aid. In particular, local sync Vim was 9.2.1164-2 while the baseline manifest records 9.2.1178-1. The installed host Archiso is 82-1, not the required 91-1; its executable is not used as authoritative build-version evidence.

Reinspect dependency metadata without refreshing databases or installing packages:

```bash
while IFS= read -r package; do
  LC_ALL=C pacman -Si "$package"
done < image/archiso/packages.x86_64
```

### Static dependency cross-check

A read-only traversal of `%DEPENDS%` and `%PROVIDES%` from the existing core/extra sync databases, preferring the retained or baseline provider for virtual dependencies, found **263 packages reachable from the 62 retained declarations**, no unresolved dependency names, and **no proposed or accepted removed package reachable through hard-dependency names**. Every baseline firmware/microcode package remains reachable. The traversal ignores version constraints and is not a Pacman transaction solver; it cannot qualify the eventual rolling build or claim an exact reduced package count. Task 2/3 must inspect the actual resolved build manifest before accepting removal.

The declaration/table comparison passed: **131 rows for 131 declarations**, no missing, extra or duplicate rows; 62 Keep, 7 Remove / accepted, 62 Remove / proposed. `git diff --check` passed for tracked changes; this new document is untracked, so its row check was performed directly on its contents.

## Execution-boundary inventory

- **Live, directly required:** Bash and core utilities; Node.js for facts, plans, confirmation and records; Gum for presentation; util-linux for storage inspection, locks and mounts; systemd for firmware/time/service checks and udev; kbd for live keyboard setup; iproute2, glibc/getent and curl for connectivity; native Arch installation scripts; dosfstools, e2fsprogs and btrfs-progs; parted for partprobe; gptfdisk for the existing VM discovery fixture.
- **Indirect, required:** base pulls pacman and systemd; pacman pulls curl, GnuPG and its keyring/mirror support; systemd pulls kbd and cryptsetup; GnuPG pulls tpm2-tss; Vim pulls gpm; cloud-init pulls a dhcp-client provider and sudo. Removing archinstall does not make Python removable: cloud-init still requires it. Node.js brings its own structured-data runtime dependencies.
- **Inside the target:** account/password operations, locale generation, sudo validation, systemd-boot installation, Snapper operations, Limine snapshot tooling and package transactions. The prebuilt Limine archives are payload, not installed live packages. Build-time Java/Gradle/GraalVM/makepkg requirements stay in the container and are outside package trimming.
- **Build-time versus live:** mtools and squashfs tools used by mkarchiso must remain in the build environment through Archiso's dependencies even if not declared live. Only live declarations are under review. Removing a live grub package neither removes a host GRUB tool nor changes installed boot policy.
- **NoCloud versus ordinary boot:** cloud-init and its enabled units remain. Startup checks the cidata label to avoid competing with seeded qualification. Ordinary tty1 startup still calls MirrorOS live-startup from the root Zsh login.

## Per-package disposition

`Keep` is the audited recommendation to preserve the declaration. `Remove / accepted` implements an already accepted concrete interview decision. `Remove / proposed` identifies an additional audit proposal; all 62 remaining rows with this label received explicit maintainer approval in the review record below. Dependency statements refer to M unless otherwise noted. `C0` means only the package declaration changes: no checked-in live overlay consumer was found in O, D, P, E or V; package-owned files disappear through normal image assembly. It does not mean a package has no dependencies.

| Package | Disposition | Provided tools / dependency and use evidence | Affected configuration |
| --- | --- | --- | --- |
| alsa-utils | Remove / proposed | amixer/aplay are used only by the inherited sound helper (O); remove after speech consumers. Shared alsa-lib may still resolve independently. | C1 |
| amd-ucode | Keep | AMD CPU microcode; preserve firmware/CPU boot support (DEC-002, B). | Boot/initramfs |
| arch-install-scripts | Keep | pacstrap, genfstab, arch-chroot are directly required (E,V,R); depends on awk/bash/coreutils/grep/pacman/util-linux. | Native-tool qualification |
| archinstall | Remove / accepted | Alternative Python installer, not the selected engine (DEC-004); V currently requires it. Its filesystem and Python dependencies are evaluated independently, not blindly removed. | C2 |
| b43-fwcutter | Keep | Extracts b43 wireless firmware; retain the inherited Wi-Fi firmware preparation path initially rather than assume firmware coverage (N, DEC-002). Depends on glibc. | C0 retained |
| base | Keep | Required metapackage: Bash/coreutils, glibc, util-linux, pacman, systemd, iproute2, iputils and pciutils (D,P,E,V). | All live startup |
| bcachefs-tools | Remove / proposed | bcachefs userspace administration; no accepted root/ESP option or live caller (D,P,E,R). Its fuse/keyutils/libraries are not automatically removable. | C0 |
| bind | Remove / proposed | dig/nslookup and DNS server; live uses getent/resolved and retains drill for basic DNS diagnostics (N). Provides bind-tools/dnsutils, neither required by retained paths. | C0 |
| bolt | Remove / proposed | Thunderbolt authorization daemon; no live caller or enabled profile unit (O,D,P,E,V). Removing it is not physical Thunderbolt qualification. Depends on polkit/systemd. | C0 |
| brltty | Remove / accepted | Braille driver and libbrlapi; DEC-005 removes inherited Braille function. Pulls gpm, espeak-ng, libspeechd and GUI/AT-SPI libraries; gpm remains for Vim. | C1; package-owned units/rules |
| btrfs-progs | Keep | mkfs.btrfs, subvolume operations, filesystem mkswapfile/map-swapfile (E); mount/rescue inspection (R). Required live independently of target Btrfs. | Storage/rescue |
| clonezilla | Remove / proposed | Disk cloning suite; not installation or minimal mounting/chroot (E,R). Pulls drbl, partclone, partimage, screen, ntfs tools and compression/transfer tools; evaluate their shared edges separately. | C0 |
| cloud-init | Keep | Existing NoCloud boot orchestration (V); requires Python, dhcp-client and sudo. Keep all enabled cloud-init units. | NoCloud symlinks retained |
| cryptsetup | Keep | systemd hard dependency; libcryptsetup needed even with unencrypted installed roots. No change to encryption policy (M,D,P). | systemd dependency |
| darkhttpd | Remove / proposed | Static HTTP server; no live caller; HTTPS probes use curl, not a local server (D,P,V). Depends on glibc. | C0 |
| ddrescue | Remove / proposed | Recovery imaging beyond mounting/chroot (R); no E/V caller. libgcc/libstdc++ remain if required elsewhere. | C0 |
| dhcpcd | Keep | Provides dhcp-client required by cloud-init (M,V). Ethernet DHCP normally uses networkd; that does not eliminate the package dependency. | Network/NoCloud retained |
| diffutils | Keep | diff/cmp; cmp compares live/target mirrorlists (E). Also a hard dependency of mkinitcpio (M). | Package/initramfs checks |
| dmidecode | Keep | DMI/SMBIOS inspection for manual live hardware diagnosis (R); explicitly retained after maintainer review. D's sysfs collection is not its only possible live use. Depends on glibc. | Hardware diagnosis |
| dmraid | Remove / proposed | Firmware RAID activation, outside accepted installation/minimal supported-target rescue. No dmraid hook or caller in the profile (O,E). device-mapper remains through systemd/Archiso. | C0 |
| dnsmasq | Remove / proposed | DNS/DHCP server, not the guest client path (N,V); no enabled overlay unit. Does not provide cloud-init's dhcp-client dependency. | C0 |
| dosfstools | Keep | mkfs.fat formats ESP on the live side (E); FAT repair for rescue. Independently needed despite the target bootloader choice. | ESP/rescue |
| e2fsprogs | Keep | mkfs.ext4 and filefrag for ext4 resume offset (E); supported-root rescue. Libraries may also be shared dependencies. | ext4/resume/rescue |
| edk2-shell | Keep | UEFI shell copied by Archiso from live package contents (B); firmware/boot-path diagnosis (R). Not BIOS-exclusive. | UEFI shell auto-entry |
| efibootmgr | Keep | Inspect/repair UEFI boot entries during minimal boot rescue (R); efivar libraries. Target bootctl does not substitute for this live use. | UEFI rescue |
| espeakup | Remove / accepted | Speakup/espeak-ng connector started by livecd-talk (O); DEC-005. | C1 |
| ethtool | Keep | Ethernet driver/link inspection for failed live networking (N,R). Depends on libmnl/glibc. | Network diagnosis |
| exfatprogs | Remove / proposed | exFAT maintenance utilities, not FAT32 ESP or supported root (E,R). Kernel exFAT mounting is separate; no removal of kernel support. | C0 |
| f2fs-tools | Remove / proposed | F2FS formatting/repair; no supported layout or caller after removing archinstall (E,R). libf2fs consumers must be checked in reduced manifest. | C0 |
| fatresize | Remove / proposed | FAT resizing through libparted; engine creates a fixed ESP and does not resize it (E). parted remains for partprobe. | C0 |
| foot-terminfo | Keep | Remote-terminal description; preserve interactive terminal operation over retained SSH (DEC-008). ncurses-dependent data, not a desktop install. | SSH terminal data retained |
| fsarchiver | Remove / proposed | Filesystem backup/deployment beyond minimal rescue; E uses pacstrap, not filesystem archive restoration. Shared compression libs remain as needed. | C0 |
| ghostty-terminfo | Keep | Remote-terminal description for retained SSH (DEC-008); terminal data only. | SSH terminal data retained |
| gpart | Remove / proposed | Guess/reconstruct lost partition tables; outside minimum rescue, no E/V caller. | C0 |
| gpm | Keep | Hard dependency of retained Vim (M). Do not classify it as speech-only because brltty also depends on it. | Vim runtime |
| gptfdisk | Keep | sgdisk used by the existing disposable discovery safety fixture (V); GPT inspection (R). Engine itself uses sfdisk. | VM fixture retained |
| grml-zsh-config | Keep | Existing root Zsh interactive configuration (O); depends on Zsh/core tools. Preserve cancellation-to-shell behavior. | Root live shell |
| grub | Remove / proposed | Not BIOS-exclusive: package also provides EFI tools. Current live boot mode is uefi.systemd-boot (B), target boot options use bootctl/Limine (T), no live GRUB caller. Keep compatible loopback.cfg for external GRUB. | C3 |
| gum | Keep | Required major-2 presentation, including pager and protected prompts (P); glibc dependency. | Installer UI |
| hdparm | Remove / proposed | ATA parameter tuning; no live caller. Disk inspection remains lsblk/blkid and smartctl (D,R). | C0 |
| hyperv | Remove / proposed | Hyper-V filecopy/KVP/VSS agents, not reference QEMU serial protocol (V). Explicit enabled symlinks must go. | C4 |
| intel-ucode | Keep | Intel CPU microcode, initial complete boot support (DEC-002,B). | Boot/initramfs |
| irssi | Remove / proposed | IRC client; no installation/network/rescue caller. Its Perl/crypto/ncurses libraries remain if required. | C0 |
| iw | Keep | Wireless interface/radio diagnostics; required by wireless-regdb (M,N). Not replaced merely because iwctl exists. | Wi-Fi retained |
| iwd | Keep | iwctl is the documented Wi-Fi setup tool (P,N); enabled iwd.service remains. | Wi-Fi service/instructions |
| jfsutils | Remove / proposed | JFS administration, outside supported-root rescue; no E caller. util-linux stays. | C0 |
| kitty-terminfo | Keep | Remote-terminal support for retained SSH; ncurses data (DEC-008). | SSH terminal data retained |
| kmscon-terminfo | Keep | Console-terminal descriptions; preserve console compatibility (DEC-005). Does not require adding kmscon. | Console data retained |
| ldns | Keep | drill for basic DNS diagnosis when getent/resolved connectivity fails (N,R); smaller client role than retaining a DNS server. Provides libldns/drill. | DNS diagnosis |
| less | Keep | Read logs/configuration for minimal rescue; required by man-db (M,R). Gum's pager does not replace all shell inspection. | Rescue/manuals |
| lftp | Remove / proposed | FTP client; inherited automated script uses curl, not lftp (O). No D/P/E/V caller. | C0 |
| libfido2 | Keep | Optional OpenSSH FIDO/U2F support (M). Preserve inherited authentication capabilities under DEC-008 rather than trim an SSH feature while leaving config unchanged. | SSH feature dependency retained |
| libusb-compat | Remove / proposed | Legacy libusb ABI, not modern libusb used by GnuPG/usbutils. No retained consumer identified in inspected metadata; gate on resolved dependency check. | C0 |
| linux | Keep | Kernel/modules for UEFI boot, networking and supported mounts (B,N,R). Requires an initramfs provider. | Kernel/initramfs |
| linux-atm | Remove / proposed | ATM networking tools, no Ethernet/iwd caller or configuration (N,O). | C0 |
| linux-firmware | Keep | Complete existing firmware metapackage and every resolved firmware dependency retained (DEC-002,N). No vendor-specific trimming. | All firmware preserved |
| linux-firmware-marvell | Keep | Explicit additional Marvell firmware beyond the default metapackage (DEC-002,N). Depends on linux-firmware-whence. | All firmware preserved |
| livecd-sounds | Remove / accepted | Speech card-selection WAV files consumed by livecd-sound (O), DEC-005. | C1 |
| lsscsi | Keep | Inspect disk transports for rescue diagnostics (R); sysfsutils dependency. Complement to lsblk, not a RAID authorization mechanism. | Storage diagnosis |
| lvm2 | Keep | Inspect/release existing LVM holders when a candidate disk is busy (E precheck,R); LVM is not added to installed layout choices. device-mapper remains shared. | Rescue holder diagnosis |
| lynx | Remove / proposed | Text browser; inherited Installation_guide uses xdg-open. Remove that convenience launcher and welcome instructions together, retaining accurate upstream documentation URLs. | C5 |
| man-db | Keep | Local manual lookup during rescue without working internet (R); depends on less/groff/libpipeline. | Rescue manuals |
| man-pages | Keep | Offline Linux API/system reference for minimal diagnosis (R); no runtime dependency. | Rescue manuals |
| mc | Remove / proposed | Alternative file-manager/editor; retained Vim and core file tools cover minimum repair. gpm/e2fsprogs remain independently. | C0 |
| mdadm | Remove / proposed | MD RAID administration; no accepted layout or explicit mdadm initramfs hook/caller (O,E). Kernel/lsblk still report existing holders; no RAID rescue support claim. | C0 |
| memtest86+ | Remove / accepted | Legacy BIOS binary only (M,B); DEC-007. EFI sibling is distinct and retained. | C3, BIOS assets |
| memtest86+-efi | Keep | UEFI memory diagnosis (R,B); keep its existing loader entry and binary. Not BIOS-exclusive. | EFI memtest entry retained |
| mkinitcpio | Keep | linux initramfs provider, required by mkinitcpio-archiso (M,B); its own tools/dependencies remain. Target regeneration is a separate T boundary. | Live initramfs |
| mkinitcpio-archiso | Keep | Archiso initramfs hooks and live-root discovery (B,O), depends on mkinitcpio/device-mapper. | Live boot hooks |
| mkinitcpio-nfs-utils | Keep | ipconfig/nfsmount for existing archiso_pxe_common/archiso_pxe_nfs hooks (O). Removing BIOS menus does not authorize breaking shared initramfs hooks. | PXE hooks retained, unqualified |
| mmc-utils | Remove / proposed | MMC administration; D reads sysfs/lsblk without it. No E/V caller; no MMC maintenance promise. | C0 |
| modemmanager | Remove / proposed | mmcli/WWAN daemon, not Ethernet or Wi-Fi method in P. Depends on ppp and modem libs; remove both enabled/alias symlinks and motd WWAN guidance. | C6 |
| mtools | Remove / proposed | mcopy/mmd required on build host by UEFI assembly (B), not in live E/R. Archiso host dependency remains installed; no live caller. | C0; build dependency unchanged |
| nano | Remove / accepted | Alternative editor; DEC-006, no necessary retained dependency identified. Vim remains. | C0 |
| nbd | Keep | nbd-client for existing archiso_pxe_nbd hook (O); shared network boot support is not BIOS-exclusive. | PXE hooks retained, unqualified |
| ndisc6 | Remove / proposed | Supplemental IPv6 discovery commands; live uses ip/getent/resolved and retained iputils (N). No direct caller. | C0 |
| nfs-utils | Keep | Existing NFS network-root/mount support associated with retained Archiso PXE hooks (O); libraries may be shared. No new NFS qualification claim. | PXE dependencies retained |
| nilfs-utils | Remove / proposed | NILFS administration, no supported target; partclone is its known declared consumer and also proposed for removal (M). | C0 |
| nmap | Remove / proposed | Network scanner, not connectivity readiness (D,P,V); retain ip/ethtool/drill. | C0 |
| nodejs | Keep | Structured facts, plan, digest, confirmation and engine records (D,P,E,V). Runtime libraries remain dependency-resolved. | Embedded installer runtime |
| ntfsprogs | Remove / proposed | NTFS utilities; clonezilla/testdisk are consumers also proposed for removal (M). No supported NTFS root or required E caller. | C0 |
| nvme-cli | Keep | NVMe controller/namespace inspection for disk diagnosis (R); no mutation is authorized by inclusion. util-linux/json-c dependencies. | Storage diagnosis |
| open-iscsi | Remove / proposed | iSCSI initiator/remote block discovery; no profile hook or accepted target path (O,E). Shared kmod/crypto/util-linux remain. | C0 |
| open-vm-tools | Remove / proposed | VMware agents and vmblock support; no reference serial/NoCloud consumer (V). Remove both enabled symlinks. | C7 |
| openconnect | Remove / proposed | AnyConnect VPN client; P offers Ethernet/Wi-Fi without VPN setup. Pulls vpnc/pcsclite/tpm2-tss/xdg-utils; shared libraries are evaluated separately. | C0 |
| openpgp-card-tools | Remove / proposed | OpenPGP card management CLI, not pacman-init keyring setup (O). pcsclite remains because scdaemon configuration explicitly references it. | C0 |
| openssh | Keep | ssh/sshd/scp/sftp remote access explicitly required by DEC-008. Preserve package, feature support, enabled symlink and configuration byte-for-byte. | C8 protected |
| openvpn | Remove / proposed | VPN client, no accepted live connection method/caller (P,N). No configured overlay unit. | C0 |
| partclone | Remove / proposed | Used-block imaging outside minimum rescue; clonezilla consumer also proposed for removal. Pulls nilfs/NTFS utilities. | C0 |
| parted | Keep | partprobe is directly invoked by sync_partitions (E); do not remove because engine partitions with sfdisk. | Engine partition rescan |
| partimage | Remove / proposed | Partition imaging; clonezilla consumer removed by proposal (M); not mount/chroot rescue (R). | C0 |
| pcsclite | Keep | libpcsclite explicitly selected by root .gnupg/scdaemon.conf (O); preserve pcscd.socket symlink. Optional GnuPG backend remains valid without OpenPGP card CLI. | C9 retained |
| ppp | Remove / proposed | PPP modem/VPN support; modemmanager/pptpclient/wvdial/xl2tpd consumers all proposed for removal (M). No Ethernet/iwd dependency. | C0 |
| pptpclient | Remove / proposed | PPTP VPN client, depends on ppp; no live connection path (P,N). | C0 |
| pv | Keep | Optional Archiso copy-to-RAM progress display; preserve existing boot option without changing hooks (M,O,B). Not only a general-purpose transfer utility. | copytoram option retained |
| qemu-guest-agent | Remove / proposed | Guest management daemon; reference harness uses NoCloud/serial/QMP instead (V). No enabled overlay qemu-ga unit. QEMU boot must still be qualified. | C0 |
| refind | Remove / proposed | Alternative EFI boot manager, not BIOS-only. Live selects systemd-boot and target selects bootctl/Limine (B,T); no live caller. edk2/EFI memtest stay. | C0 |
| reflector | Remove / proposed | Mirror-ranking CLI; choose-mirror only writes a supplied mirror URL with shell/core tools (O). No D/P/E/V caller; pacman-mirrorlist remains through pacman. | C0 |
| rsync | Remove / proposed | Transfer tool, not used by live engine (E); source capture runs outside the guest. Native cp/core tools remain. | C0 |
| rxvt-unicode-terminfo | Keep | Remote-terminal data for retained SSH (DEC-008); no graphical terminal package added. | SSH terminal data retained |
| screen | Remove / proposed | Multiplexer inherited via cloning suite, no D/P/E/V caller; alternate consoles and optional retained tmux suffice (R). | C0 |
| sdparm | Remove / proposed | SCSI parameter tuning, no live caller; lsblk/lsscsi/smartctl retained for inspection (R). | C0 |
| sequoia-sq | Remove / proposed | Sequoia CLI; pacman-init invokes pacman-key/GnuPG, not sq (O). No retained CLI consumer; crypto libraries remain as needed. | C0 |
| sg3_utils | Remove / proposed | Low-level SCSI administration, outside minimum rescue; no live caller (E,R). | C0 |
| smartmontools | Keep | smartctl for read-only disk-health inspection (R); retaining tools does not authorize destructive drive tests or physical qualification. | Storage diagnosis |
| sof-firmware | Keep | Sound Open Firmware remains despite speech removal: complete initial firmware preservation (DEC-002), no hardware-family trimming. | All firmware preserved |
| squashfs-tools | Keep | unsquashfs can inspect the independent rescue medium's live filesystem for diagnosis (R). Build compression remains unchanged; build-host dependency is distinct. | Rescue ISO inspection |
| sudo | Keep | Required dependency of cloud-init (M,V); root live model does not make dependency dispensable. Target visudo remains a separate T command. | NoCloud dependency |
| syslinux | Remove / accepted | BIOS-only profile use, DEC-007; remove bios.syslinux mode and all associated resources. UEFI dependencies stay. | C3 |
| systemd-resolvconf | Keep | Existing resolvconf compatibility with resolved for network clients (N,O); depends on matching systemd. Preserve current DNS integration. | DNS compatibility |
| tcpdump | Remove / proposed | Packet capture outside basic connectivity diagnosis; no D/P/E/V caller. libpcap may remain if other packages need it. | C0 |
| terminus-font | Keep | Inherited console fonts retained under DEC-005; do not conflate terminal data with speech. Current installer uses kernel-default console font. | Console data retained |
| testdisk | Remove / proposed | Undelete/PhotoRec forensic recovery beyond minimum mount/chroot (R). Pulls ntfsprogs/libntfs-3g; no live caller. | C0 |
| tmux | Keep | Preserve an interactive rescue session while inspecting logs/network and chroot (R); does not imply automation requirement. libevent/ncurses dependency. | Rescue shell tool |
| tpm2-tools | Remove / proposed | TPM administration CLI; no Secure Boot/TPM installation integration or live caller (D,E). Do not remove tpm2-tss with it. | C0 |
| tpm2-tss | Keep | GnuPG hard dependency through pacman (M); systemd optional TPM support is not the only edge. | Package trust dependency |
| udftools | Remove / proposed | UDF administration; no target filesystem choice or caller. ISO mounting uses kernel support, not UDF formatting tools (B,R). | C0 |
| usb_modeswitch | Remove / proposed | Mode-switch support for inherited mobile broadband devices; not used by Ethernet/iwd flow (P,N). No physical USB modem support claim. | C0; package-owned rules |
| usbmuxd | Remove / proposed | Apple-device multiplexing, no required live network/rescue caller (N,R). Package-owned daemon/rules disappear with package. | C0 |
| usbutils | Keep | lsusb for diagnosing available USB/Wi-Fi devices (N,R); modern libusb remains. | Hardware/network diagnosis |
| vim | Keep | Explicit live repair editor (DEC-006,R); retain vim-runtime and gpm dependencies. Installed-system editor policy unchanged. | Rescue editor |
| virtualbox-guest-utils-nox | Remove / proposed | VirtualBox user services, not reference QEMU serial/NoCloud path (V). Kernel's guest modules remain part of linux; remove enabled vboxservice symlink. | C10 |
| vpnc | Remove / proposed | Cisco VPN client and openconnect dependency (M); both proposed for removal, no P connection flow. | C0 |
| wireless-regdb | Keep | Wireless regulatory database and iw dependency (M,N); preserve Wi-Fi functionality. | Wi-Fi regulatory support |
| wireless_tools | Remove / proposed | Legacy Wireless Extensions iwconfig/iwlist, no documented setup caller; modern iw/iwd retained (P,N). This is not proof all legacy adapters work. | C0 |
| wpa_supplicant | Keep | Alternative Wi-Fi/802.1X client for manual connectivity setup and diagnosis if the documented iwd path is insufficient (N,R); explicitly retained after maintainer review. Depends on pcsclite and network/crypto libraries. Inclusion does not enable a new service or qualify alternative networks. | Wi-Fi fallback; existing configuration unchanged |
| wvdial | Remove / proposed | Dial-up configuration, ppp/wvstreams dependency; no accepted network flow (P,N). | C0 |
| xdg-utils | Remove / proposed | xdg-open only retained profile caller is Installation_guide; remove launcher and motd guidance together. openconnect consumer also removed by proposal. | C5 |
| xfsprogs | Remove / proposed | XFS administration; not an accepted target root. archinstall is the known declared consumer being removed; verify other library consumers in reduced manifest. | C0 |
| xl2tpd | Remove / proposed | L2TP/PPP daemon, no accepted network flow (P,N); ppp consumer also removed by proposal. | C0 |
| zsh | Keep | Root shell in inherited passwd and .zlogin; required for automatic installer startup and cancellation-to-shell (O,P). grml configuration remains. | Root shell/startup |

## Exact affected-configuration map

All package decisions affect `image/archiso/packages.x86_64`. Supporting implementation tests/docs are bounded by Task 2's file list plus the three approved amendments above. The following map names every additional checked-in overlay/configuration consumer identified for the proposals. It is not authorization to delete every candidate file in the original plan.

### C1: speech/Braille and sound helper

Remove dedicated resources and their permission entries:

- `image/archiso/airootfs/etc/systemd/system/livecd-alsa-unmuter.service`
- `image/archiso/airootfs/etc/systemd/system/livecd-talk.service`
- `image/archiso/airootfs/etc/systemd/system/multi-user.target.wants/livecd-talk.service`
- `image/archiso/airootfs/etc/systemd/system/sound.target.wants/livecd-alsa-unmuter.service`
- `image/archiso/airootfs/usr/local/bin/livecd-sound`
- `image/archiso/airootfs/usr/local/share/livecd-sound/asound.conf.in` (approved amendment)
- `image/archiso/efiboot/loader/entries/02-archiso-speech-linux.conf`

Modify only affected sections in:

- `image/archiso/profiledef.sh`: remove livecd-sound executable permission.
- `image/archiso/airootfs/root/.zlogin`: remove screen-reader conditional, preserve all other startup (approved amendment).
- `image/archiso/grub/grub.cfg` and `image/archiso/grub/loopback.cfg`: remove speech entry/accessibility tune where present; preserve external loopback technical paths.
- BIOS speech menus disappear with C3.

brltty/espeakup package-owned rules and units disappear through package removal, not repository edits. alsa-utils removal is an additional proposal, not implicitly approved by DEC-005; sof-firmware stays.

### C2: native-tool qualification

Modify:

- `vm/reference/guest/bootstrap-checks.sh`
- `tests/vm/reference/launch.contract.bats` (approved amendment)
- `tests/vm/reference/evidence.contract.bats`
- `tests/image/live-profile.contract.bats`
- `tests/image/guided-installer.contract.bats`
- `docs/procedures/test.md` and `docs/procedures/build.md`

Require pacstrap/genfstab/arch-chroot without requiring archinstall. Keep qualification IDs, serial reporting, configuration and safety contracts unchanged. Historical prototype evidence is not rewritten.

### C3: UEFI-only profile and unused live boot tools

Modify `image/archiso/profiledef.sh` to retain `uefi.systemd-boot` only. Remove the inherited `memdisk` hook from `image/archiso/airootfs/etc/mkinitcpio.conf.d/archiso.conf`: it detects Syslinux MEMDISK virtual disks and requires `memdiskfind` from the removed `syslinux` package, not the supported UEFI boot path. Preserve every other hook and compression setting. Story 2.6 build qualification exposed this leftover as `binary not found: memdiskfind`; the static profile contract checks this narrow upstream exception. Remove these BIOS-only resources:

- `image/archiso/syslinux/archiso_head.cfg`
- `image/archiso/syslinux/archiso_pxe.cfg`
- `image/archiso/syslinux/archiso_pxe-linux.cfg`
- `image/archiso/syslinux/archiso_sys.cfg`
- `image/archiso/syslinux/archiso_sys-linux.cfg`
- `image/archiso/syslinux/archiso_tail.cfg`
- `image/archiso/syslinux/splash.png`
- `image/archiso/syslinux/syslinux.cfg`

Modify `image/archiso/grub/grub.cfg` and `image/archiso/grub/loopback.cfg` to remove obsolete BIOS memtest/menu paths alongside branding/speech cleanup. Keep loopback.cfg: Archiso 91 copies it even for non-GRUB media, enabling use by external GRUB. The live grub package removal is a reviewed proposal, not a claim GRUB is BIOS-only. Keep EFI memtest and edk2-shell; do not remove `image/archiso/efiboot/loader/entries/03-archiso-memtest86+x64.conf`.

### C4: Hyper-V agents

Remove only these enabling symlinks if hyperv removal is approved:

- `image/archiso/airootfs/etc/systemd/system/multi-user.target.wants/hv_fcopy_daemon.service`
- `image/archiso/airootfs/etc/systemd/system/multi-user.target.wants/hv_kvp_daemon.service`
- `image/archiso/airootfs/etc/systemd/system/multi-user.target.wants/hv_vss_daemon.service`

### C5: upstream convenience guide launcher

Remove `image/archiso/airootfs/usr/local/bin/Installation_guide`, remove its executable permission from `image/archiso/profiledef.sh`, and remove its usage instruction from `image/archiso/airootfs/etc/motd`. Keep the official installation-guide URL as upstream reference, not as MirrorOS product identity. This permits removal of lynx/xdg-utils without a broken convenience command.

### C6: modem management

Remove:

- `image/archiso/airootfs/etc/systemd/system/dbus-org.freedesktop.ModemManager1.service`
- `image/archiso/airootfs/etc/systemd/system/multi-user.target.wants/ModemManager.service`

Remove mmcli/WWAN instruction from `image/archiso/airootfs/etc/motd`. Keep `image/archiso/airootfs/etc/systemd/network/20-wwan.network` unchanged: it is a generic networkd matcher, not an executable reference to ModemManager and does not enable that service. Removing it is unnecessary scope expansion.

### C7: VMware agents

Remove:

- `image/archiso/airootfs/etc/systemd/system/multi-user.target.wants/vmtoolsd.service`
- `image/archiso/airootfs/etc/systemd/system/multi-user.target.wants/vmware-vmblock-fuse.service`

### C8: protected SSH state

Retain without changes:

- `image/archiso/airootfs/etc/systemd/system/multi-user.target.wants/sshd.service`
- `image/archiso/airootfs/etc/ssh/sshd_config.d/10-archiso.conf`
- `image/archiso/airootfs/etc/passwd`
- `image/archiso/airootfs/etc/shadow`

Keep libfido2 and terminal descriptions; do not introduce an authentication-feature regression while preserving the literal SSH configuration. Static equality checks cannot establish whether sshd is active in a booted artifact; resolving the previous runtime discrepancy is out of scope.

### C9: smartcard backend retained

Retain `image/archiso/airootfs/root/.gnupg/scdaemon.conf` and `image/archiso/airootfs/etc/systemd/system/sockets.target.wants/pcscd.socket` because the configuration explicitly selects `/usr/lib/libpcsclite.so`. The socket is in the candidate file list but **must not be deleted** under this audit. OpenPGP CLI removal is separate from backend-library retention.

### C10: VirtualBox agent

Remove `image/archiso/airootfs/etc/systemd/system/multi-user.target.wants/vboxservice.service` if its package removal is approved. Do not trim linux guest modules or alter the reference-VM contract.

## Dependency and removal gates for implementation

1. Review every row, not just package categories. Removing a declaration does not prove the package disappears from the image.
2. In the build resolver, inspect the reduced native `pkglist.x86_64.txt`; all accepted/proposed removed packages must be absent unless a newly demonstrated hard dependency blocks the cut. Stop and update the audit instead of forcing dependency removal.
3. Specifically check closure edges: base → pacman → curl/GnuPG → tpm2-tss; base → systemd → cryptsetup/kbd; Vim → gpm; cloud-init → dhcp-client/dhcpcd + sudo + Python; wireless-regdb → iw; mkinitcpio-archiso → mkinitcpio/device-mapper. Preserve the complete baseline firmware package set, including additional Marvell and SOF firmware, AMD/Intel microcode and firmware-whence.
4. Keep nbd, mkinitcpio-nfs-utils and nfs-utils while the unchanged live initramfs declares PXE hooks. PXE retention is compatibility, not additional qualification. Removing those hooks needs another exact-path amendment and review; it is not part of the present proposals.
5. Check optional and configuration-selected consumers independently of hard dependency closure: OpenSSH/libfido2 and scdaemon/pcsclite are deliberately retained. No SSH policy change is approved.
6. Search the profile and embedded live paths for removed commands, dangling service/symlink targets, file_permissions and boot entries. Do not treat declarations in unchanged packages.aarch64 or historical prototypes as active x86_64 consumers; no new architecture support or aarch64 package edits are authorized.
7. Run Task 2's Bats and Node suites, installer regressions relevant to these live tools, and `git diff --check`. Do not label static checks runtime qualification.
8. Request separate authorization before every build and VM run. Retain private evidence only under ignored evidence locations. Reduced size, boot behavior, actual package closure and manual rescue verdicts remain pending until those runs.

## Branding implementation inventory

Task 2 will apply `mirroros-YYYY.MM.DD-x86_64.iso`, `MIRROROS_YYYYMM`, publisher `MirrorOS`, application `MirrorOS Live/Rescue`, and hostname `mirroros`. Preserve date/SOURCE_DATE_EPOCH evaluation, technical install_dir `arch`, Archiso kernel parameters, upstream package names and accurate Arch lineage.

The existing overlay has no `/etc/os-release`. Before creating a live-only `image/archiso/airootfs/etc/os-release`, inspect filesystem package ownership and the installed `/etc/os-release` symlink behavior. Do not edit `/usr/lib/os-release` or target policy. The installed target is independently populated by pacstrap. Visible menu, motd and hostname changes use the enumerated Task 2 paths; the guided welcome already uses MirrorOS.

Update `image/archiso/UPSTREAM.md`, `docs/attribution.md`, and build/test procedures with the actual delta. Do not rewrite the vendor branch, imported upstream identity, accepted ADRs or historical evidence.

## Maintainer review record

- Table coverage: passed automated row/declaration comparison (131/131, no duplicates or omissions).
- Already accepted concrete cuts: archinstall; brltty/espeakup/livecd-sounds and dedicated speech resources; nano; syslinux/legacy memtest and BIOS resources (DEC-004 through DEC-007).
- Additional removals: **all 62 remaining `Remove / proposed` rows and their associated configuration-map paths explicitly approved** by the maintainer with `yes` on 2026-10-13.
- Exact-path amendments: the three paths listed above are approved; no other out-of-list edit is authorized.
- Corrections: the maintainer requested keeping dmidecode for manual live hardware inspection and confirmed keeping wpa_supplicant as a Wi-Fi fallback with `yes`. Both former removal proposals are now Keep; no service or network-configuration change is authorized.
- Review discussion: the maintainer raised possible uses of hyperv, open-vm-tools, virtualbox-guest-utils-nox and qemu-guest-agent in other VM configurations or future installation/configuration work. Their current live consumers and possible future installed-system uses were distinguished; future target requirements do not authorize adding them to the live medium or changing target policy. Their live removal was included in the subsequent approval of the remaining 62 proposals.
- Package approval response: `yes`, answering whether the maintainer approved the 62 remaining removals and their associated paths after the two retention corrections.
- AC-1: satisfied by complete table coverage, dependency/use evidence and explicit package/path review approval; no runtime acceptance is claimed.

## Manual acceptance and optimization measurements

The guide below is the attended acceptance path for the reduced live medium. It does not change the automated reference-VM contract or qualify Story 2.6 postconditions. **Execution state: pending.** No build or VM has been run during Task 3 guide preparation. Document review, successful static tests, and a published ISO alone do not grant runtime acceptance.

### Authorization and host prerequisites

Run host commands from the repository root in Bash as a normal user. Obtain explicit authorization **before each build and each VM launch**, including installed-disk boots and rescue boots. Record the authorized artifact, case, disposable disk, consequential effects and verdict in the private worksheet. An Apply decision for this documentation is not build/VM authorization. Installation erases the selected guest disk: obtain approval for that case before proceeding and still complete the real installer confirmation. Never bypass confirmation or invoke the internal engine directly.

Host requirements:

- x86_64 Arch-compatible host with hardware virtualization enabled and functional user access to `/dev/kvm`; no sudo launch, permission/group changes or software-emulation fallback.
- QEMU with `qemu-system-x86_64`, `qemu-img`, a working GTK display backend and a local graphical session. Install any missing prerequisites separately with explicit authorization.
- Readable `/usr/share/edk2/x64/OVMF_CODE.4m.fd` and `/usr/share/edk2/x64/OVMF_VARS.4m.fd`; Secure Boot disabled.
- Bash, Git, Node.js, Bats, Gitleaks, coreutils and util-linux; `xorriso` for inspecting ISO metadata. Enough free space for the bundle and three growing sparse 32 GiB disks.
- Working outbound network/DNS/TLS. Guest Ethernet uses SLIRP NAT and VirtIO, without forwarding.
- For construction, all [build prerequisites](build.md#prerequisites-and-privilege-boundary), including trusted Docker daemon access, Cosign and Gitleaks. Docker access is root-equivalent and construction uses a privileged container.

Do not attach host block devices, USB devices, host directories, credentials, shared filesystems or a NoCloud seed to these graphical runs. No seed is essential for exercising automatic startup. Physical Wi-Fi is a separate checklist, not authorization for passthrough or a physical installation.

### Select and validate artifacts

Select exact bundle directories; do not choose an ISO solely by newest timestamp. Substitute the reduced bundle only after its separately authorized build succeeds. Use paths without commas or newlines because QEMU's option syntax treats commas specially; quoted paths may contain spaces.

```bash
BASELINE_BUNDLE="$PWD/dist/20261012T234437Z-1e6dbbfd-61ef-4ef7-b0a9-c7b59bd3bc85"
REDUCED_BUNDLE="$PWD/dist/REPLACE_WITH_REDUCED_RUN_ID"
(cd "$BASELINE_BUNDLE" && sha256sum --check SHA256SUMS)
(cd "$REDUCED_BUNDLE" && sha256sum --check SHA256SUMS)
node image/builder/build-documents.mjs validate-bundle \
  --metadata "$REDUCED_BUNDLE/artifact-metadata.json" \
  --iso "$REDUCED_BUNDLE/$(node -e 'const fs=require("node:fs"); const m=JSON.parse(fs.readFileSync(process.argv[1])); console.log(m.artifact.iso.name)' "$REDUCED_BUNDLE/artifact-metadata.json")" \
  --manifest "$REDUCED_BUNDLE/pkglist.x86_64.txt" \
  --checksums "$REDUCED_BUNDLE/SHA256SUMS"
MIRROROS_BASELINE_BUNDLE="$BASELINE_BUNDLE" \
MIRROROS_REDUCED_BUNDLE="$REDUCED_BUNDLE" \
bats tests/image/live-profile.contract.bats
```

Expected: every checksum and bundle validation passes; the resolved-manifest test runs rather than skips. All approved cuts must be absent, all retained declarations/dependency tools present, and every baseline firmware/microcode package retained. If a removed declaration resolves indirectly, stop for audit review rather than force removal. Inspect package versions in both manifests and the builder's `execution-result.json` for publication, scans and successful cleanup. A published-but-failed build is not accepted. Record source commit, dirty state, embedded code identity, OCI digest, Archiso version and tool versions from metadata. A dirty development build must be labeled as such, not counted clean qualification.

Set `ISO` to the exact validated filename, then inspect metadata:

```bash
ISO="$REDUCED_BUNDLE/$(node -e 'const fs=require("node:fs"); const m=JSON.parse(fs.readFileSync(process.argv[1])); console.log(m.artifact.iso.name)' "$REDUCED_BUNDLE/artifact-metadata.json")"
stat --format='%n %s bytes' "$ISO"
xorriso -indev "$ISO" -pvd_info
```

Expected: `mirroros-YYYY.MM.DD-x86_64.iso`, volume ID `MIRROROS_YYYYMM`, publisher `MirrorOS`, application `MirrorOS Live/Rescue`. The date must agree with the recorded `SOURCE_DATE_EPOCH`, not necessarily today's local date. Upstream technical paths such as `/arch/` remain valid.

### Prepare isolated run resources

This preparation creates only private local files, not a VM. Refuse symlinked `build/` or `evidence/` bases and occupied run paths; never adopt another run's resources. Keep the same shell variables for the session.

```bash
umask 077
RUN_ID="$(date -u +%Y%m%dT%H%M%SZ)-$(cat /proc/sys/kernel/random/uuid)"
WORK="$PWD/build/live-branding/$RUN_ID"
PRIVATE="$PWD/evidence/live-branding/$RUN_ID"
test ! -L build && test ! -L evidence
mkdir -p build/live-branding evidence/live-branding
test ! -L build/live-branding && test ! -L evidence/live-branding
mkdir "$WORK" "$PRIVATE"
CASE=btrfs-limine
DISK="$WORK/$CASE.qcow2"
VARS="$WORK/$CASE-OVMF_VARS.fd"
qemu-img create -f qcow2 "$DISK" 32G
cp -- /usr/share/edk2/x64/OVMF_VARS.4m.fd "$VARS"
```

Stop on any failed command. Repeat with a new case name and **new disk and vars copy** for `ext4-systemd-boot` and `btrfs-rescue`; never overwrite an existing disk. The settings below reuse q35/KVM/host CPU, 2 vCPUs, 4 GiB RAM, 32 GiB VirtIO disk and VirtIO SLIRP Ethernet from `vm/reference/reference-vm.conf`. Only the presentation is graphical and unseeded; this is not an `operations/test` result.

### Graphical launch, installed boot and rescue boot

Define the launch array in the host shell; defining it does not launch a VM:

```bash
QEMU_COMMON=(
  qemu-system-x86_64
  -machine q35,accel=kvm -cpu host -smp 2 -m 4096
  -nodefaults -no-user-config -display gtk
  -device VGA -device qemu-xhci -device usb-kbd -device usb-tablet
  -monitor none -serial none
  -smbios type=1,manufacturer=QEMU
  -drive "if=pflash,format=raw,unit=0,readonly=on,file=/usr/share/edk2/x64/OVMF_CODE.4m.fd"
  -drive "if=pflash,format=raw,unit=1,file=$VARS"
  -drive "if=none,id=disk0,format=qcow2,file=$DISK"
  -device virtio-blk-pci,drive=disk0,bootindex=2
  -netdev user,id=net0 -device virtio-net-pci,netdev=net0
)
```

**Gate: request approval for this exact ISO boot and case before executing:**

```bash
"${QEMU_COMMON[@]}" \
  -drive "if=none,id=iso,media=cdrom,format=raw,readonly=on,file=$ISO" \
  -device ide-cd,drive=iso,bus=ide.0,bootindex=1
```

Run in the foreground; record its exit status. No serial capture is enabled, to avoid capturing password input. Keep an attended deadline (5 minutes to a usable live console; up to 45 minutes for installation), record a timeout as failure and do not retry automatically. QEMU's console may grab the keyboard; Ctrl+Alt+G releases it. On normal completion, shut down **inside the guest** and wait for the host command to exit. Closing QEMU abruptly is a failure/interrupt, not orderly shutdown evidence. Do not delete files or launch another QEMU against this disk while a process still has it open.

After an installation and confirmed exit, request **separate authorization** for a disk-only boot:

```bash
"${QEMU_COMMON[@]}"
```

Expected: the installed bootloader appears without ISO or seed media, the installed system reaches a login prompt and the planned disposable user can log in. Record the selected boot entry, filesystem and account-policy observations. Do not expect the installed system's identity to become MirrorOS: installed-system branding is excluded. Do not call an installer success screen or this observation Story 2.6 postcondition qualification.

For rescue, shut down the installed guest normally and confirm QEMU exit. Create a **new** vars copy at `$WORK/$CASE-rescue-OVMF_VARS.fd` (refuse an existing path), set `VARS` to it and redefine `QEMU_COMMON` with that path. Retain the installed disk. Request **separate authorization** before rerunning the ISO-boot command. A new disk would not test rescue of the installed target.

### Attended live checklist

1. Inspect the UEFI boot menu: the primary entry says `MirrorOS Live/Rescue`; no speech/Braille boot entry or BIOS menu is offered. EFI shell and EFI memtest remain. Choose the primary entry.
2. On an unseeded tty1, the MirrorOS welcome starts automatically without initiating disk writes. Cancel through the UI; expect a root shell. Restart with `mirroros-install`, then cancel again; expect exit `3` when invoked from the shell. A blocked prerequisite is not a successful cancellation test.
3. From the live root shell, run:

   ```bash
   test -d /sys/firmware/efi
   hostname
   cat /etc/hostname /etc/motd /etc/os-release
   readlink /etc/os-release
   cat /usr/lib/os-release
   for tool in mirroros-install pacstrap genfstab arch-chroot node gum vim \
     lsblk blkid sfdisk partprobe mount mkfs.fat mkfs.ext4 mkfs.btrfs \
     filefrag btrfs iw iwctl rfkill wpa_supplicant ssh sshd; do
     command -v "$tool" || break
   done
   gum --version
   pacman -Q linux-firmware linux-firmware-marvell sof-firmware amd-ucode intel-ucode
   systemctl is-active sshd
   systemctl --failed --no-pager
   ```

   Expected: UEFI present, hostname `mirroros`, MirrorOS welcome/motd/effective `/etc/os-release`, `ID_LIKE=arch`, Gum major 2 and all commands available. `/etc/os-release` is expected to be the regular live-only override (`readlink` returns nonzero); `/usr/lib/os-release` retains package-owned Arch identity. Confirm actual behavior rather than infer it from the overlay. Firmware completeness is decided by resolved-manifest comparison, not just the five packages above. Record SSH status without starting it, altering credentials or changing authentication; report unexpected startup state. Review failed units for dangling removed consumers; unrelated failures still require a recorded reason.
4. Check the whole removed package set against the resolved manifest as above. In the guest, `command -v archinstall nano` should find neither, and `pacman -Q archinstall brltty espeakup livecd-sounds syslinux memtest86+` should report them absent. These expected nonzero probes are not suite failures. Verify no inherited speech/sound or removed-agent unit is being started. Keep EFI memtest distinct from removed BIOS memtest.
5. Check virtual Ethernet:

   ```bash
   ip -brief address
   ip route
   getent hosts archlinux.org
   curl --fail --silent --show-error --max-time 30 \
     --output /dev/null --write-out '%{http_code}\n' https://archlinux.org/
   ```

   Expected: VirtIO Ethernet has an IPv4 address and default route, DNS resolves, TLS succeeds with HTTP `200`. Record external network failures distinctly. This is virtual Ethernet only, never Wi-Fi qualification.

### Installation matrix

Run each case on its own fresh disk. Before **each destructive case**, request approval to erase only that case's guest disk, then run `mirroros-install` in tty1. Select the disk only after verifying it is `/dev/vda`, VirtIO, 32 GiB, and the sole attached writable disk. Never select the ISO. Walk the existing UI, review the complete plan and its digest, confirm the actual device name and enter a **disposable, non-personal password** only in the protected prompts. Do not record that password or reuse credentials. Do not alter defaults silently when the layout does not fit.

| Case | Choices | Expected existing behavior |
| --- | --- | --- |
| `btrfs-limine` | Default storage, hibernation on, locked root | 2 GiB FAT32 ESP at `/boot`, Btrfs flat `@` layout including `@swap`; Limine; installed success and disposable user login on disk-only boot |
| `ext4-systemd-boot` | ext4, hibernation on, root password policy | 2 GiB FAT32 ESP at `/boot`, ext4 root and swapfile; systemd-boot; installed success, disposable user and root login on disk-only boot |
| `btrfs-rescue` | Btrfs/systemd-boot, hibernation off, locked root | 2 GiB FAT32 ESP at `/boot`, `@`, `@home`, `@log`, `@pkg`, `@snapshots`, no `@swap`; systemd-boot; installed success and disposable user login on disk-only boot |

Expected: no disk writes before the actual bound confirmation/password/final revalidation; installation progress and success screens work, with exit `0` if returning to the shell. Record failure stage/status instead of treating a partially installed disk as success. Guest records normally live under the live shell's `evidence/install/<run-id>/`; inspect `install-run.json`, `install.log` and `engine/` privately before shutdown (live storage is ephemeral). Do not attach a shared folder or publish raw records to retain them: record a sanitized verdict and relevant non-secret fields in the host worksheet. No automatic destructive retry; regenerate and review a new plan after a failure.

This matrix observes the Story 2.5 engine. It does not implement configuration, desktop readiness, Story 2.6 verification, snapshot restoration or hibernation qualification. Use ordinary shutdown, not hibernation, before rescue; never boot a Limine snapshot with a pending hibernation image.

### Rescue mounting and arch-chroot

For each installed disk, boot the same ISO again using fresh vars and separate launch approval, cancel the automatic assistant and inspect partitions. These commands are **guest-only**; do not run them in the host shell. Verify UUIDs/types against the case's plan and installation observations before mounting. Stop if `/dev/vda1` is not the FAT32 ESP or `/dev/vda2` is not the expected ext4/Btrfs root.

```bash
lsblk -o NAME,SIZE,TYPE,FSTYPE,UUID,MOUNTPOINTS
blkid /dev/vda1 /dev/vda2
mkdir -p /mnt/mirroros-rescue
```

For ext4:

```bash
mount /dev/vda2 /mnt/mirroros-rescue
mkdir -p /mnt/mirroros-rescue/boot
mount -o umask=0077 /dev/vda1 /mnt/mirroros-rescue/boot
```

For either Btrfs case, first inspect the flat layout read-only:

```bash
mkdir -p /mnt/mirroros-top
mount -o ro,subvolid=5 /dev/vda2 /mnt/mirroros-top
btrfs subvolume list /mnt/mirroros-top
umount /mnt/mirroros-top
mount -o compress=zstd:1,subvol=@ /dev/vda2 /mnt/mirroros-rescue
mkdir -p /mnt/mirroros-rescue/{boot,home,var/log,var/cache/pacman/pkg,.snapshots}
mount -o compress=zstd:1,subvol=@home /dev/vda2 /mnt/mirroros-rescue/home
mount -o compress=zstd:1,subvol=@log /dev/vda2 /mnt/mirroros-rescue/var/log
mount -o compress=zstd:1,subvol=@pkg /dev/vda2 /mnt/mirroros-rescue/var/cache/pacman/pkg
mount -o compress=zstd:1,subvol=@snapshots /dev/vda2 /mnt/mirroros-rescue/.snapshots
mount -o umask=0077 /dev/vda1 /mnt/mirroros-rescue/boot
```

Only when the recorded case has `@swap`, additionally mount it at `/mnt/mirroros-rescue/swap` with `subvol=@swap`; do **not** run `swapon` or recreate the swapfile. The existing layout and `/etc/fstab` must agree. These read-write mounts exercise normal chroot rescue on a disposable disk, not forensic read-only recovery.

For every case:

```bash
findmnt -R /mnt/mirroros-rescue
arch-chroot /mnt/mirroros-rescue /bin/bash
# Inside the target chroot:
cat /etc/fstab
cat /etc/os-release
ls /boot
exit
# Back in the live guest:
umount -R /mnt/mirroros-rescue
findmnt -R /mnt/mirroros-rescue
```

Expected: the root and FAT ESP are mounted at the intended paths, every selected Btrfs subvolume is mounted correctly, `arch-chroot` opens the **target** Bash and can read the target fstab, target identity and boot files; it exits normally. All mounts then release (the final `findmnt` returns nonzero/no mount). Do not run package upgrades, regenerate boot files, change accounts or restore snapshots in this minimal rescue test. The installed identity is not governed by live branding. Stop on a failed command and document any residual mounts; do not delete an active disk. Shut down the guest normally and confirm host QEMU exit.

### Separate Wi-Fi-device checklist

Without an available, explicitly authorized device/environment, mark every runtime Wi-Fi check **pending / device unavailable**. QEMU's VirtIO Ethernet cannot satisfy it. This guide authorizes no physical-disk exercise, USB passthrough, network/service changes on the host or broader hardware support claim.

For a separately approved live session with a real Wi-Fi device and no host storage exposure:

- Record only non-sensitive adapter/driver/firmware identification, not MAC addresses, SSIDs, passwords or host inventories.
- Check `iw dev`, `rfkill list`, `iwctl device list` and `systemctl is-active iwd`; expect the adapter to be detected, firmware loaded and the radio usable.
- Use the existing installer Wi-Fi instructions and `iwctl` interactively to connect to an approved test network. Enter any secret only through a protected prompt, never a command argument or evidence file. Do not indiscriminately disable radios or change SSH policy.
- Confirm address, route, DNS and TLS using the Ethernet probes above, now on the wireless interface. Record pass/fail for device detection and actual connectivity separately.
- Record wpa_supplicant availability separately; its retained fallback is not automatically qualified by a successful iwd connection.
- Disconnect the test connection through the same approved setup; keep credentials and raw wireless logs private. No accessibility or universal-adapter claim follows from this check.

### Measurements and comparison limits

The inspected baseline ISO is **1,682,014,208 bytes**. Its private `evidence/archiso-build/20261012T234437Z-1e6dbbfd-61ef-4ef7-b0a9-c7b59bd3bc85/execution-result.json` records a successful build from `2026-10-12T23:44:37Z` to `2026-10-12T23:53:03Z`, **506 seconds (506,000 ms)**. This is end-to-end builder duration, not isolated mkarchiso time. Hardware/load and prior cache warmth have not been established for that historical run; the duration is not fabricated but is not yet comparable evidence.

Before each authorized new build, record CPU model/core count, RAM, storage type/free space, host kernel, relevant tool versions, network conditions and other workload in the private worksheet. Avoid hostnames, serial numbers or full inventories. Record default cache mount versus `--no-cache`, known warmth and image-layer/AUR/download reuse separately. `--no-cache` omits the Pacman volume; it does not establish that every layer/download is cold. Do not delete a cache or change the builder to improve this comparison.

Use the existing [build command](build.md#invocation) only after separate authorization, then read the run's total `duration_seconds`, start/end timestamps, artifact metadata and resolved manifest. If comparable baseline evidence needs a rebuild, stop and agree an isolated baseline checkout and exact source before it; do not undo the current tree or run an unapproved second build. Rolling package versions, OCI digest, hardware/load, network and cache differences must be listed, not attributed to trimming.

Calculate after both exact artifacts are available:

```bash
BASELINE_ISO="$BASELINE_BUNDLE/$(node -e 'const fs=require("node:fs"); const m=JSON.parse(fs.readFileSync(process.argv[1])); console.log(m.artifact.iso.name)' "$BASELINE_BUNDLE/artifact-metadata.json")"
node - "$BASELINE_ISO" "$ISO" <<'NODE'
const fs = require('node:fs');
const baseline = fs.statSync(process.argv[2]).size;
const reduced = fs.statSync(process.argv[3]).size;
console.log(JSON.stringify({ baseline_bytes: baseline, reduced_bytes: reduced,
  bytes_saved: baseline - reduced,
  size_change_percent: 100 * (reduced - baseline) / baseline,
  reduction_percent: 100 * (baseline - reduced) / baseline }, null, 2));
NODE
```

Negative `size_change_percent` and positive `bytes_saved` mean a smaller artifact. Record elapsed totals in ms (existing seconds multiplied by 1000) with their scope. A shorter single run does not prove a build-time improvement. AC-5 requires a smaller reduced ISO under documented comparable conditions; missing or materially incomparable evidence blocks completion, without a fixed maximum size. Official Arch media is optional contextual information, not a mandatory benchmark.

### Private verdict worksheet and failure handling

Keep the completed worksheet only under `$PRIVATE/verdict.md`, with private permissions; publish at most a sanitized conclusion and evidence reference. Fill in actual results, not prechecked boxes. Obtain maintainer approval of the recorded verdicts only after required checks pass.

```text
Artifact/run ID and SHA-256:
Source/embedded identity and dirty state:
Baseline/reduced bundle and build evidence references:
Host and tool versions; QEMU/OVMF code hash:
Cache/network/load and rolling-version differences:
Authorization per build/VM/erase case (scope and time):

Check                              Verdict (pass/fail/pending)   Evidence/reason
Bundle/checksum/resolved packages  pending                       not run
ISO metadata and boot menu         pending                       not run
Live identity/override/hostname    pending                       not run
Automatic welcome/cancel/restart   pending                       not run
Retained tools/firmware/SSH state  pending                       not run
Removed packages/startup cleanup  pending                       not run
Virtual Ethernet/DNS/TLS           pending                       not run
btrfs-limine install/disk boot     pending                       not run
ext4 install/disk boot             pending                       not run
btrfs-rescue install/disk boot     pending                       not run
ext4 mount/ESP/arch-chroot/unmount  pending                       not run
Btrfs mounts/ESP/chroot (each case) pending                       not run
Wi-Fi detection/connectivity      pending                       device unavailable
Size/timing/comparability          pending                       reduced artifact missing
Evidence scan and cleanup          pending                       not run

Baseline bytes: 1682014208; total duration_ms: 506000 (historical)
Reduced bytes / duration_ms:
Bytes saved / size change_percent / reduction_percent:
Comparison limitations and acceptance consequence:
Failed stage, expected/actual behavior, status, next action:
Maintainer verdict approval and date: pending
AC-2 / AC-3 / AC-4 / AC-5: pending
```

On failure, stop the dependent check, record artifact/case, exact non-secret command or UI step, expected/actual result, status and failing stage. Inspect guest records locally before shutdown; do not copy passwords, raw sensitive logs or screenshots into public documentation. Leave missing physical Wi-Fi evidence pending rather than relabel Ethernet. Do not remediate SSH, change target policy or implement Story 2.6 to make this checklist pass; escalate out-of-scope fixes for exact-path approval.

Scan the private worksheet and any approved retained diagnostics with `gitleaks dir "$PRIVATE" --redact`; retain findings privately and block acceptance until reviewed. A clean scan does not prove an entire ISO or disk contains no secrets. Installed qcow2 files contain disposable account state; keep them private and temporary.

### Cleanup

After each guest's ordinary shutdown, confirm the foreground QEMU command has returned and that no QEMU process references this run (`pgrep -af -- "$WORK"`; no matches is expected). If exit cannot be confirmed, preserve resources and stop for recovery authorization; never use a broad kill command. Keep the validated bundles and private verdict/build evidence.

Only after explicit approval to delete **this run's disposable files**, inspect the exact paths, confirm `WORK` is the recorded non-symlinked `build/live-branding/<run-id>` directory and remove the three case qcow2 files and their installation/rescue vars copies by exact filename. Remove the now-empty run directory with `rmdir`; do not use a broad recursive cleanup or delete another run. Record cleanup status and any leftovers. No build, VM, erase or cleanup operation is authorized merely by reading this procedure.

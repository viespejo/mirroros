# ISO Size and Live Branding — Decision Log

## DEC-001
- **Question**: How broadly should Arch Linux branding be replaced?
- **Context/Nuances**: The project-owned Archiso profile still uses Arch Linux ISO metadata and visible live-media identity. Technical upstream references and attribution must remain accurate; replacement is not a global text substitution.
- **User Response**: "yes, agrega directamente la decision." The user subsequently approved persistence and this backfilled registration with "yes".
- **Decision**: Replace the visible live-media identity with MirrorOS, including ISO filename, volume label, metadata, boot menus, welcome, and live-system identification. Preserve necessary repository, key, package, official URL, and attribution references. Installed-system branding is out of scope.
- **Status**: Accepted

## DEC-002
- **Question**: What package-removal policy should reduce ISO size?
- **Context/Nuances**: The existing artifact is 1,682,014,208 bytes. Its excess size has not yet been attributed to particular packages. The profile already uses XZ SquashFS compression. Minimal rescue must remain possible, rather than retaining an unrestricted general-purpose rescue suite. The user expressly requires accounting for every tool used by the MirrorOS installer.
- **User Response**: "Bueno el recate mínimo para poder arrancar y montar cosas o hacer chroot...tu sabes. agrega directamente la decision"; registration approved with "yes...por favor tengamos en cuenta cualquier herramienta que estemos usando en mirroros para el instalador".
- **Decision**: Focus the live ISO on MirrorOS installation and minimal rescue: booting, inspecting disks, mounting supported filesystems, and using arch-chroot. Preserve Ethernet/Wi-Fi, initially the complete firmware set, basic diagnostics, and tools needed by accepted storage options. Before removing packages, audit all tools used by the MirrorOS installer, including indirect dependencies and alternative execution paths. Remove unjustified general-purpose tools together with their associated configuration. No specific package removal is approved yet.
- **Status**: Accepted

## TODO-001
- **Question**: Which packages and associated overlays can actually be removed without breaking required capabilities?
- **Context/Nuances**: A declared package may be required indirectly or by a less common installation path. Package names alone do not establish removability or compressed-size savings.
- **User Response**: The user explicitly requested that every tool used by the installer be considered.
- **Decision**: Audit installer and validation dependencies, map retained packages to installation, networking, boot, diagnosis, and rescue capabilities, and verify the reduced profile before acceptance.
- **Status**: Pending

## DEC-003
- **Question**: Should ISO reduction have a fixed size target or use official Arch media as a target?
- **Context/Nuances**: The official Arch download page reports release 2026.10.01 at a rounded 1.5 GB (https://archlinux.org/download/). That is contextual evidence, not a byte-exact or package-equivalent comparison. The user prioritizes removing tools that will never be used and avoiding their build-time cost. DEC-002's installer, minimal-rescue, and initial full-firmware preservation requirements remain binding.
- **User Response**: "bajemos todo lo que podamos...no queremos dejar herramientas que no usaremos nunca y que nos está añadiendo tiempo en el build"; registration approved with "yes, agrega directamente la decision."
- **Decision**: Minimize packages without a justified MirrorOS live use to reduce ISO size and build duration. Set no mandatory size target; official Arch ISO size is only contextual reference. Preserve required installer tools, indirect dependencies, minimal rescue, and initially the complete firmware set. Audit usage and dependencies and measure both artifact size and build duration before and after; do not claim package-specific improvements without evidence.
- **Status**: Accepted

## DEC-004
- **Question**: Should archinstall remain as an alternative installer?
- **Context/Nuances**: MirrorOS provides its own guided installer, but vm/reference/guest/bootstrap-checks.sh currently requires archinstall alongside pacstrap, genfstab, and arch-chroot. Removing the package without updating that qualification requirement would break validation.
- **User Response**: "yes, agrega directamente la decision."
- **Decision**: Remove archinstall from the live package declaration and remove its presence requirement from reference-VM validation. Preserve pacstrap, genfstab, and arch-chroot for native installation and minimal rescue. Update affected tests and documentation consistently; do not weaken validation of the retained capabilities.
- **Status**: Accepted

## DEC-005
- **Question**: Should inherited speech-boot and Braille accessibility functions remain?
- **Context/Nuances**: The inherited profile includes dedicated accessibility packages, services, sounds, and boot entries. MirrorOS currently qualifies only its colored interactive live console, not an accessible installer flow. Console keyboard, font, and terminal requirements must not be conflated with these inherited functions.
- **User Response**: "yes, agrega directamente la decision."
- **Decision**: Remove inherited speech-boot and Braille functions, their dedicated packages, services, sounds, and associated boot entries. Preserve keyboard, font, and terminal tools needed by MirrorOS. Audit dependency ownership before selecting exact package removals; make no accessibility qualification claim.
- **Status**: Accepted

## DEC-006
- **Question**: Which editor should remain for minimal live rescue?
- **Context/Nuances**: The profile currently declares both nano and vim. The user prefers Vim. This choice applies only to the live medium, not the target-system package policy.
- **User Response**: "soy un entusiasta de vim"; registration approved with "yes, agrega directamente la decision."
- **Decision**: Keep vim as the live editor and remove nano unless the dependency audit demonstrates a necessary dependency. Do not change installed-system editor policy.
- **Status**: Accepted

## DEC-007
- **Question**: Should unsupported BIOS/Legacy boot and its exclusive components remain?
- **Context/Nuances**: The architecture guarantees and validates UEFI/OVMF only and permits, but does not require, retaining inherited BIOS/Syslinux assets. The installer rejects BIOS boot. A tool or asset may be shared with UEFI and must not be removed solely because it also supports BIOS.
- **User Response**: "yes, agrega directamente la decision."
- **Decision**: Remove BIOS/Legacy boot from the live profile and remove Syslinux and other BIOS-exclusive resources. Preserve UEFI boot and shared dependencies required by UEFI or the installer. Do not change installed-system boot choices or introduce new support claims.
- **Status**: Accepted

## DEC-008
- **Question**: Is SSH needed in the live medium for remote installation or rescue?
- **Context/Nuances**: Current VM qualification communicates through serial output rather than SSH, but the user explicitly wants SSH retained. Keeping the package does not decide server autostart or authentication policy.
- **User Response**: "lo queremos dentro"; registration approved with "yes, agrega directamente la decision."
- **Decision**: Keep openssh in the live medium for remote access and do not remove its associated configuration during package reduction. Review the existing server startup and authentication behavior before deciding whether it should change; no automatic exposure or authentication change is approved.
- **Status**: Accepted

## DEC-008 — Scope clarification
- **Question**: Should this plan change SSH startup or authentication after retaining OpenSSH?
- **Context/Nuances**: The checked-in profile enables sshd through a systemd wants symlink and permits root password authentication; its root shadow entry has an empty password field. These source observations do not prove that sshd was running in the user's booted artifact. The user recalls that SSH may not have been active. A proposed manual-start decision (DEC-009) was not accepted.
- **User Response**: "de momento mejor solo registremos que no queremos remover openssh...la configuración la que traiga por defecto, si?"
- **Decision**: Limit DEC-008 to retaining OpenSSH with the existing inherited profile defaults. Do not change SSH startup, authentication, or credentials in this delivery. Resolving the observed runtime discrepancy is not a prerequisite for package reduction. No DEC-009 is accepted.
- **Status**: Accepted

## DEC-009
- **Question**: Which exact ISO branding values should be used?
- **Context/Nuances**: Date-based versioning remains useful for artifact identification. Technical Archiso paths are not visible product identity and renaming them creates unnecessary integration risk. The earlier proposed SSH manual-start decision was never accepted; this ID is assigned to the accepted branding decision.
- **User Response**: "yes, agrega directamente la decision."
- **Decision**: Use mirroros-YYYY.MM.DD-x86_64.iso for the ISO filename, MIRROROS_YYYYMM for the volume label, MirrorOS for the publisher without inventing a URL, MirrorOS Live/Rescue for the application, and mirroros for the live hostname. Keep date-based versioning and existing technical Archiso internal paths.
- **Status**: Accepted

## DEC-010
- **Question**: How should remaining package removals be approved without guessing their use during the interview?
- **Context/Nuances**: Package names do not establish actual usage, indirect dependencies, or shared ownership. The audit must include installer paths, VM qualification, networking, and minimal rescue. Advanced rescue tools, VPN/modem tools, and other hypervisor agents are candidates, not automatically approved removals.
- **User Response**: "yes, agrega directamente la decision."
- **Decision**: The first implementation task produces a reviewable per-package table covering keep/remove, rationale, provided tools, dependencies, and affected configuration. Require explicit maintainer review before applying remaining removals. Previously accepted concrete choices remain binding. Do not infer approval for candidate categories solely from their names.
- **Status**: Accepted

## DEC-011
- **Question**: What verification should accept the reduced ISO?
- **Context/Nuances**: The user requires a guide that can be checked manually in QEMU. Existing automated tests complement, rather than replace, attended verification. Ordinary QEMU Ethernet does not establish physical Wi-Fi compatibility. No physical disk may be used for the rescue exercises.
- **User Response**: "si, pero basdosbasados en una guia que podamos comprobar manualmente en qemu"; registration approved with "yes, agrega directamente la decision."
- **Decision**: Deliver a reproducible manual QEMU/UEFI guide covering branding, installer startup, installation, and minimal rescue with ext4/Btrfs mounts and arch-chroot, using disposable virtual disks only. Preserve existing automated tests as complementary checks. Verify Ethernet in QEMU; document Wi-Fi as an additional check requiring an available device without claiming ordinary QEMU validates it. Include commands, expected results, artifact-size and build-time comparison, and a result checklist. Each build and VM execution still requires explicit authorization.
- **Status**: Accepted

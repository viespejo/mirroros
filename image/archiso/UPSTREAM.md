# Archiso `releng` upstream record

## Import identity

- **Upstream project:** Archiso
- **Canonical upstream repository:** `https://gitlab.archlinux.org/archlinux/archiso.git`
- **Upstream tag:** `v91`
- **Upstream commit:** `723da192226e1c9d5def9168f13332793c82a85e`
- **Package version:** `91-1`
- **Canonical packaging repository:** `https://gitlab.archlinux.org/archlinux/packaging/packages/archiso.git`
- **Packaging tag:** `91-1`
- **Packaging commit:** `6ed3a48a0c00cdc9d709043f02f20ff820f4a7b0`
- **Package filename:** `archiso-91-1-any.pkg.tar.zst`
- **Package SHA-256:** `3d08984593f235fc5de8ec379bdf7860fbcd2e62fa7e36b14dc53ba663289d1c`
- **Package origin:** Official Arch `extra` repository, validated using the configured Pacman signature policy.
- **Acquisition image:** `docker.io/archlinux/archlinux@sha256:0d5d0f0c0437027c72489485079c8968793a7fa5290e045d4816a936dc4640a1`
- **Image platform:** `linux/amd64`
- **Image signature identity:** Cosign keyless signature verified against the identity regexp documented by the official [Arch Linux OCI image project](https://gitlab.archlinux.org/archlinux/archlinux-docker/-/blob/master/README.md): `https://gitlab\.archlinux\.org/archlinux/archlinux-docker//\.gitlab-ci\.yml@refs/tags/v[0-9]+\.0\.[0-9]+`
- **OIDC issuer:** `https://gitlab.archlinux.org`
- **UTC import date:** `2026-10-04` (evidence timestamp `20261004T171704Z`)
- **Source path:** `/usr/share/archiso/configs/releng/`
- **Import method:** Resolve and Cosign-verify the official Arch-owned OCI image digest; install Archiso from the signed official `extra` repository; run `pacman -Qkk archiso`; export the profile with `docker cp`; compare the complete path set, path types, file contents, symlink targets, and executable bits before committing the pure vendor snapshot.
- **Pacman container note:** The OCI image's `NoExtract` rules excluded package-owned documentation and manual paths. For this import only, those two patterns were temporarily removed inside disposable acquisition containers so `pacman -Qkk archiso` could check every package-owned path. The configured `SigLevel` was unchanged, and no host configuration was modified.
- **Vendor import commit:** `bc4cd22b0e4294914f38f4ba800b88474ab3a50a`

## Licensing and boot scope

The incorporated upstream profile remains under `GPL-3.0-or-later`, with its upstream notices retained. Original MirrorOS material remains under `GPL-3.0-only`; incorporation does not relicense the upstream files.

The supported boot scope is **UEFI/OVMF only**, using systemd-boot. The reviewed live-profile reduction removes BIOS/Syslinux resources and inherited speech/Braille helpers; shared Archiso hooks and dependencies remain. External GRUB loopback configuration is retained without claiming a qualified additional boot path.

## Local delta

- **Baseline:** vendor import commit `bc4cd22b0e4294914f38f4ba800b88474ab3a50a`.
- **Functional summary:** Embed the MirrorOS installer entry point and tty1 startup integration, Node.js/Gum runtime declarations and executable permissions; preserve NoCloud orchestration. Apply the [approved package audit](../../docs/procedures/iso-size-and-live-branding.md): 62 retained x86_64 declarations, 69 removed declarations, associated service/agent/speech and BIOS resource cleanup. Set MirrorOS ISO metadata, live hostname, welcome and boot titles; add a live-only regular `/etc/os-release` override with Arch lineage. Preserve upstream technical paths, firmware, network configuration, SSH policy and package signature policy. Installed-system policy is separate. Under [ADR 0018](../../docs/adr/0018-native-live-display-and-installer-presentation.md), the single normal live entry preserves the firmware/kernel display choice without a MirrorOS mode request; the ADR 0017 preference and redundant native-display entry are removed. Both retained GRUB configurations carry the same reversal without expanding boot qualification. No package, persistent font, installed boot parameter, or graphical scaling policy changes.
- **Shared live splash (ADR 0019):** Add official-repository `plymouth` as a live-only presentation dependency beyond the 62-declaration reduction baseline (63 current declarations). Its rolling version is recorded in the built native package manifest. Add its hook immediately after `udev` and `quiet splash` once to normal systemd-boot and retained GRUB lines, preserving other hooks, root arguments, firmware/kernel display choice, editor policy and installer startup. The builder installs official-repository `librsvg` in the build container (not a new live declaration), then renders/validates branding and copies the original MirrorOS theme from captured capabilities into container-local `/live-profile`; captured `/profile` stays read-only. No vendor import or third-party theme code is added. [Build procedure](../../docs/procedures/build.md#construction-and-timeouts) and [ADR 0019](../../docs/adr/0019-shared-symbol-and-live-splash.md) govern this additive delta; the previous no-package-change statement describes ADR 0018 only.
- **Installer coexistence (ADR 0022):** Capture the original MirrorOS `operations/boot-first` command and `operations/lib/uefi-boot-entry.sh` alongside the existing installer/configure code. Declare ISO modes `0:0:755` for the command and `0:0:644` for the library in `profiledef.sh`, independent of checkout modes. The live engine uses the shared library for explicit firmware registration and delivers the installed command for manually restoring MirrorOS-first order; no automatic service or live launcher is added. [ADR 0022](../../docs/adr/0022-installer-coexistence-and-uefi-boot-entry.md) and the [build procedure](../../docs/procedures/build.md) govern this extension. Capture and static permission tests do not establish ISO build, firmware, or hardware qualification; those remain pending.
- **Statistics:** Use the baseline comparison below for the reviewed integration commit; include new profile paths before recording final statistics. `UPSTREAM.md` is excluded. No generated image or embedded code payload is committed.

Run from `main` after the merge commit; `HEAD` then identifies the reviewed integration commit:

```sh
VENDOR_BASELINE_COMMIT='bc4cd22b0e4294914f38f4ba800b88474ab3a50a'
git diff --no-ext-diff --binary "$VENDOR_BASELINE_COMMIT" HEAD \
  -- image/archiso ':(exclude)image/archiso/UPSTREAM.md'
git diff --stat "$VENDOR_BASELINE_COMMIT" HEAD \
  -- image/archiso ':(exclude)image/archiso/UPSTREAM.md'
```

## Qualification states

The ADR 0018 reversal, installer presentation, and ADR 0019 shared animated live splash have not been built or boot-qualified. Prior artifacts
and attended temporary-preview observations do not qualify this source delta. Effective geometry,
font restoration, cancellation, and remaining installer screens require attended verification.

- **Aggregate signature validation:** passed (Cosign image signature and Pacman package signature).
- **Import integrity:** passed (`pacman -Qkk archiso`; exported profile comparison).
- **Secret scan:** passed (vendor profile and acquisition evidence).
- **Reduced/branded profile build qualification:** pending; previous artifacts do not qualify this delta.
- **Reduced/branded profile UEFI/OVMF boot qualification:** pending attended verification and resolved manifest inspection. Static contract tests do not establish runtime acceptance.

Acceptance checks for the failure drill, cached import, and uncached verification all passed. The failure drill rejected a deliberately modified copy while preserving the acquisition container until diagnostics were exported and Gitleaks passed. The cached import reused the package archive. The uncached run matched package version `91-1`, the package SHA-256 above, and the imported profile. Detailed evidence is retained under `evidence/archiso-import/20261004T171704Z-91-1/`; failure-drill evidence is under `evidence/archiso-import/20261004T170955Z-failure-drill/`.

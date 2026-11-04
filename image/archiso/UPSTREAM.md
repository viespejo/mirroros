# Archiso `releng` upstream record

## Import identity

- **Upstream project:** Archiso
- **Canonical upstream repository:** `https://gitlab.archlinux.org/archlinux/archiso.git`
- **Upstream tag:** `v92`
- **Upstream commit:** `8e3ead17e1e5cfde503534d23be918b8787d3dd3`
- **Package version:** `92-1`
- **Canonical packaging repository:** `https://gitlab.archlinux.org/archlinux/packaging/packages/archiso.git`
- **Packaging tag:** `92-1`
- **Packaging commit:** `eae5a23075bf9100d00155449a22d36c940b3b7e`
- **Package filename:** `archiso-92-1-any.pkg.tar.zst`
- **Package SHA-256:** `a79f7a3a3032295e9d041c759e47ee4324166aa4c1cf19a4c3e5550ade5312e2`
- **Package origin:** Official Arch `extra` repository, validated using the configured Pacman signature policy.
- **Acquisition image:** `docker.io/archlinux/archlinux@sha256:49a539200d95722694b26b4cab2c91c9f7bf72ca8e3c9d3ec1d5dfd172a69952`
- **Image platform:** `linux/amd64`
- **Image signature identity:** Cosign keyless signature verified against the identity regexp documented by the official [Arch Linux OCI image project](https://gitlab.archlinux.org/archlinux/archlinux-docker/-/blob/master/README.md): `https://gitlab\.archlinux\.org/archlinux/archlinux-docker//\.gitlab-ci\.yml@refs/tags/v[0-9]+\.0\.[0-9]+`
- **OIDC issuer:** `https://gitlab.archlinux.org`
- **UTC import date:** `2026-11-04` (evidence timestamp `20261104T224829Z`)
- **Source path:** `/usr/share/archiso/configs/releng/`
- **Import method:** Resolve and Cosign-verify the official Arch-owned OCI image digest; install Archiso from the signed official `extra` repository; run `pacman -Qkk archiso`; export the profile with `docker cp`; compare the complete path set, path types, file contents, symlink targets, and executable bits before committing the pure vendor snapshot.
- **Pacman container note:** The OCI image's `NoExtract` rules excluded package-owned documentation and manual paths. For this import only, those two patterns were temporarily removed inside disposable acquisition containers so `pacman -Qkk archiso` could check every package-owned path. The configured `SigLevel` was unchanged, and no host configuration was modified.
- **Vendor import commit:** `824022d16d7ffd2646d7226b7b13e8b43592b020`

## Licensing and boot scope

The incorporated upstream profile remains under `GPL-3.0-or-later`, with its upstream notices retained. Original MirrorOS material remains under `GPL-3.0-only`; incorporation does not relicense the upstream files.

The supported boot scope is **UEFI/OVMF only**, using systemd-boot. The reviewed live-profile reduction removes BIOS/Syslinux resources and inherited speech/Braille helpers; shared Archiso hooks and dependencies remain. External GRUB loopback configuration is retained without claiming a qualified additional boot path.

## Local delta

- **Baseline:** vendor import commit `824022d16d7ffd2646d7226b7b13e8b43592b020`.
- **Functional summary:** Embed the MirrorOS installer entry point and tty1 startup integration, Node.js/Gum runtime declarations and executable permissions; preserve NoCloud orchestration. Apply the [approved package audit](../../docs/procedures/iso-size-and-live-branding.md): 62 retained x86_64 declarations, 69 removed declarations, associated service/agent/speech and BIOS resource cleanup. Set MirrorOS ISO metadata, live hostname, welcome and boot titles; add a live-only regular `/etc/os-release` override with Arch lineage. Preserve upstream technical paths, firmware, network configuration, SSH policy and package signature policy. Installed-system policy is separate. Under [ADR 0018](../../docs/adr/0018-native-live-display-and-installer-presentation.md), the single normal live entry preserves the firmware/kernel display choice without a MirrorOS mode request; the ADR 0017 preference and redundant native-display entry are removed. Both retained GRUB configurations carry the same reversal without expanding boot qualification. No package, persistent font, installed boot parameter, or graphical scaling policy changes.
- **Shared live splash (ADR 0019):** Add official-repository `plymouth` as a live-only presentation dependency beyond the 62-declaration reduction baseline (63 current declarations). Its rolling version is recorded in the built native package manifest. Add its hook immediately after `udev` and `quiet splash` once to normal systemd-boot and retained GRUB lines, preserving other hooks, root arguments, firmware/kernel display choice, editor policy and installer startup. The builder installs official-repository `librsvg` in the build container (not a new live declaration), then renders/validates branding and copies the original MirrorOS theme from captured capabilities into container-local `/live-profile`; captured `/profile` stays read-only. No vendor import or third-party theme code is added. [Build procedure](../../docs/procedures/build.md#construction-and-timeouts) and [ADR 0019](../../docs/adr/0019-shared-symbol-and-live-splash.md) govern this additive delta; the previous no-package-change statement describes ADR 0018 only.
- **Installer coexistence (ADR 0022):** Capture the original MirrorOS `operations/boot-first` command and `operations/lib/uefi-boot-entry.sh` alongside the existing installer/configure code. Declare ISO modes `0:0:755` for the command and `0:0:644` for the library in `profiledef.sh`, independent of checkout modes. The live engine uses the shared library for explicit firmware registration and delivers the installed command for manually restoring MirrorOS-first order; no automatic service or live launcher is added. [ADR 0022](../../docs/adr/0022-installer-coexistence-and-uefi-boot-entry.md) and the [build procedure](../../docs/procedures/build.md) govern this extension. Capture and static permission tests do not establish ISO build, firmware, or hardware qualification; those remain pending.
- **Archiso 92 integration:** Adopt upstream's removal of `kms` while retaining `plymouth` immediately after `udev` and the local omission of `memdisk`. Early graphics and the live splash require renewed UEFI/OVMF qualification; static checks do not establish their behavior. Adopt architecture-specific Memtest86+ EFI filenames in systemd-boot and retained GRUB entries, keeping the local removal of the speech and BIOS memtest entries. Retain the unmodified upstream IA32, AA64 and LOONGARCH64 memtest entries for provenance, without expanding the x86_64 UEFI/OVMF support scope. Upstream removes `linux-atm`; it was already absent from the reduced x86_64 profile, so the 63 local declarations are unchanged (the historical audit's 69 removals now include one upstream removal). The packaged aarch64 declaration follows upstream without claiming aarch64 support.
- **Statistics:** Relative to the vendor baseline, excluding `UPSTREAM.md`: 2 added, 10 modified and 24 deleted paths. Use the comparison below to reproduce line and binary statistics for the reviewed integration commit. No generated image or embedded code payload is committed.

Run from `main` after the merge commit; `HEAD` then identifies the reviewed integration commit:

```sh
VENDOR_BASELINE_COMMIT='824022d16d7ffd2646d7226b7b13e8b43592b020'
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
- **Secret scan:** vendor-profile, post-sanitation working-tree and import-evidence scans passed with zero findings. The history scan reports two pre-existing `generic-api-key` findings in `tests/install/confirmation/confirm-plan.contract.bats`, reviewed as synthetic password-isolation test data. The maintainer explicitly accepted those two false positives as an import-specific exception to the procedure's zero-findings requirement. The original redacted report is retained; no history rewrite, scanner configuration change or exclusion was applied. See the local evidence summary and `history-findings-review.md`.
- **Reduced/branded profile build qualification:** pending; previous artifacts do not qualify this delta.
- **Reduced/branded profile UEFI/OVMF boot qualification:** pending attended verification and resolved manifest inspection. Static contract tests do not establish runtime acceptance.

The `92-1` acquisition used a fresh unprivileged container without a shared Pacman cache. Cosign verification, signed package installation, `pacman -Qkk archiso`, export ownership and the vendor comparison passed. The packaging revision selects upstream tag `v92`. Import integration does not qualify the resulting ISO: build and UEFI/OVMF boot were explicitly deferred by the maintainer and remain pending, including live Plymouth after the upstream `kms` removal. Detailed command outcomes, static-test results, scans and clean-clone verification are retained under `evidence/archiso-import/20261104T224829Z-update/`.

Static verification: all 21 image/builder Node tests and ShellCheck passed. The full image Bats suite has 83 passing tests, one bundle-dependent skip and one pre-existing failure: the executable `capabilities/desktop/shell/services/wallpaper-thumbnails` lacks a `profiledef.sh` permission entry. The same permission test fails on the pre-update `main` snapshot; it was not changed as part of this import. This outstanding issue and deferred build/boot qualification prevent claiming full image acceptance.

The initial working-tree scan stopped on pre-existing ignored evidence. With maintainer authorization, 11 affected local evidence files were sanitized, without changing tracked source or adding scan exceptions; the rescan passed. The affected upstream excerpts are no longer byte-identical and the preview manifest's redacted hashes no longer prove source identity. Paths, rules and integrity limitations are recorded in the import evidence's `evidence-sanitization.json`.

Historical `91-1` import evidence remains at `evidence/archiso-import/20261004T171704Z-91-1/`; its failure-drill evidence remains at `evidence/archiso-import/20261004T170955Z-failure-drill/`. Those earlier cached, uncached and failure-drill checks were not repeated for `92-1` and do not qualify the new import.

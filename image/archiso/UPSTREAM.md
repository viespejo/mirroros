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

The supported boot scope is **UEFI/OVMF only**. BIOS and Syslinux assets are retained unchanged from upstream but are unsupported and unqualified.

## Local delta

- **Baseline:** vendor import commit `bc4cd22b0e4294914f38f4ba800b88474ab3a50a`.
- **Functional summary:** `None`.
- **Statistics:** 0 added paths, 0 modified paths, 0 deleted paths; 0 files changed, 0 insertions, 0 deletions. `UPSTREAM.md` is excluded from this comparison.

Run from `main` after the merge commit; `HEAD` then identifies the reviewed integration commit:

```sh
VENDOR_BASELINE_COMMIT='bc4cd22b0e4294914f38f4ba800b88474ab3a50a'
git diff --no-ext-diff --binary "$VENDOR_BASELINE_COMMIT" HEAD \
  -- image/archiso ':(exclude)image/archiso/UPSTREAM.md'
git diff --stat "$VENDOR_BASELINE_COMMIT" HEAD \
  -- image/archiso ':(exclude)image/archiso/UPSTREAM.md'
```

## Qualification states

- **Aggregate signature validation:** passed (Cosign image signature and Pacman package signature).
- **Import integrity:** passed (`pacman -Qkk archiso`; exported profile comparison).
- **Secret scan:** passed (vendor profile and acquisition evidence).
- **Build qualification:** not yet performed.
- **UEFI/OVMF boot qualification:** not yet performed.

Acceptance checks for the failure drill, cached import, and uncached verification all passed. The failure drill rejected a deliberately modified copy while preserving the acquisition container until diagnostics were exported and Gitleaks passed. The cached import reused the package archive. The uncached run matched package version `91-1`, the package SHA-256 above, and the imported profile. Detailed evidence is retained under `evidence/archiso-import/20261004T171704Z-91-1/`; failure-drill evidence is under `evidence/archiso-import/20261004T170955Z-failure-drill/`.

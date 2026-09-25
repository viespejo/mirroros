# Updating the Archiso releng vendor profile

> **Status:** Pending first execution (plan 01-02)

This procedure is the maintainer-run path for evaluating and importing the Archiso `releng` profile. It is intentionally separate from the build: a build may report a preflight mismatch, but it never imports upstream material automatically. The maintainer completes this procedure, reviews and merges the result, and retries the build explicitly.

## 1. Purpose and triggers

The procedure is event-driven. Start it when a build preflight detects a mismatch with the currently imported profile, or when a maintainer deliberately evaluates an upstream update. There is no calendar or periodic schedule.

A build-side mismatch is only a handoff. The build does not fetch, verify, or merge upstream material. After a successful import and explicit merge on `main`, the maintainer retries the build as a separate action.

Before changing anything, confirm the checkout and branch:

```sh
git switch main
git status --porcelain
```

The working tree must be clean before acquisition or integration begins.

## 2. External prerequisites

The following prerequisites are mandatory:

- Docker is installed and its daemon is reachable.
- Cosign is installed.
- Gitleaks is installed.
- A Git author and committer identity are configured.
- Online access to all official sources is available.

Check them without installing, starting, repairing, or configuring anything:

```sh
command -v docker
docker info
command -v cosign
command -v gitleaks
git var GIT_AUTHOR_IDENT
git var GIT_COMMITTER_IDENT
```

If any check is missing or fails, stop with an unmet-precondition report. Do not install a tool, start or restart a service, change Git configuration, weaken a verification setting, or continue with a partial import.

## 3. Canonical sources

Use these sources in this order of authority:

- The [Archiso GitLab repository](https://gitlab.archlinux.org/archlinux/archiso.git) is authoritative for the upstream project.
- The [Archiso GitLab packaging repository](https://gitlab.archlinux.org/archlinux/packaging/packages/archiso.git) is authoritative for package metadata and packaging history.
- GitHub is a read-only consultation mirror. Do not use it as the import authority or as a substitute for the GitLab history.
- The binary package is obtained from the Arch `extra` repository through the normal signed package mechanism.

Use native Git commands to record the exact revisions that were actually used; do not infer a revision from a mirror or from a mutable branch name.

## 4. Branch model and worktree

`vendor/archiso-releng` is created once from the baseline commit. It is a continuing vendor-history branch, not an orphan branch. A **pure** vendor commit contains only the unmodified upstream transition for the imported profile. Pure does not mean that the branch has no ancestry; it means that local MirrorOS changes are not mixed into that vendor commit.

`UPSTREAM.md`, the attribution entry, and every MirrorOS local delta live only on `main`. Every vendor integration is brought to `main` with an explicit `--no-ff` merge so that the import boundary remains visible. Merge conflicts are useful: they surface local deltas for maintainer review instead of silently overlaying them.

The vendor work is performed in `build/worktrees/archiso-vendor/`. The primary checkout stays on `main` while the vendor worktree is being prepared.

Create the branch only when it does not already exist:

```sh
git switch main
git status --porcelain
git branch vendor/archiso-releng
mkdir -p build/worktrees
git worktree add build/worktrees/archiso-vendor vendor/archiso-releng
```

For a later update, attach the existing branch to the same worktree path after confirming that no other worktree uses it:

```sh
git switch main
git status --porcelain
git worktree add build/worktrees/archiso-vendor vendor/archiso-releng
```

The intended history is:

```text
B (baseline)
├── vendor: B ── V1 ───────────── V2
└── main:   B ───────── X1 ─ M2 ─────── X2
                    ↖──┘       ↖───────┘
```

Here `V1` and `V2` are pure vendor commits, `X1` and `X2` are explicit non-fast-forward merges, and `M2` represents a main-only local change. The diagram is conceptual: the important properties are the baseline ancestry, the pure vendor line, and the visible merge boundaries.

## 5. Image selection and signature verification

Pull the current Arch Linux image for the supported architecture, then resolve the manifest digest that was actually pulled:

```sh
docker pull --platform=linux/amd64 docker.io/archlinux/archlinux:latest
docker image inspect docker.io/archlinux/archlinux:latest \
  --format '{{index .RepoDigests 0}}'
```

Extract and validate the returned `sha256:` digest. If the tag does not resolve to exactly one usable manifest digest, stop and report the ambiguity. Do not invent a digest and do not turn the result into a permanent pin.

Obtain the Arch GitLab CI certificate identity and OIDC issuer from the current official Arch documentation or CI verification instructions. Do not hard-code an identity string here or guess one. Verify the digest reference, not the mutable tag:

```sh
IMAGE_DIGEST='<sha256:digest returned for this pull>'
ARCH_CI_IDENTITY='<identity documented by Arch>'
ARCH_CI_ISSUER='<issuer documented by Arch>'
IMAGE="docker.io/archlinux/archlinux@${IMAGE_DIGEST}"

cosign verify \
  --certificate-identity "$ARCH_CI_IDENTITY" \
  --certificate-oidc-issuer "$ARCH_CI_ISSUER" \
  "$IMAGE"
```

A failed or ambiguous signature verification is an unmet prerequisite. Stop without creating a container. Record the digest used for this import in `UPSTREAM.md`; the digest is evidence of this execution, not a pin for future executions, which must resolve and verify the current tag again.

## 6. Acquisition container

The acquisition container has no `--privileged` flag and no `--rm` flag. Keep its lifecycle explicit: create, execute, export, verify, and remove.

Use a reusable pacman cache when desired:

```sh
docker volume create mirroros-pacman-cache
CONTAINER=mirroros-archiso-acquire

docker create \
  --name "$CONTAINER" \
  --platform=linux/amd64 \
  --volume mirroros-pacman-cache:/var/cache/pacman/pkg \
  "$IMAGE" sleep infinity

docker start "$CONTAINER"
```

The uncached variant omits the volume entirely and uses a fresh container name:

```sh
CONTAINER=mirroros-archiso-acquire-uncached

docker create \
  --name "$CONTAINER" \
  --platform=linux/amd64 \
  "$IMAGE" sleep infinity

docker start "$CONTAINER"
```

Inside the running container, use the distribution keyring and the configured package signature policy. Do not add an insecure repository, use an unsigned package, or weaken `SigLevel`:

```sh
docker exec "$CONTAINER" pacman -Syu --noconfirm
docker exec "$CONTAINER" pacman -S --needed --noconfirm archiso
docker exec "$CONTAINER" pacman -Qkk archiso
```

The `pacman` output and package metadata are part of the evidence. If signature validation, package installation, or `pacman -Qkk archiso` fails, stop and discard the acquisition attempt.

After export and verification are complete, remove the container explicitly:

```sh
docker stop "$CONTAINER"
docker rm "$CONTAINER"
```

When the cached run is no longer needed, remove the named volume explicitly:

```sh
docker volume rm mirroros-pacman-cache
```

Do not remove the cache before all intended exports and checks have completed.

## 7. Identity resolution

Resolve all identities from the exact acquisition, and stop on any ambiguity. Record the complete package version, including any epoch or release component exposed by the package manager:

```sh
docker exec "$CONTAINER" pacman -Qi archiso
docker exec "$CONTAINER" pacman -Q --qf '%n %v\n' archiso
docker exec "$CONTAINER" sh -c \
  'find /var/cache/pacman/pkg -maxdepth 1 -type f -name "archiso-*.pkg.tar.*" -printf "%f\n" | sort'
```

There must be one package filename corresponding to the installed package. Copy that exact file for hashing and record its SHA-256 without altering it:

```sh
PACKAGE_FILENAME='<exact package filename returned above>'
docker cp "$CONTAINER:/var/cache/pacman/pkg/$PACKAGE_FILENAME" "build/$PACKAGE_FILENAME"
sha256sum "build/$PACKAGE_FILENAME"
```

Resolve the upstream tag and commit from the authoritative GitLab repository:

```sh
UPSTREAM_URL=https://gitlab.archlinux.org/archlinux/archiso.git
UPSTREAM_DIR="$(mktemp -d /tmp/mirroros-archiso-upstream.XXXXXX)"
git clone --no-checkout "$UPSTREAM_URL" "$UPSTREAM_DIR"
git -C "$UPSTREAM_DIR" fetch --tags --force
# Select the tag that corresponds to the imported package and record it.
UPSTREAM_TAG='<tag resolved from the authoritative history>'
git -C "$UPSTREAM_DIR" rev-parse "$UPSTREAM_TAG^{commit}"
```

Resolve the packaging tag and commit from the authoritative packaging repository:

```sh
PACKAGING_URL=https://gitlab.archlinux.org/archlinux/packaging/packages/archiso.git
PACKAGING_DIR="$(mktemp -d /tmp/mirroros-archiso-packaging.XXXXXX)"
git clone --no-checkout "$PACKAGING_URL" "$PACKAGING_DIR"
git -C "$PACKAGING_DIR" fetch --tags --force
# Select the package tag that produced the installed package and record it.
PACKAGING_TAG='<tag resolved from the authoritative packaging history>'
git -C "$PACKAGING_DIR" rev-parse "$PACKAGING_TAG^{commit}"
```

Inspect the selected packaging revision to confirm the package version and source revision agree with the installed package. Do not guess when multiple tags, commits, package files, or source revisions could match; stop and report the ambiguity instead.

## 8. Export and integrity

Create a UTC-stamped staging directory containing the profile exported from the acquisition container:

```sh
UTC_TIMESTAMP="$(date -u +%Y%m%dT%H%M%SZ)"
PACKAGE_VERSION='<complete package version>'
STAGING_DIR="build/archiso-staging/${UTC_TIMESTAMP}-${PACKAGE_VERSION}"
mkdir -p "$STAGING_DIR"
docker cp "$CONTAINER:/usr/share/archiso/configs/releng/." "$STAGING_DIR/"
```

The exported tree must be owned by the normal user running the procedure. Check it and stop rather than silently changing ownership:

```sh
if find "$STAGING_DIR" \( ! -uid "$(id -u)" -o ! -gid "$(id -g)" \) -print -quit | grep -q .; then
  printf '%s\n' 'export ownership is not the normal user' >&2
  exit 1
fi
```

Compare the exported profile with the profile placed in the vendor worktree. The comparison covers:

- the complete relative path set;
- the type of every path;
- the content of every regular file;
- the target of every symbolic link; and
- the executable bit of every applicable file.

UID, GID, timestamps, and directory modes are deliberately excluded from comparison. Use native commands to inspect the required dimensions; do not treat a timestamp or ownership difference as a content delta:

```sh
find "$STAGING_DIR" -printf '%P\t%y\n' | sort
find build/worktrees/archiso-vendor/image/archiso -printf '%P\t%y\n' | sort

# For each regular-file path, compare bytes; for each symlink, compare readlink output.
# For each executable file, compare only its executable bit with stat.
diff -ruN --no-dereference \
  "$STAGING_DIR" build/worktrees/archiso-vendor/image/archiso
```

A path-set, type, content, symlink-target, or executable-bit mismatch is an integrity failure. Resolve it before creating the vendor commit; do not overlay one tree on top of the other.

## 9. Vendor commit

In the vendor worktree, completely replace `image/archiso/` with the exported profile. Overlays and incremental copies are forbidden:

```sh
VENDOR_WT=build/worktrees/archiso-vendor
rm -rf "$VENDOR_WT/image/archiso"
mkdir -p "$VENDOR_WT/image/archiso"
cp -a "$STAGING_DIR/." "$VENDOR_WT/image/archiso/"

git -C "$VENDOR_WT" diff --name-status
git -C "$VENDOR_WT" add -A -- image/archiso
git -C "$VENDOR_WT" diff --cached --name-status
```

Run Gitleaks on the staged profile before committing. Use the installed command syntax; for current releases:

```sh
gitleaks dir "$VENDOR_WT/image/archiso" \
  --redact --report-format json \
  --report-path "$VENDOR_WT/../archiso-vendor-gitleaks.json"
```

If the scan reports a finding, stop and report only the rule and path. Never reproduce the detected value, and do not add a `.gitleaks.toml` to suppress it.

After the profile review and scan pass, create exactly one pure vendor commit:

```sh
git -C "$VENDOR_WT" commit \
  -m "vendor(archiso): import releng $PACKAGE_VERSION" \
  -m "Upstream tag: $UPSTREAM_TAG\nUpstream commit: <upstream commit>\nPackaging tag: $PACKAGING_TAG\nPackaging commit: <packaging commit>"
```

Remove the worktree after the commit and retain the branch:

```sh
git worktree remove "$VENDOR_WT"
git worktree prune
```

If any vendor step fails before the commit, do not commit a partial tree. Discard the failed worktree, verify that `vendor/archiso-releng` still points to its previous commit, and leave `main` unchanged. The initial failed attempt must leave the vendor branch at the baseline rather than creating a partial import.

## 10. Pending merge

Start the integration from a clean `main` checkout. Do not merge a dirty worktree:

```sh
git switch main
test -z "$(git status --porcelain)"
git merge --no-ff --no-commit vendor/archiso-releng
```

Resolve conflicts deliberately. A conflict is a review of local MirrorOS deltas, not permission to overwrite them. On the first import, update the root `UPSTREAM.md` contract and add the corresponding attribution entry to `docs/attribution.md`. On later imports, update the existing provenance record and attribution only as required by the change; keep both files on `main`.

Run the delta, provenance, profile-integrity, and secret-scan checks before committing. If the review cannot establish the accepted provenance or integrity, abort without committing:

```sh
git merge --abort
```

When all checks pass, create the merge commit with this subject:

```sh
git commit -m "vendor(archiso): merge releng $PACKAGE_VERSION"
```

The merge must remain an explicit `--no-ff` merge. Do not fast-forward, squash away the vendor boundary, or add local files to the pure vendor branch to avoid a conflict.

## 11. `UPSTREAM.md` contract

The root `UPSTREAM.md` is a main-only provenance and qualification record. It must record all of the following for each import:

- the upstream project and canonical URL;
- the upstream tag and commit;
- the complete package version;
- the package filename and SHA-256;
- the verified image digest;
- the UTC import date;
- SPDX `GPL-3.0-or-later` for the incorporated upstream material;
- the acquisition and import method;
- the source path `/usr/share/archiso/configs/releng/`;
- the vendor commit;
- a local-delta block containing the baseline commit, a functional summary, add/modify/delete statistics, and a reproducible diff command excluding `UPSTREAM.md`;
- boot scope: UEFI/OVMF only, with BIOS/Syslinux assets retained but unsupported;
- separate states for import integrity, secret scan, build qualification, and boot qualification;
- the aggregate signature-validation result;
- an acceptance summary; and
- the local evidence path.

Use explicit state values rather than implying that an unrun gate passed. Until the later build and boot stories exist, the build-qualification and boot-qualification states are `not yet performed`.

The local-delta block must make the comparison reproducible. For example, after recording the relevant baseline and merge commits:

```sh
BASELINE_COMMIT='<baseline commit>'
MERGE_COMMIT='<merge commit>'
git diff --no-ext-diff --binary "$BASELINE_COMMIT" "$MERGE_COMMIT" \
  -- . ':(exclude)UPSTREAM.md'
git diff --stat "$BASELINE_COMMIT" "$MERGE_COMMIT" \
  -- . ':(exclude)UPSTREAM.md'
```

## 12. Checks and evidence

Create a UTC-stamped, ignored evidence directory for the import:

```sh
EVIDENCE_DIR="evidence/archiso-import/${UTC_TIMESTAMP}-${PACKAGE_VERSION}"
mkdir -p "$EVIDENCE_DIR"
```

Before the merge, confirm the worktree is clean, no ignored file is tracked, the exported profile matches the vendor profile under the comparison semantics above, and the vendor-to-main delta is understood:

```sh
git status --porcelain
git ls-files -ci --exclude-standard
git diff --name-status main...vendor/archiso-releng
git diff --stat main...vendor/archiso-releng
```

Run Gitleaks over the working tree before the merge in directory mode, which scans the working tree rather than Git history, and write a redacted report into the evidence directory. For an older release, use its equivalent `gitleaks detect --no-git --source .` form:

```sh
gitleaks dir . \
  --redact --report-format json \
  --report-path "$EVIDENCE_DIR/gitleaks-working-tree.json"
```

After the merge, scan the resulting history as well as the working tree:

```sh
gitleaks git . \
  --redact --report-format json \
  --report-path "$EVIDENCE_DIR/gitleaks-history.json"
```

Run an explicit scan of the evidence directory itself:

```sh
gitleaks dir "$EVIDENCE_DIR" \
  --redact --report-format json \
  --report-path "$EVIDENCE_DIR/gitleaks-evidence.json"
```

All reports must show zero findings. If any scan finds a value, stop, sanitize the evidence without copying or displaying the detected value, and rescan. Report only the rule and path. Never place a secret in `UPSTREAM.md`, a commit message, a report, or a troubleshooting note.

Append non-sensitive command outcomes and paths to an evidence summary. Do not include secret values or unredacted tool output.

## 13. Clean-clone gate

Validate the committed result from a fresh clone made outside the repository. `--no-local` is required so the test exercises the clone protocol rather than sharing the object store:

```sh
CLONE_PARENT="$(mktemp -d /tmp/mirroros-clean-clone.XXXXXX)"
git clone --no-local . "$CLONE_PARENT/repository"
CLONE="$CLONE_PARENT/repository"
```

The clone must have a clean `main`, and the vendor branch must be present as `origin/vendor/archiso-releng`:

```sh
test "$(git -C "$CLONE" branch --show-current)" = main
test -z "$(git -C "$CLONE" status --porcelain)"
git -C "$CLONE" show-ref --verify --quiet refs/remotes/origin/vendor/archiso-releng
```

Check the required files and confirm that ignored/generated paths are absent from the clone:

```sh
test -f "$CLONE/.gitignore"
test -f "$CLONE/LICENSE"
test -f "$CLONE/AGENTS.md"
test -f "$CLONE/docs/attribution.md"
test ! -e "$CLONE/build"
test ! -e "$CLONE/dist"
test ! -e "$CLONE/evidence"
```

Append the clean-clone result to the import evidence summary, then remove the temporary clone and its parent:

```sh
printf '%s\n' 'clean-clone gate: passed' >> "$EVIDENCE_DIR/summary.md"
rm -rf "$CLONE_PARENT"
```

A failed clean-clone gate blocks acceptance. Do not leave the temporary clone inside the repository or treat a local checkout as proof of clone behavior.

## 14. Requalification

Once Stories 1.3 and 1.4 exist, every accepted update reruns both the build gate and the UEFI/OVMF boot gate. Until those stories exist, the corresponding `UPSTREAM.md` states remain `not yet performed`; an import is not represented as build- or boot-qualified merely because it passed provenance and secret checks.

UEFI/OVMF is the only supported boot scope. BIOS/Syslinux assets may remain in the upstream profile for provenance, but their presence implies no BIOS or Syslinux support and must not be reported as qualification.

## 15. Remote publication

This baseline has no remote. When a remote exists in a later phase, publish both branches after the local gates pass:

```sh
git push <remote> main
git push <remote> vendor/archiso-releng
```

Do not add or configure a remote as part of this procedure. Publication is a separate, explicitly authorized operation.

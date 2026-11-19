# ADR 0032: Chrome Supply Chain and Update Flow

## Identifier and title

- **Identifier:** `0032`
- **Title:** Chrome Supply Chain and Update Flow

## Status

`Proposed`

Drafted by plan 02-43. Recipe, configure and laboratory work must wait for explicit maintainer acceptance at the
plan 02-43 acceptance checkpoint (DEC-001).

## Date

`2026-11-19`

## Context and question

Story 4.5 needs a replaceable browser that works with the desktop integrations and leaves accounts, credentials and
browsing data outside MirrorOS. Google does not publish a pacman repository. Chrome ships security fixes almost
weekly, while existing local recipes pin versions and hashes in the repository and update them through review. The
root-owned configure snapshot under `/usr/local/lib/mirroros` is never synchronized with the repository; a newly
reviewed pin would not reach an installed device through that snapshot.

The laboratory Chromium used on Hyprland falls back to the plain-text `basic` password store. Chrome can be launched
with `--password-store=gnome-libsecret`, but the selected backend and login keyring integration still need attended
validation on the reference VM.

How can MirrorOS install and update Chrome promptly without enabling another pacman repository, bypassing user
authorization or making the browser irreplaceable?

## Constraints and decision criteria

- Keep the package build unprivileged and require explicit authorization for privileged updates.
- Verify the upstream origin and package bytes independently of HTTPS and do not build or install on verification
  failure.
- Keep configure missing-only for the MirrorOS package in both the running system and guided installation target.
- Record package provenance without collecting accounts, credentials, profiles or browsing data.
- Keep the general Story 4.7 rules for AUR review and third-party repositories unchanged.

## Alternatives considered

1. **Resolve Chrome from Google's signed apt metadata and build a local package (selected).** Delivers security
   fixes independently of repository releases while keeping verification and privileged installation separate.
2. **Pin a reviewed version and hash for every release.** Fits existing local recipes, but delays fixes and does
   not deliver new pins through an installed configure snapshot.
3. **Pin the entire signing key file or trust HTTPS alone.** The former leaves installed snapshots without newly
   rotated subkeys; the latter does not authenticate the metadata independently of transport.
4. **Upgrade from configure or at login without user authorization.** Violates configure's missing-only semantics
   or allows unattended privileged updates.
5. **Use `extra/chromium`.** Uses the official Arch package flow, but does not address the observed password-store
   fallback out of the box. It remains the alternative provider.

## Evidence

- The [technical interview log](../technical-interviews/story-4-5-browser_log.md) records DEC-001–DEC-020. DEC-002
  and DEC-003 record the 2026-11-19 inspection of Google's stable channel metadata and its signing key.
- The [consolidated interview plan](../technical-interviews/story-4-5-browser_plan.md) records the proposed
  verification, update and provider boundaries.
- The [configure procedure](../procedures/configure.md) describes the installed snapshot and package behavior.

The interview observations are not evidence of a successful MirrorOS Chrome build, update or keyring integration.
Those checks belong to plan 02-43 after acceptance.

## Decision

- **Recipe and provenance (DEC-002, DEC-004):** The local recipe pins neither a version nor a `.deb` hash. The
  device resolves both from Google's stable amd64 metadata. A shared verifier authenticates `InRelease`, checks
  the SHA256 of `Packages` against it and extracts the stable package version and `.deb` SHA256. `makepkg` checks
  the downloaded `.deb` against that SHA256. Configure and `chrome-update` record the version, package hash,
  `InRelease` date and signing subkey as provenance. Per-version review is waived for this recipe only;
  structural recipe changes still require review. MirrorOS does not redistribute the Chrome binary.
- **Trust anchor (DEC-003):** The only pinned trust material is Google's primary Linux signing-key fingerprint,
  `EB4C 1BFD 4F04 2F6D DDCC EC91 7721 F63B D38B 4796`. Verification fetches the public key into a temporary
  keyring and accepts it only when the primary matches. Signing subkeys are accepted only if bound to that
  primary and valid for verification. A primary mismatch, invalid or expired signature, or hash mismatch fails
  closed: no update is offered from failed verification, and no package is built from unverified metadata or
  installed with an unverified payload. A primary change requires a reviewed amendment to this ADR.
- **Installation and updates (DEC-004–DEC-007, DEC-017):** Configure installs the MirrorOS package only when
  missing, replacing a reported AUR `google-chrome` if present; it never upgrades an installed MirrorOS Chrome.
  A oneshot user check at graphical login and a persistent daily user timer offer a verified newer stable version
  through one critical notification per version. Its `Update` action opens `chrome-update` in Foot; the command
  can also be run manually. It verifies and builds as the user and requests `sudo` only for `pacman -U`.
  Transient check failures leave the offer marker untouched and exit quietly. Integrity failures send a separate
  non-actionable notice, suppress repeats of the same cause and leave the check failed. Update failures report a
  next step and leave the installed browser in place.
- **Ownership and repository boundary (DEC-008):** Story 4.5 owns the Chrome flow end to end. Story 4.7 inherits
  this governed exception without changing its general `yay` or AUR review rules. Google's apt channel is a
  verified source for the local build, not an enabled pacman repository: no `pacman.conf` entry or key in
  pacman's keyring is added.

## Consequences and trade-offs

- Security fixes do not wait for a MirrorOS repository change, but installation and updates depend on Google's
  channel being reachable and verifiable. There is no unsigned fallback.
- Subkey rotation does not require a new configure snapshot. A change to the pinned primary blocks verification
  until reviewed and deployed.
- The device downloads and builds the package locally. Update checks make bounded network requests at login and
  daily; builds and privileged package installation are not performed by the check.
- A dismissed offer is not repeated for the same version. The user can still run `chrome-update` manually.

## Replacement or reversal boundary

`extra/chromium` is the alternative provider (DEC-019). Switching providers changes only the recipe, web
associations and desktop ID, with their corresponding tests. Provider-neutral launch paths and key bindings stay
unchanged. Browser accounts, credentials and profiles are external state; configure does not migrate them.

## Required validation

- Obtain explicit maintainer acceptance before changes to the recipe, configure or laboratory.
- Test the verification chain and its failure modes, missing-only configure in both contexts and the offer marker
  lifecycle.
- On the reference VM, confirm recorded provenance, user-authorized updates, desktop integrations and libsecret
  storage in the login collection without recording credential values. Confirm first boot after a clean guided
  installation and record the configure step cost.

## References

- [Story 4.7: Update the System Safely](../epics.md#story-47-update-the-system-safely)
- [Google Linux Software Repositories](https://www.google.com/linuxrepositories/)

## Superseded by

None.

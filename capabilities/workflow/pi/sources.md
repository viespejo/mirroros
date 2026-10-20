# Pi source and ownership boundaries

## Executable

- Package: `@earendil-works/pi-coding-agent`, installed with `npm install --global --ignore-scripts` into the
  selected user's NVM prefix. No sudo and no lifecycle hooks run.
- Version: selected once per execution by `pi-version.mjs` from the synchronized pi-config
  `devDependencies["@earendil-works/pi-coding-agent"]`.
  - An exact valid version is used as declared.
  - An absent declaration (or an absent `devDependencies`) selects the latest stable published version, queried once.
  - A range, an invalid value or malformed JSON fails with an actionable message; there is no fallback.
- The applied version and its selection source (`exact_dependency` or `stable_registry`) are recorded in `sources.tsv`.
- Matching the declared version does not guarantee compatibility, and `npm install` does not pin transitive
  dependencies. Compatibility repairs stay manual; configure never repairs or downgrades silently.

## External configuration

- Repository: https://github.com/viespejo/pi-config; selected normal branch `master`; destination `~/code/pi-config`.
- Published workbench revision reviewed initially at `37ae549ae4de603ab0b9535e9a13187c9d257a26`. This is a
  provenance observation, not a permanent pin: configure resolves the branch once and records the applied commit.
- The repository owns its extensions and resources. MirrorOS never copies them. `~/.local/bin/pi-editor` links to
  `~/code/pi-config/scripts/pi-editor` only while that path is absent; any other existing path is user-owned.
- The runtime dependencies of pi-config are installed with `npm ci --ignore-scripts --omit=dev --omit=peer` only
  when `node_modules` is missing or the manifest or lockfile identity recorded in
  `~/.local/state/mirroros/pi/pi-config-dependencies` differs.

## Initial `~/.pi` defaults

- `init-pi` initializes `~/.pi` only while that path is absent. An existing directory, symlink, dangling symlink or
  empty directory is preserved without any write and reported; nothing is merged, adopted or reset, and package state
  inside it is never reconciled. Moving the directory aside is the manual way to adopt newer defaults.
- A fresh `~/.pi` is staged in an owned sibling directory, validated, and published with a no-clobber rename. A
  destination created concurrently is preserved; an interrupted or failed run leaves no `~/.pi` and no staging.
- `defaults/settings.json`, `defaults/keybindings.json` and `defaults/APPEND_SYSTEM.md` are sanitized portable
  settings, bindings and operator instructions. Voice and text-to-speech are disabled and validated as disabled
  before publication; no model is downloaded and no credential, session, trust decision, cache or generated state
  is included.
- `defaults/prompts/` holds the seven maintainer-authored prompt templates (`batch-grill-me-log`, `batch-grill-me`,
  `grill-me-log`, `grill-me`, `handoff`, `impl-guide`, `ubiquitous-language`), shipped unchanged as original
  MirrorOS material under `GPL-3.0-only`.
- The extensions of pi-config are linked, never copied: each name under `~/.pi/agent/extensions` points into
  `~/code/pi-config`, including the `node_modules` directory installed there for dependency resolution. A missing
  target aborts the initialization before anything is published. Existing links may resolve to newer pi-config code
  after a synchronization without any write inside `~/.pi`.

## Initial `~/.pi` packages and skills

- Packages: `npm-packages` declares the exact versions initially reviewed (all MIT per their registry metadata):
  `@codexstar/pi-listen@7.2.2`, `pi-mermaid@0.3.0`, `pi-extension-manager@0.8.2`, `pi-resource-center@0.3.1`,
  `pi-sub-anthropic@0.1.10` and `pi-web-access@0.41.0`. They are installed only for a fresh `~/.pi` with
  `npm install --prefix <staging>/agent/npm --ignore-scripts --legacy-peer-deps`, an empty user and global npm
  configuration and a private HOME and cache, never inside an existing `~/.pi`. The shipped `settings.json` keeps its
  resource filters and stays authoritative; transitive dependencies are not pinned. Applied versions are recorded in
  `sources.tsv` as `npm:<name>` with the ref `declared`. Updates are explicit MirrorOS changes.
- Owned skills: `skills/aikido-mcp/{README.md,SKILL.md}` and `skills/atlassian-mcp/SKILL.md` are maintainer-authored
  MirrorOS material distributed under the project license (GPL-3.0-only, authorized by the maintainer), shipped
  byte for byte from the reviewed snapshot (SHA256 `e91628ab...27ba`, `6900d543...6f9b`, `7cc7c7d4...ac03`) with no
  managed header, because a header would alter the skill frontmatter. They contain no credentials and no private
  account setup. They are delivered to `~/.local/share/mirroros/pi/skills/<name>` and linked from `agent/skills`.
- External manual skills: `external-skills` declares `teach` and `wait-what` (`mattpocock/skills`,
  `skills/productivity`), `show-me` (`humanlayer/skills`, `plugins/show-me/skills/show-me`) and `archify`
  (`tt-a1i/archify`, `archify`). They are not vendored. Each repository's default branch is resolved once per run
  and recorded with its commit as `skills:<owner>/<repo>` in `sources.tsv`; the `skills` CLI version (`1.7.2`,
  initially observed commit `671e8c320810d36fed80fac5f1a2c1bf7e82d812`) is recorded as `skills-cli`. The CLI is not
  claimed to pin its own dependencies. Reviewed initially at `mattpocock/skills`
  `49dd158d1076134a641b33efb035946536778336`, `humanlayer/skills` `653b6411c1f70c275a18e37673b042ff99f67ceb` and
  `tt-a1i/archify` `ba701d20a55ed6f139484d9ead7ff45671fe40eb`: provenance observations, not pins.
  - The only amendment is `disable-model-invocation: true` in each `SKILL.md` header (`manual-skill.mjs`); it hides
    the skill from automatic selection but keeps `/skill:<name>` available. It is an invocation policy, not a
    sandbox. Bodies and support files stay byte-identical to upstream.
  - The upstream license stays with each skill. Archify's code terms and third-party artwork notices
    (`THIRD_PARTY_NOTICES.md`) remain distinct; installing them does not relicense anything, and no skill script,
    browser or model runs during initialization.

## Google Cloud CLI

- No official-repository package was found in the guest's pacman sync metadata (this does not establish universal
  availability), so `install-gcloud` installs Google's self-contained versioned Linux x86_64 archive as the selected
  user, without sudo, an AUR recipe, `install.sh`, `gcloud init`, component installation, profile edits or
  authentication.
- Version: Google Cloud SDK `589.0.0`. Archive:
  `https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-cli-589.0.0-linux-x86_64.tar.gz`.
- Identity reviewed during development: size `93451089` bytes and MD5 `c3d491ff5bb2a19aa9fbf86f2e0e9eba` (hex of the
  published base64 `w9SR/1uyoZqp+/hvLg6eug==`) match the metadata of the official object (generation
  `1791890871601864`). The SHA256 `f865da648f6fdae2015abb5b32eaa0eb10520e88f0ca735cfb33795868c8d26f` was computed
  locally from that object: it is a content identity, not a checksum published by upstream. The documentation's
  floating-name archive checksum does not apply to the versioned archive and is not used.
- Size, MD5 and SHA256 are all verified before extraction; any mismatch aborts with nothing extracted or published.
  The archive is extracted into an owned staging directory under `~/.local/opt` and published with a no-clobber
  rename to `~/.local/opt/google-cloud-sdk-589.0.0`. A destination created concurrently, a directory of another
  version and a symlink are preserved and reported; only owned staging is removed.
- `~/.local/bin/gcloud` links to the installation only while that path is absent; any other existing path is
  user-owned. The postcondition runs `gcloud --version` with a throwaway `CLOUDSDK_CONFIG`, usage reporting and the
  component update check disabled, so no account, project or settings are read or created.
- The archive identity is recorded in `sources.tsv` only when the installation changed. A satisfied installation
  causes no download and no network probe. A version change is an explicit MirrorOS change.
- Account setup (`gcloud auth application-default login`), project and location selection, APIs, billing and IAM are
  private runtime inputs; configure copies no credentials and enables no API.

## Official packages

- `ffmpeg` is the approved audio-capture prerequisite of the optional voice package. Voice and text-to-speech stay
  disabled by default; this step downloads no models and enables no audio feature.

Authentication, sessions and provider accounts are private runtime inputs and never part of this step.

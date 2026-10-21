# Development workbench preparation

## Status and scope

Task 1 of plan 02-17 received overall maintainer acceptance. Task 2 decisions
are recorded in the final review addendum; its overall A/B review remains pending.
This is a provisional preparation record, not a completed reproduction procedure
or product acceptance. Pi initialization,
guest shell measurements and several attended checks are recorded chronologically
below. Fresh editor-tool preparation and disposable native Tmux restoration have
passed and received incremental maintainer acceptance. Pi's declared and observed
versions now agree; historical executable-install provenance remains qualified.
The current dependency/notice map, owned-skill packaging proposal and final source
checks appear at the end. Overall Task 1 review and Task 2's blocking candidate,
Sesh delivery and measured-performance decisions remain pending. Earlier pending
statements below represent the state at their respective preparation stages.

Changes in this record were developed in the existing guest. The host MirrorOS
checkout was not changed. No commit or publication is authorized by this record.

## Current normal guest installation

The maintainer explicitly authorized deleting the guest's previous Neovim
configuration link, data, state, cache and all four isolated installations, then
rebuilding the approved configuration in the normal user paths. The destructive
scope was enumerated and confirmed before execution. No Neovim process was
running. The guest source checkout was verified clean at `654973f` first.

Preserved `~/code/nvim`, created local branch `workbench-neovim` (no commit/push),
and applied only the approved bootstrap, Rainbow/Aerial Lazy-generated lockfile
changes and LspInfo deprecation fix. Removed and recreated only the
`~/.config/nvim` symlink to this checkout; the target source was not deleted.
Removed `~/.local/share/nvim`, `~/.local/state/nvim`, `~/.cache/nvim`, and the four
historical isolated roots documented below. Their cache, session/recovery state,
plugins and tool installations were intentionally discarded. No host paths,
Pi directory, global tools, or source repository were deleted.

Before deletion, preserved approved source files, selected diagnostic reports,
the probe script and the 14 Mason package source identities under:
`~/.local/state/mirroros-lab/workbench-prototype/neovim-rebuild-record.Wnaulr`.
These are preparation records, not another Neovim installation or scanned
acceptance evidence. Historical root paths below no longer exist.

Rebuilding plugins and tools in normal guest XDG paths completed with exit 0.
The record's `mason-specs.txt` selected the same 14 observed tool versions for
this reconstruction; this is not an Arch package freeze or permanent product
pinning policy. JSON LSP remains in the user's NVM environment, outside the
deleted Neovim directories. The rebuild explicitly loaded Blink/Treesitter and
waited for the Rust fuzzy implementation and all 17 parsers. Independently
verified 14 Mason receipts, all active plugin commits against the lockfile, all
17 parser shared libraries, and Blink's binary in normal Neovim data paths.

Normal-path smoke tests now pass: JSON and Go servers both attach and produce
diagnostics, and Stylua/goimports/shfmt/Prettier all transform their fixtures.
The earlier JSON failure was a probe limitation: it checked only push diagnostic
namespaces, while JSON diagnostics were available through the pull namespace.
The updated probe checks both, without changing JSON server configuration.
An initial normal-path probe could not write its result because the record's
state output directory was absent and timed out (124); after creating it, the
full probe exited 0. These failed attempts are not passing evidence.

Records: `rebuild.exit`, `restore.log`, `mason-install.log`, `resources.log`,
`parity-tools-probe.log`, and `state/parity-tools-probe-results.txt` under the
preserved record directory. A client.notify deprecation remains observed.
Interactive normal-path checks and the explicit repository-owned tool preparation
entry point remain pending. This is prototype preparation, not Task 2 acceptance.

## Neovim clean-install investigation

### Inputs

- Guest Neovim: v0.12.6.
- Guest configuration: `~/code/nvim`, remote
  `https://github.com/viespejo/nvim-lua-new`, branch `master`, commit
  `654973fa0a5e3d5b15e782f8fe449ac347df014f`.
- The guest source checkout was clean before the investigation.
- Node.js v24.22.0 is supplied explicitly through
  `~/.nvm/versions/node/v24.22.0/bin` during provisioning.

### Isolation and commands

The maintainer authorized fresh isolated configuration, data, state, and cache
roots and plugin downloads. Existing Neovim configuration and installed plugin
directories were preserved. System packages were not installed by this test.

Create an empty temporary root with `mktemp -d`, clone the configuration into
`$root/config/nvim`, and select the source commit. Set all four variables before
running Neovim:

```bash
export XDG_CONFIG_HOME="$root/config"
export XDG_DATA_HOME="$root/data"
export XDG_STATE_HOME="$root/state"
export XDG_CACHE_HOME="$root/cache"
export PATH="$HOME/.nvm/versions/node/v24.22.0/bin:$PATH"
nvim --headless '+Lazy! restore' '+qa!'
```

This isolates Neovim's XDG state, not the entire home or installed system tools.
It is not a replacement for reconstruction in a separate clean VM. Temporary
roots are diagnostic working data and may disappear after reboot.

### Initial observations

Initial root: `/tmp/mirroros-nvim-fresh.vpr48B`.

- Fresh installation did not contain `luarocks.nvim`, `mcphub.nvim`,
  `plenary.nvim`, or `render-markdown.nvim`. These four entries in the ordinary
  installation's Clean list were leftovers from earlier configuration changes.
- Obsidian is explicitly disabled; its remaining lockfile entry does not imply
  it should be installed.
- All active plugin checkouts matched the source lockfile except lazy.nvim.
- Bootstrap cloned lazy.nvim from `stable` and changed its lockfile commit from
  `6c3bda4aca61a13a9c63f1c1d1b16b9d3be90d7a` to
  `85c7ff3711b730b4030d03144f6db6375044ae82`.
- Treesitter downloaded and compiled all 17 configured parsers. The first
  health report was collected while some parsers were still being built.
- Blink downloaded its prebuilt fuzzy binary on first interactive loading;
  the maintainer reported successful download. Preparation must exercise and
  verify this before the first normal interactive use.
- The maintainer reported a Rainbow Delimiters FileType callback failure in
  Fzf and an Aerial Markdown Treesitter callback failure. Neither is accepted
  as fixed yet.

### Health findings

- Conform reported missing `stylua`, `prettier`, `shfmt`, `goimports`, and
  `stylelint`; `jq` and `shellcheck` were available.
- Lua, JSON, and JavaScript/TypeScript language-server executables were absent
  in the fresh environment. Go, Terraform, and Tailwind servers were also absent.
- `ensure_installed` is currently supplied directly to mason.nvim, which does
  not implement that option. No installation integration was found in the
  configuration to consume the list.
- Optional provider/language warnings are not an instruction to install every
  supported language or package manager.
- Lazy's health check reports absent LuaRocks but explicitly states no plugins
  require it. No LuaRocks installation was performed.
- Clipboard warnings from SSH lack graphical-session context. `wl-copy` exists;
  actual clipboard behavior must be tested in Foot in the graphical session.
- Some explicitly requested healthcheck names were unavailable. The resulting
  `No healthcheck found` messages are diagnostic invocation limitations, not
  evidence of plugin runtime failure.

Reports in the initial temporary root: `restore.log`, `health.txt`,
`health-run.log`, `plugin-health.txt`, and `plugin-health-run.log`. These are
unscanned temporary diagnostics, not retained acceptance evidence.

### Approved candidate changes

The maintainer approved a lockfile-respecting bootstrap, provisioning-time
Blink preparation, and selective Rainbow Delimiters/Aerial updates. Changes
remain in a separate isolated candidate; they are not promoted to the normal
configuration or published.

Candidate root: `/tmp/mirroros-nvim-candidate.8vPhoB`.

- `lua/core/lazy.lua` reads and validates the lazy.nvim commit from the lockfile,
  clones without checkout, then selects that exact commit on fresh bootstrap.
- `Lazy! restore` completed with exit status 0 without changing the lockfile.
- `Lazy! update rainbow-delimiters.nvim aerial.nvim` completed with exit status 0.
- Only the following two lockfile entries changed, generated by Lazy itself:
  - Rainbow Delimiters: `687ef75fdbd497eabc9eea92b52e7b4d403b3319` ->
    `b55decda611755171bc5bf8f4c99603a75de4b41`.
  - Aerial: `c7cbbad40c2065fccfd1f1863bb2c08180c0533d` ->
    `28fe6e822ae344544c379d60fcb13c9519a1f08a`.
- Bootstrap files and lockfile were not manually regenerated. Future lockfile
  changes must continue to be produced by Lazy, not hand-edited.
- Upstream Rainbow adds a missing nil-parser guard. Upstream Aerial handles
  Treesitter node arrays rather than assuming individual match nodes.
- Candidate logs and exit records are under `$root/state/`.

Upstream inspection references:

- <https://github.com/HiPhish/rainbow-delimiters.nvim>
- <https://github.com/stevearc/aerial.nvim>
- <https://github.com/mason-org/mason.nvim>

### Mason ownership discussion

The maintainer prefers Mason to install editor tools, with configure ensuring
preparation is complete. This is compatible with explicit provisioning-time
`MasonInstall` execution and executable postconditions; it does not require
startup-time installation or automatic installation of every configured server.
The maintainer initially authorized eight tools for an isolated experiment:
`lua-language-server`, `json-lsp`, `vtsls`, `bash-language-server`,
`yaml-language-server`, `stylua`, `prettier`, and `shfmt`.
This was subsequently superseded as the integration baseline by the explicit
host-parity decision below. Preserve the experiment as history, not approval to
promote its additional tools or Bash/YAML configuration into MirrorOS.
The product integration remains pending.

The maintainer reported this host inventory (not independently inspected):
`golangci-lint`, `js-debug-adapter`, `lua-language-server`, `stylelint`,
`tailwindcss-language-server`, `terraform-ls`, `tflint`,
`typescript-language-server`, and `vtsls`. This is a reference inventory, not
approval to install all of it in MirrorOS.

### Provisioning attempt and environment failure

The maintainer observed first-start/Insert-mode downloads, described as LSP and
Blink installation. Before explicit Mason provisioning, the candidate had Blink's
`libblink_cmp_fuzzy.so` and checksum but no Mason packages directory. Do not
conflate LSP integration plugins with installed language-server executables or
assume observations from different isolated roots describe the same state.

Executed in the candidate with the declared XDG roots and Node PATH:

```bash
nvim --headless \
  '+MasonInstall lua-language-server json-lsp vtsls bash-language-server yaml-language-server stylua prettier shfmt' \
  '+qa!'
```

Mason exited 1. Receipts existed for `bash-language-server`, `lua-language-server`,
`vtsls`, and `yaml-language-server`; the other four were not complete. npm reported
write errno 122 (`EDQUOT`). `/tmp` is a 2 GiB tmpfs with `usrquota`; the guest home
filesystem had approximately 22 GiB free. Download diagnostics also included a
missing-wget fallback. No system package was installed and no quota was changed.

A second fresh candidate was created on the guest disk:
`~/.local/state/mirroros-lab/workbench-prototype/neovim-clean.XBYkeF`.
It uses empty XDG data/state/cache, its own disk-backed `TMPDIR`, and the approved
candidate configuration. Plugin restore followed by the same Mason command was
completed with exit status 0 for both restore and Mason installation. All eight
Mason package receipts exist and `vim.fn.exepath()` resolves the corresponding
eight executables inside this isolated Mason installation. Previous isolated
roots were preserved. The lockfile still differs only in Rainbow/Aerial entries;
lazy.nvim did not drift.

Logs and explicit exit status files are under this root's `state/` directory;
`executables.log` records the executable postconditions. This is not yet proof
of working LSP attachment, formatting, or idempotency. Bash/YAML server activation was subsequently implemented and tested as recorded
below; installing a server alone did not enable it automatically.

npm reported four high-severity vulnerabilities during one package installation
and an install-script approval warning for `core-js@3.50.0`. These warnings remain
untriaged. No audit repair, forced upgrade, or script approval was performed.
Do not treat exit status 0 as a security acceptance verdict.

### Bash/YAML activation and LspInfo correction

The maintainer authorized enabling `bashls`/`yamlls` and replacing deprecated
`vim.lsp.get_log_path()` with `vim.lsp.log.get_filename()` in `lua/core/lsp.lua`.
The candidate preserves the file's original non-ASCII icon bytes (verified by
SHA-256 over the non-ASCII bytes).

Inspection corrected an earlier assumption: this configuration explicitly
disables nvim-lspconfig and owns server definitions in `lsp/*.lua`. Adding names
to `vim.lsp.enable()` alone therefore failed: the definitions were absent.
No nvim-lspconfig dependency was enabled or installed. Instead, the candidate
adds `lsp/bashls.lua` (`bash-language-server start`, sh/bash filetypes) and
`lsp/yamlls.lua` (`yaml-language-server --stdio`, yaml filetype), both with `.git`
root markers, matching the existing native configuration ownership.

A smoke test creates deliberately invalid Bash/YAML files only under the
candidate's `.workbench-lsp-probes/` directory. Both servers attached and emitted
diagnostics from their own diagnostic namespaces. The successful command was:

```bash
nvim --headless -c "luafile $root/check-lsp.lua"
```

This requires the same XDG variables, Node PATH, TMPDIR, and
`WORKBENCH_ROOT="$root"` as the disk-backed candidate. Exit status was 0;
`state/lsp-probe-results.txt` records `attached=true, diagnostics=true` for both
servers. The script and fixtures remain in the isolated candidate. An initial
`nvim -l` invocation did not load normal configuration and was not valid evidence;
a normal-config retry exposed the missing definitions before they were added.
The normal guest Neovim checkout and host configuration remain unchanged.

### Superseding host-parity decision

The maintainer clarified that the host must be the functional reference. Tools
absent from Mason may already be installed globally through npm. Do not infer a
missing host capability from Mason's list alone, and do not install packages just
to suppress health warnings.

The maintainer explicitly authorized a new clean guest environment with exactly
these nine Mason packages: `golangci-lint`, `js-debug-adapter`,
`lua-language-server`, `stylelint`, `tailwindcss-language-server`, `terraform-ls`,
`tflint`, `typescript-language-server`, and `vtsls`. This includes the host's
Go/Terraform/debug tools by explicit request rather than the previously proposed
minimal MirrorOS language subset. It is still a prototype choice, not final
Task 2 acceptance or a declaration that all development tooling is delivered.

New root:
`~/.local/state/mirroros-lab/workbench-prototype/neovim-host-parity.TQDCjV`.
It clones configuration commit `654973f`, retains the approved lock-respecting
bootstrap, selective Rainbow/Aerial lockfile changes and LspInfo deprecation fix,
and does not copy the experimental Bash/YAML definitions or enable those servers.
It has fresh XDG data/state/cache, disk-backed TMPDIR, and an isolated npm cache.
No previous environment or ordinary configuration was deleted or overwritten.

Plugin restore and explicit `MasonInstall` for the nine named packages both
exited 0. Verified exactly nine Mason receipts and executable links, matching the
approved package names. No additional Mason package was installed. npm reported
five high-severity vulnerabilities during installation; triage remains pending.
No audit repair, forced upgrade, or lifecycle-script approval was performed.

Loaded Blink, Conform and Treesitter explicitly, allowed preparation to finish,
and ran full `:checkhealth` headlessly. The command exited 0 and all 17 parsers
finished installing; this is not an assertion that every health check passed.
Reports are `state/checkhealth.txt` and `state/checkhealth-run.log` under the new
root. They are unscanned diagnostic files, not acceptance evidence.

Relevant findings:

- Conform: missing goimports, prettier, shfmt, stylua; jq, shellcheck and stylelint
  are available.
- LSP: gopls and vscode-json-language-server are missing. No additional server
  installation is authorized merely by this warning.
- LuaSnip: optional jsregexp library is missing for snippet transformations.
- Lazy: missing LuaRocks despite no plugin requiring it.
- Mason: version-not-latest and optional ecosystem/package-manager warnings.
- Deprecated vim.validate usage remains to attribute to its actual caller.
- Empty locale and TERM, and unavailable clipboard in the headless SSH environment
  are not proof of graphical-session failure.

Read-only host comparison used `npm ls --global --depth=0 --json --ignore-scripts`
and `command -v` without sourcing host shell startup files. Only relevant results
are recorded here; unrelated global packages are not product inputs:

- `vscode-langservers-extracted@4.10.0` is globally installed through npm, and
  `vscode-json-language-server` resolves in the host NVM Node v24.15.0 bin directory.
- npm provider `neovim@5.3.0` is globally installed on the host.
- gopls and goimports resolve under the host `~/go/bin`; their installation method
  and source versions were not established by this lookup.
- stylua resolves to `/usr/bin/stylua`; package provenance is not yet established.
- prettier and shfmt do not resolve in the current harness PATH and are absent
  from the inspected global npm list. This does not prove absence from Neovim's
  runtime PATH, other Node versions, project-local dependencies, or other tooling.

The host has tools outside Mason. Review their provenance and whether they are
needed before proposing parity installations. Do not install the previous
experiment's extra servers or formatters automatically.

### Follow-up decisions and conditional Prettier installation

The maintainer approved pursuing host-parity JSON LSP/gopls/goimports/stylua,
but agreed not to install the npm Neovim provider merely because it exists on the
host. Source inspection found host gopls v0.20.0 (Go module
`golang.org/x/tools/gopls`), goimports from `golang.org/x/tools` v0.36.0, and
Arch-owned stylua 2.0.2-1 (`stylua --version`: 2.0.2). These observations do not
pin future Arch packages or authorize arbitrary upgrades. Provisioning of these
four tools was subsequently completed as recorded below.

The maintainer conditionally approved Mason Prettier only if a project-local
installation wins. The locked Conform implementation uses `from_node_modules`,
searches upward for `node_modules/.bin/prettier`, and falls back to `prettier`
from PATH. Installed Mason prettier 3.9.10 with exit 0. A resolution-only fixture
links the Mason binary at a project's node_modules/.bin/prettier path: Conform
selected this local path when present and the Mason PATH binary outside the
fixture project. No additional project package was downloaded and no project
formatter version was changed. Logs: `state/prettier-install.log` and
`state/prettier-priority.log`. The current candidate therefore has the nine host
Mason packages plus this separately approved Prettier addition.

Confirmed `shfmt` is available in the guest Mason registry. The maintainer asked
for a proposal for the Neovim repository; shfmt has not been installed in this
host-parity candidate or added to the host repository. Merely adding it to the
currently ineffective ensure_installed field would not implement provisioning.

The deprecated vim.validate stack identifies virt-column.nvim and
nvim-treesitter. No plugin update was performed for this warning.

The maintainer explicitly deferred LuaSnip/jsregexp and npm vulnerability
investigation. Keep the warnings recorded as untriaged; do not reinterpret this
as a clean security scan or perform automatic repairs.

The maintainer reported colorful health icons on the host but not the guest.
Read-only font inspection found host `noto-fonts-emoji` 1:2.047-1 and an emoji
font match of Noto Color Emoji. The guest lacks that package and its `emoji`
font match is Noto Znamenny Musical Notation. Missing color-emoji font support
is a plausible cause, not yet visually confirmed. The maintainer subsequently explicitly authorized guest pacman installation of
`noto-fonts-emoji` and candidate Mason installation of `shfmt`. Mason shfmt
installation exited 0; the candidate binary reports v3.14.1. The candidate now
contains the nine host Mason packages plus separately approved Prettier and shfmt.
Log: `state/shfmt-install.log`.

The guest font package was absent and noninteractive sudo was unavailable, so no
privileged font installation was performed. Attended authentication is required.
The intended guest command is `sudo pacman -S --needed noto-fonts-emoji` (no
package database refresh). After successful installation, open a new Foot window
and compare health icons; font matching alone is not visual acceptance. Never
record the sudo password in commands, files, logs, or evidence.

### Completed parity tools and remaining runtime check

The maintainer authorized continuing with the pending tools and accepted keeping
Mason as the editor-tool installer even though host tools use other installation
methods. Installed in the current candidate via Mason:

- stylua 2.6.0 (host observed 2.0.2).
- gopls v0.23.0 (host observed v0.20.0).
- goimports from golang.org/x/tools v0.52.0 (host observed v0.36.0), built with
  guest Go 1.27.2.

These are functional-parity candidates, not identical host versions. Installed
`vscode-langservers-extracted@4.10.0` globally, unprivileged, in the guest user's
NVM Node v24.22.0 environment with npm `--ignore-scripts`. This matches the
observed host package version. Installation commands exited 0. Logs:
`state/parity-tools-install.log` and `state/json-lsp-install.log`, with matching
`.exit` files.

Smoke script `check-parity-tools.lua` uses only isolated fixtures under the
candidate's `config/nvim/.workbench-parity-probes/`. Go LSP connected and produced
diagnostics. Stylua, goimports, shfmt and Prettier each transformed its fixture
successfully through Conform. JSON LSP connected, but the diagnostic assertion
failed; the overall probe exited 1. Do not claim a passing full Neovim validation.
Results: `state/parity-tools-probe-results.txt` and
`state/parity-tools-probe.log`. A client.notify deprecation was also observed.

The maintainer confirmed colorful icons now work. Subsequent package inspection
confirmed guest noto-fonts-emoji 1:2.051-1 and Noto Color Emoji matching. This is
attended icon acceptance only, not acceptance of the full prototype.

### Approved ownership adjustment: editor tools declared by Neovim

The maintainer explicitly approved avoiding a parallel editor-tool list in
MirrorOS. Target organization:

- The external Neovim repository owns the desired LSP/linter/formatter list and
  an explicit Mason preparation entry point.
- MirrorOS owns required system/runtime prerequisites, synchronizes the selected
  Neovim source revision, invokes that preparation, and verifies postconditions.
- Preparation does not run on normal Neovim startup. Updating the Neovim checkout
  on the host must not implicitly install tools or replace system-provided tools.
- Project-local dependencies retain precedence where supported; Prettier's local
  precedence has been verified in this candidate.
- Avoid installing the same executable through multiple providers and silently
  changing PATH precedence.

This is an approved design adjustment, not implemented repository code. Review
and publication of any external repository changes still require authorization.
Keep the mechanism bounded to this concrete editor consumer, using native Lua
and Mason APIs; do not introduce a central capability schema or generic dotfiles
provisioner. The source/dependency map and Task 2 review must reflect this decision.

Changing the external editor-tool list does not require rebuilding MirrorOS:
explicit configure can synchronize the selected external revision and prepare
its tools. Changes to MirrorOS code require updating its checkout and running
configure. A build is needed to distribute a new ISO snapshot, not for each
installed-system configuration update. These are intended update semantics, not
proof that the new editor preparation entry point already exists.

### Attended graphical checks and deprecation follow-up

The maintainer explicitly validated all three requested graphical checks in Foot
and Tmux: UTF-8/TERM/Wayland environment, absence of the corresponding graphical
health errors, and clipboard copy/paste in both directions. These are attended
outcomes, not screenshots or retained private content.

The maintainer authorized LuaRocks and deprecation follow-up and accepted leaving
optional provider/ecosystem warnings alone. Changes applied only to the guest
Neovim branch:

- `lua/core/lazy.lua`: `rocks.enabled = false`, because no active plugin requires
  LuaRocks. A subsequent Lazy health check reports `luarocks disabled` as OK.
- A Lua-buffer health check traced client.notify to lazydev.nvim/lsp.lua:90.
  Upstream uses client:notify when Neovim >= 0.11. Updated only lazydev.nvim via
  Lazy; its lockfile commit changed from
  `2367a6c0a01eb9edb0464731cc0fb61ed9ab9d2c` to
  `ff2cbcba459b637ec3fd165a2be59b7bbaeedf0d`. No hand-edited lockfile or bulk update.
- Reopened the Lua fixture, waited for server initialization and ran
  `checkhealth lazy vim.deprecated`: LuaRocks is OK and client.notify no longer
  appears. Report: `health-after-deprecation-fixes.txt`, with companion run log
  and `lazydev-update.log` under the rebuild record directory. `git diff --check`
  passes. Host 0.11 compatibility remains an untested requirement despite the
  upstream version guard.
- The remaining vim.validate warning comes from virt-column.nvim. Inspection of
  upstream master still found deprecated table-style validation, so a version
  update is not an established fix. No installed-plugin patch, warning suppression,
  replacement provider, or fork was introduced. The maintainer subsequently
  accepted retaining this warning and virt-column's behavior. No measured
  performance problem has been established; do not reopen this choice without
  new evidence or claim the warning is fixed.

Sources inspected:
<https://github.com/folke/lazydev.nvim/blob/main/lua/lazydev/lsp.lua> and
<https://github.com/lukas-reineke/virt-column.nvim/blob/master/lua/virt-column/config.lua>.

### Explicit editor-tool preparation implementation

The guest `workbench-neovim` branch now contains
`lua/config/prepare_tools.lua`, invoked explicitly as the editor user:

```sh
export PATH="$HOME/.nvm/versions/node/v24.22.0/bin:$PATH"
cd "$HOME/code/nvim"
nvim --headless -c "lua require('config.prepare_tools').run()" -c qa
```

Restore locked plugins before preparing an empty installation, as described in
that repository's README. The module owns the previously approved 14 Mason tools
and npm JSON provider. MirrorOS must not maintain a parallel tool list. The
ignored `ensure_installed` option was removed from `lua/plugins/mason.lua`;
normal editor startup does not invoke preparation. Host system/npm/Go providers
are not migrated implicitly. Project-local Prettier selection is unchanged.

Preparation checks explicit runtime prerequisites, rejects root and npm roots
outside the user's home, preserves installed Mason tools, checks their receipts
and executables, and installs missing tools only when explicitly invoked. It
refreshes the registry only when tools are missing and resolves each package
object once before installing. JSON remains
`vscode-langservers-extracted@4.10.0` in the user's npm runtime with
`--ignore-scripts`; a different existing version or incomplete existing package
path fails for manual review. Commands, registry refresh and each installation
have a 15-minute timeout. A timed-out Mason handle is cancelled. No automatic
repair, uninstall, force-install, or background update was introduced.

Validation performed:

- `nvim --headless -u NONE -l tests/prepare-tools.test.lua`: 15 isolated tests pass
  on host Neovim 0.11.2 and guest Neovim 0.12.6. Host configuration is not loaded.
  All npm/Mason effects are mocked. Cases cover fresh/satisfied inputs, explicit
  PATH, root/system-prefix rejection, npm conflicts/failures, registry/installer
  failure, missing receipts/executables, failed postconditions, cancellation and
  nonzero command-entry failure.
- Guest `stylua --check lua/config/prepare_tools.lua tests/prepare-tools.test.lua
  lua/plugins/mason.lua` and `git diff --check` pass.
- Two guest runs use the normal Neovim configuration and explicit Node v24.22.0
  PATH, with in-memory guards that reject npm installation, Mason installation
  and registry refresh. Both finish successfully and report preservation of all
  14 Mason tools and JSON npm 4.10.0. No tool-installation attempt occurs.
- The first isolated test attempt failed because the fake `vim` lacked a helper
  used by `vim.trim`; the double was corrected. The first StyLua check requested
  formatting of the two new files; those files were formatted and checks rerun.

Actual fresh-tool installation through this entry point remains untested; the
fresh case currently has contract-test evidence only. Host full-configuration
compatibility, graphical workflows, interrupted real installs and clean
reconstruction remain pending. No new lockfile change, commit, push, publication,
host configuration change, or Pi initialization was performed in this step.
External product consumption still requires separately approved publication of
the guest branch to the normal remote branch. Diagnostic output is not yet
secret-scanned acceptance evidence.

### Neovim 0.12 Treesitter consumer audit (before migration)

The maintainer approved stabilizing the configuration entirely in the guest on
Neovim 0.12 before a separately authorized host migration. Neovim 0.11 support is
no longer a requirement for this candidate. Host changes, commits and publication
remain separately gated.

The guest's `nvim-treesitter` master revision
`42fc28ba918343ebfd5565147a42a26580579482` uses legacy directives that assume
individual nodes. Neovim 0.12 supplies node lists to those handlers. A targeted
Markdown fenced-block query invoking `#set-lang-from-info-string!` reproduces
`vim/treesitter.lua:197: attempt to call method 'range' (a nil value)` and exits
nonzero. Simple headless parsing passed without exercising that directive, so it
is not sufficient regression coverage. Upstream master explicitly excludes
Neovim 0.12 and is frozen. The candidate main API is an incompatible rewrite;
branch replacement alone is not a fix.

Read-only searches covered repository Lua/Vimscript configuration, installed
plugin Lua/Vimscript sources, query directories and installed Git revisions.
References in comments, examples and inactive compatibility branches were not
treated as proof of a live dependency or failure. This is a static inventory,
not an assertion that all runtime paths are compatible.

| Consumer | Finding | Migration verification required |
| --- | --- | --- |
| Treesitter configuration | Legacy configs API, VeryLazy loading, incremental selection and parser list. Main requires eager loading and different setup. | Explicit parser preparation; native highlighting; indentation; preserve expansion/contraction/scope keys through a reviewed solution. |
| nvim-treesitter-textobjects | Installed master `71385f1` directly imports removed configs, parsers, query and ts_utils modules. | Migrate to reviewed main revision and explicit select/swap/move mappings; test all retained capture/key groups. |
| Emmet | Installed `e983971` calls legacy ts_utils in embedded-language detection. Upstream commit `66614158bd9125fb28cb6b6963d05efbba366c7c` replaces it with native get_node. | Review selective upstream update; test HTML/CSS and embedded-language expansion, not just module loading. |
| Aerial | Installed `28fe6e8` uses native parsing/query APIs and ships its own queries; previously updated for node lists. | Nested Markdown symbols, Lua/JS symbols and Fzf integration with the new parser/query set. |
| Rainbow Delimiters | Installed `b55decd` uses native APIs and ships queries; previously updated for missing parsers. | Lua rainbow-blocks, nested delimiters, Markdown injections and parserless Fzf buffers. |
| vim-matchup | Installed `b23ba39` contains native Treesitter support and queries. Legacy setup in the repository is commented out. | Confirm actual activation and percent matching/offscreen behavior; do not enable a new backend implicitly. |
| Mini | Installed `68955a9`; mini.ai is configured with defaults, mini.surround is not enabled. Legacy query imports are optional compatibility paths; the Treesitter generator defaults to native queries. | Preserve current textobject behavior and mapping precedence. mini.ai is not established as an equivalent replacement for incremental node/scope selection. |
| Fzf-Lua | Native preview, context and injection consumers. | File previews, parserless buffers and Aerial picker. |
| Blink, LuaSnip, ts-comments | Native documentation/snippet/comment consumers; optional LuaSnip extras exist. | Completion documentation, existing snippets and comments across injected languages; do not enable unused extras. |
| Conform, Kulala | Native injected-formatting and HTTP/parser consumers. | Existing formatter behavior and HTTP buffers without adding languages/tools. |
| DAP virtual text, Go/Python helpers | Native paths exist; virtual text retains compatibility fallbacks. Go already handles match node lists. | Module/query smoke tests and existing workflows where prerequisites exist; no new debuggers or all-language readiness claim. |
| Trouble, Sidekick, Oil, Lazydev, Lazy | Native parsing, preview, context or highlighting references found. Some paths are optional. | Exercise configured paths on representative files; no blanket updates based only on references. |

Query-bearing plugins found: Treesitter, textobjects, Aerial, Rainbow Delimiters
and vim-matchup. Parser/query provenance and runtimepath precedence must be
checked together after migration; a clean startup alone cannot validate these.
Guest build prerequisites are already present: tree-sitter-cli 0.26.9 and
GCC 16.2.1. No dependency or parser update was performed during this audit.
Incremental-selection replacement and the concrete dependency updates remain
subject to review before implementation.

Sources:
- <https://github.com/nvim-treesitter/nvim-treesitter/blob/main/README.md>
- <https://github.com/nvim-treesitter/nvim-treesitter/blob/master/README.md>
- <https://github.com/nvim-treesitter/nvim-treesitter-textobjects/blob/main/README.md>
- <https://github.com/mattn/emmet-vim/commit/66614158bd9125fb28cb6b6963d05efbba366c7c>

### Guest Treesitter main migration results

The maintainer clarified that only visual `v` and `Ctrl+V` incremental selection
are used, and explicitly approved dropping scope selection and the former
`<leader>v` initialization. Reports of past hangs with scope selection are an
observation, not a diagnosed cause. No extra selection plugin was added. Native
Neovim 0.12 parent/child selection callbacks preserve expansion and contraction
history; normal-mode `v` still enters Visual mode. Changes remain guest-only;
the eventual host 0.12 migration and source publication need separate approval.

After the maintainer saved and closed Neovim, the authorized selective update
was applied through Lazy, not by editing the lockfile:

| Plugin | Branch | Applied commit |
| --- | --- | --- |
| nvim-treesitter | main | d3e4a28b63961ba972b0945d66c73b6eec969953 |
| nvim-treesitter-textobjects | main | 5c7b0263797dfd1bd6202f2b219f3b53a80b2187 |
| emmet-vim | master | 92ef2f74f4093edc99db5e9e4cf7e40116a85bd6 |

Comparison with the pre-update lockfile shows exactly these three entries
changed. Existing Aerial/Rainbow candidate revisions and other plugins were not
updated. A temporary updater used these resolved commits and disabled the three
plugins' configuration while updating; it was not added to product source.

Guest external source changes:
- `lua/plugins/treesitter.lua`: eager main provider; main textobjects setup and
  retained select/move/swap mappings, local to parser-backed buffers as before.
- `lua/config/treesitter.lua`: single declared parser list, native highlighting,
  indentation and visual node-selection mappings. No network/install work on
  editor startup. Missing parsers and non-file buffers are not attached.
- Explicit parser preparation installs and synchronizes according to the selected
  plugin manifest, limits concurrency to two, bounds install/update waits,
  checks task failures and revision/loadability/query postconditions, and cancels
  a failed waiting task. All 17 declared parser revisions pass. Upstream also
  installs required dependencies: HTML and the jsx/ecma/html_tags query resources.
- README documents Neovim 0.12, prerequisites, explicit parser preparation and
  tests; source tests cover installer contracts and representative integration.

Reproduction after locked plugin restore and explicit editor-tool preparation:

```sh
export PATH="$HOME/.nvm/versions/node/v24.22.0/bin:$PATH"
cd "$HOME/code/nvim"
nvim --headless -c "lua require('config.treesitter').run()" -c qa
nvim --headless -u NONE -l tests/prepare-tools.test.lua
nvim --headless -u NONE -l tests/treesitter-preparation.test.lua
nvim --headless -c 'luafile tests/treesitter.test.lua' -c qa
```

Validation outcomes:
- 15 existing editor-tool contract tests pass; 11 new parser-preparation contract
  tests pass with mocked installers (success, privilege/prerequisite failures,
  failed install/update, cancellation and receipt/revision/binary/query checks).
- 24 integration checks pass in the normal guest configuration: all 17 declared
  parsers and available highlights/injections/indents/textobjects/Aerial/Rainbow/
  matchup/locals/folds queries; site/parser precedence; local key registration;
  native expansion and restoration of the previous selection; function selection
  and movement; parameter swap; Markdown highlighting and fenced-code injections
  without legacy handlers; Emmet native HTML detection/expansion; parserless
  buffers. Grammar/query samples use a neutral filetype to avoid activating
  unrelated account-dependent plugin paths. These are not 24 GUI acceptances.
- A second explicit parser preparation reports installed/up-to-date state.
  Before/after recursive file SHA256 lists and tree metadata (paths, types,
  sizes, mtimes and link targets) are identical under the configured site root.
- A separate headless opening of the candidate README confirms its Markdown
  highlighter/parser are active and legacy query handlers are not loaded.
- StyLua checks on the four new/migrated Lua files and `git diff --check` pass.
  The untracked procedure is checked separately against /dev/null.

Diagnostic record directory:
`~/.local/state/mirroros-lab/workbench-prototype/treesitter-migration.pOVIUf/`.
It retains the previous lock/spec, updater logs, initial preparation and rerun
logs, before/after site inventories, and integration logs. It is not yet
secret-scanned acceptance evidence. Parser revision identities are in
`prepare-parsers.log` and the manifest/installed parser-info receipts.

Failed attempts are retained rather than counted as passing checks:
- Initial updater under `-u NONE` skipped Lazy setup because loadplugins was off;
  enabled plugin loading in the temporary updater and retried successfully.
- Initial HTTP fixture activated a prompt labelled `Kulala license token` and
  timed out. No token was supplied. Cause and account requirements were not
  investigated; the actual HTTP workflow remains unverified. Query fixtures now
  use a neutral filetype; no authentication or silent plugin repair was added.
- First parameter-swap assertion ran before the plugin's queued dot-repeatable
  operation; the test now executes queued keys before checking the buffer.
- First Emmet expansion test used a removed function name; it now uses the
  installed `emmet#expandWord` entry point. Both corrected checks pass.

Attended README rendering, physical `v`/`Ctrl+V` key behavior, indentation,
Aerial/Fzf UI, Rainbow display, other configured consumer workflows and the
remaining Task 1 work are still pending. No host configuration change, commit,
push, publication, Pi initialization or claim of full workbench stability follows
from these checks. The accepted virt-column warning is unchanged.

### Required follow-up before promotion

- Exercise candidate Rainbow with Fzf buffers lacking parsers.
- Exercise candidate Aerial with nested Markdown headings and Treesitter symbols.
- Verify Blink binary preparation and subsequent loading without a download.
- Reconstruct the candidate in another empty XDG root; verify lockfile and plugin
  revisions remain unchanged after restore and a second start.
- Check incomplete bootstrap failure/rerun handling before product adoption.
- Select and provision the bounded MirrorOS editor tool list through Mason where
  appropriate, and verify LSP, formatting, diagnostics, search, and clipboard.
- Run `git diff --check` and inspect the candidate diff.
- Obtain attended functional approval. Do not report the full workbench as ready.
- Keep external configuration changes on guest-side reviewable work; publication
  and host-repository changes require separate authorization.

## Requested prototype additions: piw and Google Cloud CLI

The maintainer explicitly added the host's piw function and Google Cloud CLI
for Vertex AI preparation to Task 1. These are guest prototype additions, not
product promotion or acceptance of a general cloud-tool rollout.

### piw editor wrapper

Read only the matching block in the host's `~/.dotfiles/zsh/.zshrc` (line 97).
The bounded search of regular Zsh/alias files in `~/.dotfiles-local` found no
second definition. No symlinks were followed and no host configuration executed.
The function is installed in guest `~/.zshrc` and the prototype `zshrc`:

```zsh
piw() {
  EDITOR=pi-editor \
  VISUAL=pi-editor \
  PI_EDITOR_OPEN_MODE=auto \
  pi "$@"
}
```

The global EDITOR/VISUAL remain nvim. The existing external launcher is linked
without copying its implementation:

```bash
ln -s "$HOME/code/pi-config/scripts/pi-editor" "$HOME/.local/bin/pi-editor"
```

The source checkout remains at the previously selected pi-config revision.
Both Zsh files pass `zsh -n`. An isolated `zsh -f` check loads only the function,
substitutes a mock pi command, and verifies all three environment assignments
and preservation of two arguments including a space-containing argument.
The launcher resolves on the explicit user PATH. `pi-editor --help` is NOT a
supported smoke check: it launched Neovim and timed out. Only that probe process
and its Neovim child were terminated. Actual editor opening/return and context
integration through piw remain attended checks; no success is inferred from
launcher resolution. No existing Pi directory or credentials were inspected.

### Google Cloud CLI source and installation

Official documentation:
- https://cloud.google.com/sdk/docs/install
- https://cloud.google.com/sdk/docs/downloads-versioned-archives
- https://cloud.google.com/docs/authentication/set-up-adc-local-dev-environment

No google-cloud-cli package was found in the guest's local pacman sync metadata;
this does not establish universal repository availability. The prototype uses
Google's self-contained Linux x86_64 versioned archive, installed as the guest
user without sudo, an AUR recipe, installer execution, or automatic profile edits.

- Version: Google Cloud SDK 589.0.0; core 2026.10.09.
- Bundled Python: 3.14.8; bq 2.1.40; gsutil 5.37; gcloud-crc32c 1.0.0.
- URL: https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-cli-589.0.0-linux-x86_64.tar.gz
- Official object metadata: https://storage.googleapis.com/storage/v1/b/cloud-sdk-release/o/google-cloud-cli-589.0.0-linux-x86_64.tar.gz
- Object generation: `1791890871601864`; size: `93451089` bytes.
- Published object MD5 (base64): `w9SR/1uyoZqp+/hvLg6eug==`; size and MD5 matched.
- Locally computed SHA256: `f865da648f6fdae2015abb5b32eaa0eb10520e88f0ca735cfb33795868c8d26f`.
  This is a local content identity, not an independently published upstream SHA256.
- The documentation's floating-name archive checksum
  `817026aec0adea0e2ee8ed3a1ba3eabfe9e5177581fbe16595a8fe495a601300`
  did not match this versioned archive. Installation stopped before extraction;
  the exact official object's metadata was then retrieved over HTTPS and checked.
  No checksum bypass was substituted for the failed floating-archive comparison.

Guest locations:
- Download and metadata: `~/.local/state/mirroros-lab/workbench-prototype/gcloud-download/`.
- Installation: `~/.local/opt/google-cloud-sdk-589.0.0/`.
- Launcher: `~/.local/bin/gcloud` links to the installation's `bin/gcloud`.

Preparation downloaded the versioned URL using `curl --fail --location
--proto '=https' --tlsv1.2`, checked exact object size/MD5 with Python built-ins,
then extracted using `tar -xzf ... --no-same-owner` into a new staging directory
under `~/.local/opt`. The SDK directory was moved with no replacement into the
absent final path, and the launcher link was created only at an absent path.
Existing unrelated installations are not adopted, removed, or overwritten.
No `install.sh`, `gcloud init`, component installation or authentication ran.

Verification used an explicit user PATH and an isolated, non-credential-bearing
CLI configuration directory:

```bash
export PATH="$HOME/.local/bin:$HOME/.nvm/versions/node/v24.22.0/bin:$PATH"
CLOUDSDK_CONFIG="$HOME/.local/state/mirroros-lab/workbench-prototype/gcloud-download/validation-config" \
CLOUDSDK_CORE_DISABLE_USAGE_REPORTING=true \
CLOUDSDK_COMPONENT_MANAGER_DISABLE_UPDATE_CHECK=true \
gcloud --version
```

This returned 0 and reported the versions above. It does not establish account,
API, billing, IAM or model availability. Production delivery/update ownership
for this new dependency still requires review before Task 3.

### Private Vertex AI setup remains attended

Run account setup inside the guest, not in recorded SSH output. For a Google
user account, the documented local-client ADC command is:

```bash
gcloud auth application-default login
```

Do not carry the isolated validation CLOUDSDK_CONFIG into real account setup.
CLI login and Application Default Credentials are distinct; gcloud CLI login
alone is not proof that Pi's client libraries can authenticate. ADC contains a
refresh token and must never enter source, logs, scans or retained evidence.
Do not copy host gcloud credentials. Project/location selection must follow the
actual configured provider; no private project identifiers are hardcoded here.
Required API access, billing, IAM and model availability must be confirmed by the
maintainer. No API enablement, role grant, cloud resource mutation, token-printing
command or paid model request was performed by this preparation. Validate piw's
editor flow and one Vertex conversation privately, recording only the outcome.

### Automatic user-local Zsh fragments

The maintainer approved `~/.config/zsh/conf.d/` for trusted local configuration.
The guest's active and prototype zshrc load it after managed defaults:

```zsh
for config_file in "$HOME"/.config/zsh/conf.d/*.zsh(N); do
  source "$config_file"
done
unset config_file
```

Zsh loads matching files in alphabetical order. `(N)` allows an absent directory
or no matching files without errors. Files execute as the user in each new
interactive shell: do not put network provisioning or untrusted scripts here.
Non-interactive commands must receive their runtime environment explicitly.
MirrorOS owns the loader, not the local fragments; preserve local files on
future configure runs rather than adopting them as managed defaults.

The guest's local `vertex-ai.zsh` supplies the maintainer-selected values using
this structure (placeholders below are not literal configuration values):

```zsh
export VERTEXAI_PROJECT="YOUR_PROJECT_ID"
export VERTEXAI_LOCATION="YOUR_LOCATION"
export GOOGLE_CLOUD_PROJECT="$VERTEXAI_PROJECT"
export GOOGLE_CLOUD_LOCATION="$VERTEXAI_LOCATION"
```

The actual project identifier remains outside product defaults and this record.
New interactive Zsh shells export these values to pi, piw and other child
processes. This does not authenticate ADC or prove provider compatibility.
The new fragment and both zshrc files pass syntax checks; isolated loader tests
verify missing-directory handling, alphabetical ordering and environment
propagation without loading plugins, history or account state. Real provider
use remains an attended check. No existing local fragment was overwritten.

## Audio capture dependency

The maintainer reported `/voice` failing before capture because no supported
capture tool was installed. Read-only host PATH/package checks found ffmpeg
(2:7.1-6), not sox/rec/arecord. The maintainer selected ffmpeg for MirrorOS,
explicitly authorized guest installation, and performed the attended pacman
transaction privately because unattended sudo was unavailable:

```bash
sudo pacman -S --needed ffmpeg
```

Read-only guest checks confirmed `ffmpeg 2:9.0.2-2` from official extra metadata,
`/usr/bin/ffmpeg`, and `ffmpeg version n9.0.2`. This is an observed package version,
not a product version pin. Add the official dependency under its responsible
capability during Task 3 after the blocking prototype review. Do not substitute
sox or install multiple capture providers without a demonstrated requirement.
The maintainer reports guest audio is not configured and requested moving on.
Capture, transcription, audio devices and laptop readiness remain unverified;
voice/TTS stay disabled by default and no model download or audio recording was
performed by this check. Lack of VM audio does not remove the future feature.

## Guest Zsh startup measurements

The maintainer reports that the guest feels faster and the prompt has no
perceptible delay. This is subjective usability feedback, not a measured
host-relative improvement. No host startup configuration was executed.

### Method and reproducibility

The temporary diagnostic script is
`~/.local/state/mirroros-lab/workbench-prototype/measure-startup.py`:

```bash
python3 "$HOME/.local/state/mirroros-lab/workbench-prototype/measure-startup.py"
```

It is a laboratory measurement utility, not a product provisioning framework.
It creates a new record directory per execution and alternates ten minimal and
ten complete shell processes on the same guest resources. Each uses an actual
PTY (120 columns, 40 rows), `TERM=foot`, `LC_ALL=C.UTF-8`, working directory
`~/mirroros`, and `zsh -d -i` (interactive, non-login, global RC files disabled).
The initial PATH is `/usr/bin:/bin`; full startup adds its declared user runtime.
The guest had two virtual CPUs and MemTotal 3994812 kB; kernel
7.2.10-arch1-1, Zsh 5.9.2, Starship 1.26.0. MirrorOS source remained
`58523d5d9734249f08f9a3cf1e52de24be26552c` with only this procedure untracked.
The active zshrc SHA256 was
`9f40fe088c6bc4ddeace574b974cd4d761885591f0486142cf9d5c942cf600cd`.

ZDOTDIR is isolated. Full startup is a byte-derived copy of the active zshrc
with only HISTFILE redirected to an initially empty temporary history plus a
prompt marker appended after the normal prompt. Minimal startup has history
settings and a basic prompt without plugins. No real shell history is read or
copied; normal plugin/application caches and hooks remain enabled, so this is
not a side-effect-free emulation or a realistic populated-history benchmark.
Timing starts before process creation and stops when the marker following the
normal prompt arrives through the PTY. Then the same trivial print command is
sent to both variants and its exact response line is timed. Terminal output is
not retained. This includes process/PTY scheduling overhead and does not measure
physical keystrokes, Wayland rendering, login/session startup or every widget.

No caches were cleared. First-observed means first process in the series, NOT
guaranteed cold boot, empty application caches or fresh plugin installation.
Do not reinterpret these samples as cold-cache evidence or compare them to
unmeasured host startup. A separate PTY profile/feature probe confirms
nvm_load, mirroros_init, zvm_init, autosuggestions and syntax-highlighting
functions are loaded and node/npm/pi/nvim/zsh/tmux resolve without nvm_load.
This is not renewed attended acceptance of every shell feature.

### Results

Corrected record directory:
`~/.local/state/mirroros-lab/workbench-prototype/zsh-startup-xdk26h7h/`.

| Variant | First observed prompt | Subsequent prompt median (9 runs) | Subsequent range | First-command response median (subsequent runs) |
| --- | --- | --- | --- | --- |
| Minimal | 2.878 ms | 3.616 ms | 3.444-4.402 ms | 0.291 ms |
| Complete | 455.894 ms | 237.446 ms | 229.054-262.974 ms | 33.869 ms |

All 20 measured shells exited 0. The separate full-profile function/tool probe
also passed. Files: `startup-timings.tsv`, `summary.json`, `method.json`,
`feature-probe.json`, `zprof.txt`, `zprof.exit`. The top-level prototype
`startup-timings.tsv` is a copy of this corrected series. Retain only these
allowlisted records and the measurement script, not entire temporary HOME/RC
or history directories, for later acceptance evidence.

A preliminary series under `zsh-startup-7iw6m40z` measured the complete prompt at
660.584 ms first observed, subsequent median 240.289 ms (232.952-247.826 ms).
Its separate non-PTY profile was invalid: piped SSH stdin triggers Zplug's
legacy pipe syntax and prevents representative plugin registration. Those
profile warnings/function failures are NOT a product startup defect or passing
feature evidence. Profiling was moved onto a controlling PTY and the whole
series repeated, producing the corrected results above. Do not silently discard
the initial diagnostic limitation or present its profile as valid.

### Costs and decision boundary

The corrected zprof profile includes initialization, prompt hooks, deferred
widget setup, and typing the feature-probe command. Its cumulative function
times are NOT additive wall-clock startup measurements. Observed self time
includes Zplug info logging about 83.79 ms, vi-mode widget definition about
22.09 ms, completion initialization about 10.99 ms, and mirroros_init about
11.19 ms. Highlighting/autosuggestion costs also include probe-command editing,
so they cannot be attributed solely to startup. External command/prompt costs
are not fully captured by zprof. No configuration optimization, feature removal,
provider replacement or host-relative speedup claim was made from this series.

The measured complete prompt median is about 0.24 seconds, consistent with the
maintainer's report of no perceived delay. A numerical acceptance criterion is
still pending explicit maintainer approval at Task 2; none is retroactively
invented here. Fresh installation/cache behavior and real first-prompt
responsiveness remain distinct from these warmed laboratory observations.

The maintainer subsequently accepted the Zsh measurement tests after explicit
clarification that they do not measure Foot launch/rendering to a writable
prompt. This is not acceptance of a numerical Task 2 criterion or all of Task 1.

## Native Tmux UI palette completion

The maintainer reports that Sesh's tested workflows work and Tmux generally
looks good, but identified inherited grey areas in the native Prefix+S session
chooser preview. This feedback does not independently prove Resurrect/Continuum
restoration or complete the Task 2 provider review gate.

Read-only inspection on guest Tmux 3.8 identified native defaults using
`themedarkgrey`/`themelightgrey` for tree preview borders, menu borders, pane-number
overlays and scrollbars. The maintainer explicitly approved completing these
native UI styles in the existing Tokyo Night theme, without changing bindings,
plugins, host configuration, or application themes.

Updated only the guest's `~/.config/tmux/tmux.theme.conf` and matching prototype
copy. Added menu/style/selected/border options, tree-mode border/preview/selection
styles, display-panes foreground/border colors, scrollbar and fill-character
styles, copy-mode search/mark/line-number colors, and switch-mode match styling.
Use `bg=default` for native menu/preview backgrounds and muted blue `#3b4261`
for borders; retain a solid selected-row background with cyan text. Search
matches use cyan on the selected background, the current match uses dark text
on amber, and marks/line numbers remain distinguishable. Existing status layout,
selection mode-style, message prompt styling, popup settings and clock color
are unchanged. No new overlay or floating-pane workflow was introduced.

Validated the complete theme with an isolated plugin-free Tmux server and a
single short-lived sleep fixture, which exits automatically. `source-file`
returned 0 and produced no diagnostics. Diagnostic directory:
`~/.local/state/mirroros-lab/workbench-prototype/tmux-ui.OvSFs8cT/`.
Both original theme hashes were checked before writing. All non-ASCII bytes in
the status layout were verified unchanged. Loaded only the theme into the
existing guest Tmux server without restarting it; queried live native style
options to confirm they match the candidate. These new native options are
validated against Tmux 3.8, not asserted portable to older host versions.

Attended review: reopen Prefix+S and Prefix+double-quote choosers, Prefix+q pane
labels, and right-click menus. Also inspect copy/search, buffer chooser, URL and
Thumbs overlays using disposable non-private text. Existing popup-based plugins
may have their own Fzf styling; native option validation is not proof that every
plugin UI is visually accepted. Avoid plugin-update bindings, Kill/Respawn menu
actions, and sharing screenshots of private pane or clipboard content. Final
visual acceptance of this palette amendment was subsequently confirmed by the
maintainer with Accept; this does not close the overall Task 1/Task 2 gates.

## Right Alt Compose: approved default scope addition

The maintainer's ZMK Ferris Sweep accent macro produced apostrophe followed by
`o` instead of the intended accented character in the guest, while working on
the host. Read-only diagnostics found host `us` with `compose:ralt`, but live
guest Hyprland had `us`, an empty variant and no keyboard options. The maintainer
approved a runtime Compose test and confirmed the accented character then works.
This is evidence for the reported macro, not a complete keyboard/device matrix.

The initially suggested `hyprctl keyword input:kb_options compose:ralt` was
rejected by this guest's non-legacy Lua parser and changed nothing. For the
installed Lua configuration API, the successful runtime command was:

```bash
hyprctl eval 'hl.config({input = {kb_options = "compose:ralt"}})'
hyprctl getoption input:kb_options
```

The maintainer explicitly rejected personal-only treatment and requested Right
Alt Compose as a MirrorOS default. This is an approved expansion of the plan's
keyboard configuration scope, not authorization for unrelated hardware policy
changes, host edits, or bypassing the blocking prototype review.

Prototype persistence adds `kb_options = "compose:ralt"` to the existing input
table in guest `~/.config/hypr/hyprland.lua`, retaining the dynamically selected
layout, existing repeat settings, session model and keybindings. A candidate copy
lives in `~/.local/state/mirroros-lab/workbench-prototype/hyprland.lua`.
The file is checked with Lua's parser without running compositor actions. The
already-applied runtime option remains active; no session restart or compositor
reload is required for this file edit. Loading the persisted file on a fresh
session/reload remains a separate check; no restart was performed here.

Product promotion remains Task 3 work after Task 2 acceptance. Extend its file
scope to the existing compositor owner:
- `capabilities/desktop/compositor/providers/hyprland/hyprland.lua`.
- Review `capabilities/desktop/compositor/providers/hyprland/greeter/hyprland.lua`
  for consistent pre-login keyboard behavior and test it explicitly before
  claiming greeter coverage; no greeter file was changed in this prototype.
- Extend relevant `tests/capabilities/` running/target declarations and native
  delivery checks, plus governing scope/configure documentation.

Retain layout resolution in the existing keyboard.lua owner; do not hardcode
`us` as a side effect of adding Compose. Do not introduce a device-specific
Ferris rule or a second keyboard configuration authority. Compose on Right Alt
uses that key rather than its usual AltGr function, so layouts requiring AltGr
need an explicit supported override and testing. Do not claim all layouts remain
unaffected or invent a new general override framework during this prototype.
The default is not automatically mirrored to host keyboard configuration.

For a temporary runtime rollback using the same Lua API:

```bash
hyprctl eval 'hl.config({input = {kb_options = ""}})'
```

A runtime rollback alone does not remove the persistent declaration; review the
native input table as well when intentionally reverting the default.

## Pi editor leading-line correction

The maintainer confirms Vertex works in the guest (no conversation/account
content retained), but reported an extra initial empty line after a piw editor
round-trip. Pure synthetic build/extract checks preserve the prompt exactly.
Passing the generated Markdown through the installed Prettier reproduces the
extra line: it inserts a blank line after the PI_PROMPT_START HTML comment, and
extraction correctly preserves that newly inserted prompt content.

Narrow read-only host inspection found its active source under
`~/.config/nvim`, not the unrelated non-Git `~/code/nvim` directory. Inspected
Conform/auto-command files contain no special pi-editor formatting exclusion.
Both host and guest assign Prettier to Markdown with autoformat on save. The
host's conventional Mason Prettier path and the harness PATH had no Prettier;
the guest has it through Mason. Installed host Conform searches node_modules
upward from the buffer's directory, not simply the project where Pi started.
Thus a project's local Prettier need not apply to an external temporary file.
Actual host interactive-buffer formatter availability was not queried, so this
is not a definitive runtime inventory or proof of identical environments.
No host editor configuration was executed or changed.

The maintainer approved a scoped external integration correction. Guest
`~/code/pi-config` is now on uncommitted branch `workbench-pi-editor`, based on
`08b2469c604c2149573c82beab8c7fd3aa905b07`. Only these tracked files changed:
- `scripts/pi-editor-lib/editor-open.mjs`.
- `tests/pi-editor/cases.mjs`.

Inside the existing context-marker branch of the shared Lua setup command,
set `vim.b.disable_autoformat = true` before folding/positioning. The guest's
Conform config already honors that buffer flag. Both standalone Neovim and nvr
use the shared command; do not set a global flag, change normal Markdown
formatting, strip intentional prompt whitespace, or add a Pi version repair.
An unmarked buffer receives no autoformat flag; unrelated buffers retain normal
formatting. No extension implementation, dependency or lockfile was changed.

Validation record:
`~/.local/state/mirroros-lab/workbench-prototype/pi-editor-fix.0SBqNcL8/`.
The added contract uses fake editor executables and synthetic content to assert
both route commands contain the conditional buffer-only flag and match, and
checks preservation of empty prompts, leading lines/spaces and trailing lines.
The new regression fails against original source and passes with the patch.
An initial full-suite run passed 28/29 because the isolated source archive had
omitted extensions/files.ts, needed by an existing source-inspection test.
Added only that tracked file to the archive and reran: 29/29 pass. This was a
fixture-copy omission, not a changed extension or ignored test failure.

The native probe opens only synthetic Markdown in Neovim with `-u NONE -i NONE
-n`, an isolated HOME, and explicitly loads the installed Conform plugin plus
the guest's existing Conform spec. Four scenarios pass: baseline reproduces the
extra initial line, patched save preserves the prompt, patched save preserves
intentional leading lines/spaces, and an unmarked Markdown buffer still gets
formatted. It also checks the buffer flag does not leak to a new buffer and
that global autoformat remains enabled. No real user prompt, session/auth file,
editor state or private temporary file was read.

Commands (the HOME/TMPDIR isolation is intentional):

```bash
record="$HOME/.local/state/mirroros-lab/workbench-prototype/pi-editor-fix.0SBqNcL8"
export PATH="$HOME/.nvm/versions/node/v24.22.0/bin:/usr/bin:/bin"
cd "$HOME/code/pi-config"
node --check scripts/pi-editor-lib/editor-open.mjs
node --check tests/pi-editor/cases.mjs
env -i HOME="$record/home" TMPDIR="$record/tmp" PATH="$PATH" \
  node tests/pi-editor/run.mjs
node "$record/native-autoformat-probe.mjs" "$record" "$HOME"
git diff --check
```

The native probe targets the reviewed archive in record/candidate, while the
last contract run targets the applied guest branch. Both run successfully;
logs are synthetic diagnostics, not a substitute for attended piw acceptance.
Keep allowlisted script/log outcomes only, not the entire sandbox HOME or
source archive, when preparing final evidence. No commit/push/publication was
performed. Task 3/clean reconstruction cannot consume this unpublished branch
as an invisible dependency; normal-branch publication requires separate review
and authorization. The maintainer still needs to exercise piw's actual editor
round-trip and confirm the unwanted line is gone.

### Amendment: preserve protection when the intermediary is reloaded

During review the maintainer opened another Markdown buffer and returned to the
intermediary, where formatting resumed. The first fix set only a buffer variable
once. With existing `bufhidden=delete`, leaving that buffer can unload/delete it
and lose the variable. Synthetic Neovim reproduction confirmed this lifecycle
gap. The first patch is therefore not independently accepted as a complete fix.

The maintainer approved a narrowly scoped correction keyed by the exact
intermediary filename, explicitly retaining the existing deletion/wait contract.
Inside the same context-marker branch, capture the absolute current buffer name
and create an owned BufReadPost rule. Its callback reapplies the buffer-local
flag only when the newly loaded buffer has that exact name. This works with
either generated working-file convention without maintaining filename glob
patterns or affecting a same-basename Markdown file in another directory.

The autocmd group name uses a SHA256 of the filename; registering that file
again clears/replaces its owned group instead of adding duplicates. On subsequent
BufReadPost events, if the intermediary no longer exists, remove only that group.
Otherwise the rule remains available for reopening the file. A persistent
working file intentionally retains its rule until removal or Neovim exit.
Cleanup is deferred to another read event or process exit, not a new completion
signal. No buffer-close hooks, `hide` conversion, session service, global
formatting flag or generic temporary-file exclusion was introduced.
The original `bufhidden=delete`, nvr wait flags and route selection are unchanged.

Changes remain uncommitted on guest `workbench-pi-editor`:
- `scripts/pi-editor-lib/editor-open.mjs` extends the shared setup command.
- `tests/pi-editor/cases.mjs` checks exact-path reload registration/cleanup,
  no global formatting disable, unchanged deletion and nvr remote-wait arguments.
- New `tests/pi-editor/autoformat-buffer.test.mjs` runs native Neovim with no
  plugins, isolated HOME and synthetic files. It tests initial protection,
  changing to another Markdown and back after deletion, a matching basename at
  another path, special characters in the filename, duplicate registration,
  global/buffer isolation and owned-rule cleanup after the fixture disappears.

The native reload regression fails against the previous one-shot buffer flag
and passes with this amendment. All 29 existing/mock contracts pass. The native
Node test reports 1 passed, zero failures/skips on the guest; if Neovim is absent
it explicitly skips rather than claiming native validation. The four prior
actual Conform/Prettier synthetic-save scenarios also pass again. Applied branch
syntax checks, git diff --check, and an explicit whitespace check of the new
untracked native test pass.

Record directory:
`~/.local/state/mirroros-lab/workbench-prototype/pi-editor-reopen.NIjX2U46/`.
Allowlisted logs include `reopen-before.log`, `reopen-after.log`,
`contracts-after.log`, `applied-contracts.log`, `applied-reopen.log` and synthetic
Conform-probe logs. Do not copy the whole sandbox HOME/source archive.

```bash
record="$HOME/.local/state/mirroros-lab/workbench-prototype/pi-editor-reopen.NIjX2U46"
export PATH="$HOME/.nvm/versions/node/v24.22.0/bin:/usr/bin:/bin"
cd "$HOME/code/pi-config"
node --check scripts/pi-editor-lib/editor-open.mjs
node --check tests/pi-editor/cases.mjs
node --check tests/pi-editor/autoformat-buffer.test.mjs
env -i HOME="$record/home" TMPDIR="$record/tmp" PATH="$PATH" \
  node tests/pi-editor/run.mjs
env -i HOME="$record/home" TMPDIR="$record/tmp" PATH="$PATH" \
  node --test tests/pi-editor/autoformat-buffer.test.mjs
node "$record/native-autoformat-probe.mjs" "$record" "$HOME"
git diff --check
```

The guest has no nvr executable on the inspected noninteractive PATH. Both route
argument contracts use command doubles and share the natively tested setup;
this is not proof of real nvr wait/return behavior. No nvr installation occurred.
Switching away may still complete remote editing under the existing deletion
contract; this amendment deliberately does not redesign that behavior. The
attended standalone piw round-trip/reopen check remains required, and real nvr
behavior must be tested if adopted. No host changes, dependencies, commits or
publication were added. The unpublished external-branch boundary remains.

The maintainer subsequently selected Accept for the exact-path piw amendment,
with a new Sidekick integration issue noted separately below. This accepts that
incremental correction, not all Pi entry points or the Task 1/Task 2 gates.

## Sidekick portable Pi editor launcher

The maintainer reports that Pi started through Sidekick remains in Pi when
Ctrl+G is pressed, and separately reports model-pattern warnings. Read-only
inspection found that `lua/plugins/sidekick.lua` supplied a hardcoded host-home
editor path to both EDITOR and VISUAL. This inherited path had been visible in
prior inspection, but the Sidekick launch flow had not been corrected or tested;
prior successful piw tests did not cover it. Record this as a missed integration
case, not a regression caused by the buffer-reload amendment.

The maintainer explicitly approved correcting the path. Changed only the
fallback in the guest's existing `workbench-neovim` branch:

```lua
local pi_editor = vim.env.PI_EDITOR or "pi-editor"
```

Sidekick still invokes `pi` directly (not the interactive piw function) and sets
its own editor environment. The explicit PI_EDITOR override remains supported;
no command identity, routing metadata, bindings, plugin version, or mux lifecycle
changed. `pi-editor` resolves to the executable guest user link on the declared
user runtime PATH. Existing unrelated dirty Neovim work was preserved.

Added `tests/sidekick-editor.test.lua`, which loads only the native declaration
with a simulated vim environment and checks four Pi/Claude default/override
routing cases, plus unchanged Pi command identity, auto mode and owner metadata.
It does not launch Sidekick, Tmux, Pi, nvr, user startup configuration or account
state. The regression fails with the former host path, and all four cases pass
on the candidate and applied branch. git diff --check and an explicit whitespace
check of the new untracked test pass.

```bash
cd "$HOME/code/nvim"
nvim --headless -u NONE -i NONE -n -l tests/sidekick-editor.test.lua
git diff --check
```

Tests used a temporary HOME and synthetic values. Record directory:
`~/.local/state/mirroros-lab/workbench-prototype/sidekick-editor.JKmaUMxl/`
contains `before.log`, `after.log` and `applied.log`. These are routing tests,
not proof that the real active Neovim process has refreshed its Sidekick config.

Attended follow-up: save work, exit the disposable Pi instance normally, and
use a fresh Neovim/Sidekick launch rather than reusing a mux session with stale
environment. Verify Ctrl+G opens the editor and returns normally after editing.
No existing session was closed automatically. Without nvr, auto mode can use a
standalone Neovim process; reuse of the owning editor remains unvalidated and
must not be claimed. No nvr package was installed by this correction.
Model-pattern warnings remain a separate unresolved diagnostic; no settings,
provider definitions, dependency versions or compatibility repairs were changed.
No private sessions/auth/history were read, no host files changed, and no commit
or publication occurred. External normal-branch promotion remains separately
authorized work before product reconstruction.

The maintainer accepted the portable Sidekick editor-path correction. Model
warnings persisted only through Sidekick, prompting the environment diagnosis
and approved amendment below; this does not mark the warnings resolved.

## Environment-only Zsh startup and explicit Sidekick Vertex forwarding

Read-only presence checks found all four Vertex/Google Cloud variables in the
host Tmux global environment but none in the guest server. No values, credentials
or complete environments were printed. The reviewed host startup link points to
`~/.dotfiles/zsh/.zshenv`, which sets ZDOTDIR and sources `~/.zcustom`. The
maintainer states the variables are defined there. The prohibited source itself
was not read, followed, executed or copied. The host's Tmux update-environment
list does not include these variables; its exact startup chronology is unknown.
Do not claim which process originally populated its environment.

This differs from the previous guest arrangement: Vertex exports lived in
conf.d loaded only by interactive zshrc. Exporting them there does not update an
already-running Tmux server. Installed Sidekick code creates the Pi tool through
Tmux and explicitly passes only configured tool environment entries; it does
not run the interactive piw function. This explains a concrete environment gap,
not yet a complete diagnosis of every reported model-pattern warning. A separate
read-only diagnostic now reports user Pi 1.3.0 versus earlier observed 1.2.0;
no agent runtime upgrade occurred in this amendment. Reconcile actual version
provenance before product reconstruction rather than silently assuming the old
observation still applies.

The maintainer approved an environment-only startup layer plus explicit
forwarding. New managed prototype `~/.zshenv` (also copied to prototype/zshenv):

```zsh
# managed by MirrorOS configure
# Trusted user-local environment only: exports, no output or provisioning.
for env_file in "$HOME"/.config/zsh/env.d/*.zsh(N); do
  source "$env_file"
done
unset env_file
```

`~/.config/zsh/env.d/` is for trusted, quiet, lightweight exports used by new
interactive and noninteractive Zsh processes. `~/.config/zsh/conf.d/` remains
loaded only from zshrc for interactive customization. These are executable
native fragments, not a declarative schema or a provisioning framework. Do not
put plugins, prompts, network operations, installation, interactive commands or
startup output in env.d. Shells using `zsh -f` deliberately skip normal user RC
loading and are not promised these exports.

Moved the existing guest `vertex-ai.zsh` from conf.d to env.d without changing
its bytes or mode. Destination creation refused existing paths; source and
destination identity/content were checked before removing the old directory
entry. There is no duplicate active fragment. The actual project identifier
remains user-local, not embedded in product defaults or evidence. The zshrc
loader and existing files in conf.d remain unchanged. No host configuration or
existing Tmux server environment was changed.

Guest Neovim's Pi tool now explicitly forwards only these four inherited values:

```lua
VERTEXAI_PROJECT = vim.env.VERTEXAI_PROJECT or false,
VERTEXAI_LOCATION = vim.env.VERTEXAI_LOCATION or false,
GOOGLE_CLOUD_PROJECT = vim.env.GOOGLE_CLOUD_PROJECT or false,
GOOGLE_CLOUD_LOCATION = vim.env.GOOGLE_CLOUD_LOCATION or false,
```

Sidekick's installed Tmux backend treats false as an unset (`-u`) rather than
inheriting a stale server value. No project fallback, hardcoded account data,
credential variable forwarding, provider/model changes or global Tmux sync was
added. The unrelated Claude environment is unchanged. Neovim must itself be
launched with the correct environment; an existing process or graphical launcher
that never inherits Zsh exports is not automatically repaired by this file.
Existing Pi sessions must not be assumed refreshed.

Validation: zsh -n passes for the loader and moved fragment. Isolated HOME
contracts cover an absent env.d, alphabetical ordering, quiet startup, temporary
loop-variable cleanup, child-process exports, noninteractive shells and distinct
login/interactive RC loading. A real guest noninteractive `zsh -dc` with a clean
parent environment confirms all four exports reach a Python child, without
printing their values or loading zshrc/history. Expanded Sidekick test fails
against the previous declaration and passes all six cases on candidate/applied
source: portable editor/override cases plus present/absent Vertex propagation,
using distinct synthetic values and confirming no Claude changes.

Record directory:
`~/.local/state/mirroros-lab/workbench-prototype/zshenv-vertex.ZNNFCfXZ/`.
Allowlisted outcomes: `shell-contracts.log`, `sidekick-before.log`,
`sidekick-after.log`, `sidekick-applied.log`. Do not retain the fixture HOME or
user-local Vertex fragment as product evidence. Applied source git diff --check
and explicit untracked-test whitespace checks pass.

Task 3 scope now also includes `capabilities/workflow/shell/zshenv` and shell
apply/tests/documentation for delivering this native startup file in both
contexts. Preserve unrelated existing .zshenv files under established ownership
rules and preserve user-local env.d/conf.d fragments. This is not authorization
to read/copy arbitrary host startup data or to migrate global session environment
policy speculatively. The external Neovim branch remains uncommitted/unpublished.

Attended follow-up: save work and use a new terminal Zsh, a fresh Neovim process
and a newly started Pi tool in Sidekick (exit any disposable old Pi normally,
not merely detach and reuse it). Confirm the model warnings disappear and
Ctrl+G still works. No process/service restart or account/API request was
performed here, and this source verification does not claim final runtime
resolution or all workbench acceptance.

### Subsequent attended outcome and resumed inventory

The maintainer subsequently confirmed that the Sidekick model-pattern warnings
are gone and Ctrl+G works. The portable editor-path correction, exact-path editor
reopen protection, and environment/Vertex forwarding received incremental Accept
reviews without reported manual amendments. Vertex use was separately confirmed
privately. These outcomes do not close Task 1, establish real nvr wait behavior,
or pass the blocking Task 2/reconstruction gates. Do not repeat authentication or
restart working sessions merely to reproduce these already attended outcomes.

Read-only resume checks confirm the three guest branches and source bases:
- MirrorOS workbench-prototype at 58523d5d9734249f08f9a3cf1e52de24be26552c;
  only this procedure is untracked.
- Neovim workbench-neovim at 654973fa0a5e3d5b15e782f8fe449ac347df014f;
  preparation, compatibility and Sidekick changes remain dirty/unpublished.
- pi-config workbench-pi-editor at 08b2469c604c2149573c82beab8c7fd3aa905b07;
  editor source/tests remain dirty/unpublished.
All three tracked-source git diff --check commands pass. No commit or push ran.

The resumed runtime check reports Node v24.22.0, npm 11.19.1 and Pi 1.3.0,
while pi-config still declares exact devDependency 1.2.0. The origin and
installation authorization of this drift are not established by these checks.
Ask the maintainer before choosing a correction; do not silently downgrade,
change the dependency or claim AC-4 exact-version selection currently passes.
Existing ~/.pi remains protected; no auth/session/configuration contents were
read to investigate this mismatch.

The prototype now has source-map.tsv and package-list.txt beside its native
candidate files. They are selected observations, not a central product manifest,
full license inventory, permanent version pins or accepted product declarations.
The source map records full clean-checkout identities for Zplug/plugins,
TPM/plugins, Sesh, external configuration bases and NVM, plus prior recorded Pi
package selections and gcloud provenance. No remote tips were newly resolved,
plugins installed or external files repaired for this inventory.

NVM v0.40.8 identities recovered from its clean guest checkout:
- Tag object: 8db529c5350353f165e1e7f6abb6eb6909f7fd37.
- Commit: a885b885fef16fac4bc544188fb25e9e37ae83e8.
- SHA256 of install.sh at that tag:
  48a0eee9a60e07422dce0eb5774754c83889570ca1ee2566c516acbe8af03a9e.
This is the selected Git object's content identity, not an upstream signature.
The earlier preparation used PROFILE=/dev/null and NVM_INSTALL_VERSION=v0.40.8;
no installer was rerun and no profile was changed during recovery.

With PATH explicitly including ~/.local/bin, the selected Node bin directory,
/usr/local/bin and system bins, node/npm/pi/nvim/zsh/tmux/sesh/pi-editor/gcloud,
ffmpeg/fzf/zoxide/atuin/fd/bat/rg/wl-copy all resolve without nvm_load. An initial
probe omitted /usr/local/bin and stopped at Sesh; the corrected probe resolves
/usr/local/bin/sesh. zsh -n passes on prototype zshenv, zshrc, zprofile and
environment.zsh. A textual Sessionx match is only the existing Sesh replacement
comment, not a plugin declaration. These are bounded source/PATH checks, not
renewed graphical acceptance or fresh installation proof.

Before Task 1 can close, finish skill snapshot license/attribution and durable
ownership planning, approve and run a fresh-tool preparation test, and approve
and test restoration using disposable Tmux sessions without personal state.
Sesh product installation remains an unresolved reviewed delivery choice.
Numerical shell acceptance remains reserved for Task 2. No host product changes,
private-state inspection, installations, model downloads, VM launches, service
restarts or publication were performed by these resumed inventory checks.

### Authorized pi-config update

The maintainer clarified that the upstream configuration had been updated and
explicitly authorized pulling it in the guest. Verified the expected HTTPS
origin and fetched master once, resolving
1596c6398e571c9dfefa569237b4d9ae93f41501. Applied only a fast-forward with
merge.autostash=false and --ff-only on workbench-pi-editor. The local editor
source, cases and untracked autoformat regression test were preserved; no stash,
reset, commit or push occurred. git diff --check passes afterward.

The selected root devDependency now specifies exact Pi 1.3.0, matching the
previously observed executable. This resolves the declaration/runtime version
mismatch, not the missing historical installer provenance or proof of configure's
version-selection mechanism. Incoming changes affect root and seven extension
package manifests/lockfiles. No npm install/ci was run, so installed dependencies
must not be claimed reconciled with these new lockfiles. Existing ~/.pi was not
read or modified. Its links can expose the updated external checkout without
rewriting the protected directory, as already documented by the update policy.

### Skill snapshot distribution and durable ownership review

The maintainer previously authorized preserving all six installed skill copies,
including reported local edits, as MirrorOS content instead of reinstalling
current upstream versions. This expands Task 3's source/attribution/test scope;
it does not authorize product promotion before Task 2. Original installed commits
remain unknown. Current upstream license references below do not retroactively
establish the snapshots' original revisions.

A read-only verification recomputed all 203 payload hashes from
pi-skills-snapshot.3lr491yo/snapshot-manifest.json. All match; each path was
checked component-by-component to refuse symlinks and nonregular payloads. Counts:
aikido-mcp 2, atlassian-mcp 1, show-me 1, teach 5, wait-what 2, archify 192.
No skill, updater, renderer, browser or package command was executed.

| Snapshot | Known ownership / terms | Remaining delivery requirement |
| --- | --- | --- |
| aikido-mcp | Maintainer-authored, per explicit statement | Confirm distribution under MirrorOS's project license or supply a separate notice; private mcporter/account setup remains external. |
| atlassian-mcp | Maintainer-authored, per explicit statement | Same licensing confirmation; no account configuration or credentials are included. |
| teach, wait-what | Matt Pocock; upstream MIT notice, copyright 2026 | Package the full copyright/permission notice with each distributed copy; preserve installed content/support files rather than substitute current upstream. |
| show-me | HumanLayer; upstream MIT notice, copyright 2026 | Package the full copyright/permission notice with the snapshot. |
| archify | 2.17.0-dev.1; own code MIT, copyrights 2026 tt-a1i and 2025 Cocoon AI | Preserve LICENSE and THIRD_PARTY_NOTICES.md; resolve embedded mark redistribution and incomplete parent-repository test dependencies before promotion. |

Verified license references (read-only, fixed comparison revisions):
- https://github.com/mattpocock/skills/blob/49dd158d1076134a641b33efb035946536778336/LICENSE
- https://github.com/humanlayer/skills/blob/653b6411c1f70c275a18e37673b042ff99f67ceb/LICENSE

The first three third-party skill directories do not currently contain LICENSE
files. Their upstream MIT grant requires retention of the copyright and
permission notice; the gap must be fixed in delivery packaging, without editing
the approved skill payloads or pretending a new notice was part of the original
snapshot manifest. Preserve a separate supplemental-notice provenance record.

Archify's own third-party notice explicitly distinguishes code licensing from
embedded marks. It records Simple Icons 16.28.0 collection data as CC0, but also
individual Angular CC-BY-4.0, Apache Apache-2.0, Jenkins CC-BY-SA-3.0, Rust
CC-BY-SA-4.0, and Vue CC-BY-NC-SA-4.0 terms; OpenAI usage remains subject to its
brand guidelines. The marks are embedded in generated-brand-marks.mjs, not just
optional external downloads. Merely preserving a notice does not establish
permission for every redistribution/use. No blanket MIT clearance, automatic
asset removal, skill exclusion or legal compatibility conclusion is asserted.
Present an explicit reviewed delivery choice if these terms cannot be satisfied.

Archify package scripts check:release-identity, build:gallery, build:guide,
build:start, build:readme-showcase, test and render:examples reference paths in
the absent parent repository. The installed skill is not a complete upstream
source/test checkout. Do not claim its full npm test suite passes or download a
new version to hide this limitation. Standalone functional checks still need a
bounded reviewed scope; no npm hooks or updater were run in this review.

Proposed Task 3 ownership, pending explicit review:
- Source snapshots under capabilities/workflow/pi/skills/<name>/, with supporting
  files, per-snapshot hashes, supplemental notices and provenance alongside them.
- Deliver to a stable user-owned ~/.local/share/mirroros/pi/skills/ path, not
  ~/.local/state/mirroros-lab or a temporary measurement directory. Specify and
  test safe destination ownership/conflict behavior before implementation.
- Fresh Pi initialization may link to delivered skills; existing ~/.pi links and
  directory contents remain untouched. Any transition away from prototype links
  is a separate attended action, never automatic adoption of existing Pi state.
- No generic skill manager, floating npx reinstall, implicit npm install,
  executable-mode assumptions, model download or private MCP bootstrap.

This proposal is not implemented. Six real Pi links still point at the protected
prototype snapshots. Resolve the maintainer-authored licensing choice and Archify
redistribution/support scope before representing these as durable product inputs.
Task 1 review, Task 2 provider/performance acceptance, fresh editor-tool preparation
and disposable Resurrect/Continuum proof remain pending.

### Maintainer licensing authorization and complete Archify review path

The maintainer explicitly authorized distributing aikido-mcp and atlassian-mcp
under MirrorOS's project license. Supplemental source notices and packaging are
still Task 3 work; no skill files were edited to record this authorization.
The maintainer selected preserving Archify complete while investigating its
redistribution terms, rather than stripping marks or dropping the skill. This
is a review direction, not permission to override third-party rights or a finding
that all marks are cleared.

Static JSON extraction of BRAND_MARKS (without importing/executing its module)
confirms 107 embedded marks. Eight have explicit individual license metadata:
Angular, Apache Airflow, Apache Kafka, .NET, JavaScript, Jenkins, Rust and Vue.
OpenAI records an official brand-asset source without an individual license;
the other 98 likewise lack individual license metadata in this generated bundle.
Missing metadata alone establishes neither prohibition nor permission.

The fixed Vue artwork README attributes Evan You and specifies CC-BY-NC-SA-4.0
with additional listed use cases. It permits Vue-related open-source projects,
educational materials, and illustrating a commercial product's Vue integration;
other commercial product uses require prior written consent. MirrorOS's general
workbench/diagram catalogue use is not clearly covered by those examples.
Creative Commons' official deed confirms redistribution is conditional on
attribution, noncommercial use and share-alike for adaptations, and that the
license may not supply all necessary rights. An unrestricted GPL license for
MirrorOS code does not relicense this artwork or remove its separate conditions.
No conclusion that an aggregate necessarily relicenses the whole project, or
that free-of-charge delivery automatically satisfies NC, is asserted.

Jenkins's official artwork page requires attribution to the Jenkins project
with its link and identifies CC-BY-SA-3.0. That obligation can be recorded in
packaging, but does not establish clearance for other marks. Simple Icons'
16.28.0 disclaimer explicitly states its collection CC0 does not imply all
underlying icons are CC0 and asks consumers to check relevant permissions and
brand guidelines. The current OpenAI brand URL returned a JavaScript/cookie
challenge, not usable guideline text; the Rust policy URL failed readable
extraction. Neither failed fetch counts as a completed terms review. No browser
credentials, private sessions or bypass mechanism were used.

Review references:
- https://github.com/vuejs/art/blob/a1c78b74569b70a25300925b4eacfefcc143b8f6/README.md
- https://creativecommons.org/licenses/by-nc-sa/4.0/
- https://creativecommons.org/licenses/by-nc-sa/4.0/legalcode.en
- https://www.jenkins.io/artwork/
- https://github.com/simple-icons/simple-icons/blob/16.28.0/DISCLAIMER.md
- https://www.apache.org/foundation/marks/
- https://openai.com/brand/ (blocked response; terms not verified)
- https://www.rust-lang.org/policies/media-guide (extraction failed)

To unblock the selected complete-snapshot path, establish a documented grant or
qualified interpretation covering the actual distribution of the embedded Vue
artwork, complete the remaining applicable license/brand review, and package
required attribution/license/change notices without falsely relicensing assets.
Contacting copyright owners, opening upstream issues or publishing requests
requires separate authorization; no contact was made in this review. An upstream
Archify clarification could supply provenance or existing permissions, but its
maintainer cannot grant rights it does not hold. Keep any obtained permissions
within their actual scope; do not label all 107 marks cleared by one response.
Archify product promotion remains blocked, while the private prototype is
unchanged. No asset removal, replacement snapshot or runtime installation was
performed.

### Superseding skill source policy: current upstream plus manual invocation

The maintainer clarified that preserving the external snapshots was intended to
preserve manual-only invocation, not historical versions. They explicitly
selected latest-upstream installation through npx skills for archify, teach,
wait-what and show-me, followed by setting disable-model-invocation: true in each
SKILL.md frontmatter. aikido-mcp and atlassian-mcp are excluded from this change:
their maintainer-authored snapshots remain MirrorOS content under the authorized
project license. This supersedes the earlier six-snapshot incorporation proposal
and complete-Archify redistribution path, not the private-state protections.

Do not copy the four external skill trees into MirrorOS authoritative source or
ISO content under this policy. Download them from upstream during explicitly
requested preparation; preserve upstream notices, record consumed revisions and
the local frontmatter amendment. This changes MirrorOS's distribution mechanism,
not third-party licenses or permissions for every possible use. The prior
embedded-mark review is not a blanket prohibition on private installation and
is not a requirement to clear all 107 marks before testing an upstream install.

Read-only installer investigation found npm latest skills 1.7.2, gitHead
671e8c320810d36fed80fac5f1a2c1bf7e82d812, requiring Node >=22.20.0. Node v24.22.0
meets this prerequisite. Documentation and the matching source identify Pi's
native global target as ~/.agents/skills and project target as .agents/skills;
--agent pi, --skill <name>, --copy and --yes allow bounded selection. No --all or
implicit agent detection is needed. Project scope in an isolated directory can
exercise the installer without replacing any real user skill or ~/.pi entry.

Current upstream discovery identifies these paths (not permanently pinned
configuration versions):
- mattpocock/skills: skills/productivity/teach and skills/productivity/wait-what.
- humanlayer/skills: plugins/show-me/skills/show-me.
- tt-a1i/archify: archify; do not select repository-internal archify-review or
  archify-tuning skills instead.

Before installation, resolve each selected current upstream branch once and
record its commit. Install from those local resolved checkout paths with npx
skills, so a second floating resolution cannot silently change the consumed
source. The CLI executable version is independently identified; using an exact
observed CLI version does not pin the external skills to old snapshots. Retain
only non-secret source identities and selected validation outcomes as evidence.

The installed Pi 1.3.0 skills documentation confirms that
`disable-model-invocation: true` hides a skill from automatic model selection but keeps manually entered
/skill:<name> commands available. Its enableSkillCommands setting controls command
discovery, not whether a manually entered skill command can work. This is an
invocation policy, not a sandbox or an absolute barrier to explicit file reads.

The first execution must be a separately authorized, fresh isolated installation:
use a new output directory and HOME/npm configuration/cache, explicit Node PATH,
disabled telemetry, no private Git/SSH credentials, npm lifecycle scripts disabled,
and only the four selected skills. Verify the complete installation and parse
frontmatter before making the single field amendment; reject malformed or
ambiguous headers instead of blindly prepending duplicate fields. Keep support
files and body bytes unchanged, then verify the four manual-only flags and Pi
loading with synthetic state. Do not run skill scripts, browsers or model calls
as an implicit installer check. This investigation did not execute npx/npm or
replace the currently active skills.

Existing ~/.pi and the targets of its active links must not be mutated by this
test. Promoting new skill destinations into the live prototype requires a
separate explicit decision; do not introduce duplicate active names through a
normal global install. Product initialization/preservation and update/rerun
behavior remain Task 2/Task 3 review work, not silently settled by a CLI example.

References:
- https://registry.npmjs.org/skills/latest (observed skills 1.7.2 metadata).
- https://github.com/vercel-labs/skills/blob/671e8c320810d36fed80fac5f1a2c1bf7e82d812/README.md
- https://github.com/vercel-labs/skills/blob/671e8c320810d36fed80fac5f1a2c1bf7e82d812/src/agents.ts
- Installed Pi docs/skills.md, docs/settings.md and docs/packages.md (1.3.0).

### Authorized isolated upstream skill installation result

The maintainer explicitly authorized the isolated installation described above.
Record: ~/.local/state/mirroros-lab/workbench-prototype/skills-upstream-test.2qZN9jaB/.
No real ~/.pi, active skill destination or maintainer-authored snapshot was
modified. The test used a new project, HOME, TMPDIR, npm cache and separate empty
user/global npm config, explicit Node v24.22.0 PATH, disabled npm lifecycle
scripts and telemetry, no inherited credentials, no Git terminal prompts and no
private credential helper. No sudo, model request, browser or skill script ran.

Selected current upstream sources were resolved once through public Git HEAD
symrefs, fetched by exact commit into separate local checkouts, then consumed
through npx skills. All three selected branches were refs/heads/main:
- mattpocock/skills: 49dd158d1076134a641b33efb035946536778336.
- humanlayer/skills: 653b6411c1f70c275a18e37673b042ff99f67ceb.
- tt-a1i/archify: ba701d20a55ed6f139484d9ead7ff45671fe40eb.
Installed CLI package reports skills 1.7.2. Current Archify package reports 3.2.0,
not the older snapshot's 2.17.0-dev.1. This is a current-source prototype, not a
claim that old Archify runtime behavior/support tests apply to the new version.

The reviewed install-isolated-skills.sh records the isolation and Git resolution
commands. With those settings and working directory record/project, its actual
installation commands were:

```bash
npx --yes --package=skills@1.7.2 skills add "$record/sources/mattpocock/skills/productivity" --skill teach wait-what --agent pi --copy --yes
npx --yes --package=skills@1.7.2 skills add "$record/sources/humanlayer/plugins/show-me/skills/show-me" --skill show-me --agent pi --copy --yes
npx --yes --package=skills@1.7.2 skills add "$record/sources/archify/archify" --skill archify --agent pi --copy --yes
```

All three commands returned zero, selecting exactly four skill directories under
project/.agents/skills. Npx's package version is recorded, but its dependency
tree is not claimed permanently pinned. The logs refer only to public source
paths and synthetic installation scope; never retain the entire test HOME/cache
or downloaded source trees as acceptance evidence.

validate-manual-skills.mjs uses the installed Pi frontmatter parser and bounded
skills loader, not an agent session or extension loader. It first verifies every
installed file and its bytes against the resolved upstream skill directory and
rejects symlinks/nonregular entries. All four complete payload comparisons pass.
It validates unambiguous YAML headers, names/descriptions and field shape before
writing any SKILL.md. It sets only disable-model-invocation: true and checks
other parsed frontmatter values, exact body bytes and all support-file hashes
remain unchanged. No whole-header YAML serialization or skill-body rewrite.

Native Pi 1.3.0 loader results after the amendment:
- Exactly archify, show-me, teach and wait-what loaded.
- Zero diagnostics; all four disableModelInvocation values are true.
- formatSkillsForPrompt returns an empty string for this four-skill set.
- Support files unchanged; only the selected frontmatter field amended.

Allowlisted records: install-isolated-skills.sh, validate-manual-skills.mjs,
resolved-sources.tsv, install-mattpocock.log, install-humanlayer.log,
install-archify.log, installed-before.json, installed-after.json,
validation.log and validation-result.json. The shell script passes bash -n and
ShellCheck; the validator passes node --check. These are laboratory utilities,
not a new product provisioning framework.

This demonstrates fresh CLI installation and Pi parsing/automatic-selection
suppression, not interactive slash-command use, complete Archify rendering or
private MCP readiness. Existing active links still reference the old snapshots.
Activation of new destinations requires separate explicit approval and collision
handling; no global installation or silent active-link replacement occurred.
Task 1 remains in progress and Task 2 has not been accepted.

### Lazygit prerequisite and portable candidate

The maintainer requested Lazygit for the existing Neovim Toggleterm integration
on <leader>G and explicitly authorized its official Arch package installation.
After unattended sudo preflight failed, the maintainer privately ran:

```bash
sudo pacman -S --needed lazygit
```

Read-only checks confirm lazygit 0.66.2-1 and /usr/bin/lazygit, reporting version
0.66.2. No package database refresh, system upgrade, Neovim plugin installation
or binding change was performed for this addition. Task 3 must include Lazygit's
official dependency and portable native configuration under the editor owner,
with ownership/context tests, installed-code delivery and attribution.

The authorized host reference was only ~/.config/lazygit/config.yml; state.yml
was not read or copied. Supported reference choices are Nerd Fonts version 3
and selected-line background #1f212e. The legacy selectedRangeBgColor and
git.paging options are absent from the current native documented fields and
are not copied as inert settings. The personal Chrome profile opener is not
portable and is excluded; native link opening remains the application default,
not a new browser dependency or a claim of tested browser integration.

The separately authorized bounded host Git inspection used --no-includes and
an allowlist of pager/diff/color keys. The only matching value was color.ui=auto;
no include directives or relevant environment overrides were found. Delta 0.18.2
was installed on the host but not selected as its Git pager. Therefore the
candidate retains standard Git diff rendering and does not install Delta.
Git identities, credentials, remotes, histories and unrelated config values
were not retained.

On resume, guest ~/.config/lazygit/config.yml existed as a regular empty file
(mode 0644), unlike the prior absent-path observation. It was left unchanged;
its creator is not inferred. No active Lazygit configuration was installed.
The separate candidate contains only:

```yaml
gui:
  nerdFontsVersion: "3"
  theme:
    selectedLineBgColor:
      - "#1f212e"
```

Record: ~/.local/state/mirroros-lab/workbench-prototype/lazygit-check.mwjypP8W/.
Files: lazygit.yml, check-lazygit.sh, test-only.yml, native-startup.log and
native-startup.exit. The synthetic test ran as the guest user under env -i,
with a new HOME/config/tmp directory, no inherited credentials or SSH agent,
Git system/global configuration disabled, and a fresh repository without remotes.
A test-only overlay disables auto-fetch, branch forwarding, update checks and
introductory popups; these are fixture restrictions, not additional product
policy decisions. The PTY is 120x40, TERM=xterm-256color. After three seconds the
fixture sends only q, with a 12-second timeout.

```bash
bash -n check-lazygit.sh
shellcheck check-lazygit.sh
env -i PATH=/usr/bin:/bin /usr/bin/bash --noprofile --norc \
  "$record/check-lazygit.sh" "$record"
```

The fixture requires a fresh record directory containing the script/candidate;
it intentionally refuses reusing its populated directories. Both static checks
pass, native startup/quit returns 0, and the synthetic log contains none of the
checked YAML/unmarshal/panic/fatal diagnostics. This is native loading evidence,
not graphical acceptance, complete schema validation or a link-opening test.
Do not treat lazygit --config (default-config output) as validation of user input.

Before activation, obtain approval to replace only the existing empty config
with the candidate, refusing changed or symlinked destinations. Then ask the
maintainer to check <leader>G, glyphs, selection and standard diffs and quit
without commits, staging, resets or publication. No attended Lazygit verdict
has yet been recorded. Keep real ~/.pi and all existing guest work unchanged.

References: installed /usr/share/doc/lazygit/Config.md and the versioned upstream
https://github.com/jesseduffield/lazygit/blob/v0.66.2/docs/Config.md and
https://github.com/jesseduffield/lazygit/blob/v0.66.2/pkg/config/user_config.go.
Lazygit is MIT-licensed; the installed notice is
/usr/share/licenses/lazygit/LICENSE. Native product ownership and final source/
evidence scanning remain subsequent work, not implied by the fixture exit code.

### Lazygit managed activation: subsequent attended decision

The maintainer accepted the preceding incremental work and reported that
Lazygit opens successfully from Neovim using Ctrl+G. Record this key as reported;
the earlier inspected source mapping was <leader>G. No binding was changed or
new source mapping inferred from this report. This confirms launch integration,
not a separate appearance or browser-opening verdict.

The maintainer then explicitly authorized applying the same native managed-header
policy used by other eligible MirrorOS defaults. The candidate now starts with
`# managed by MirrorOS configure`; YAML supports this comment without changing
its native settings. The approved payload is recorded separately as
lazygit-check.mwjypP8W/lazygit-managed.yml, retaining the originally tested
headerless candidate as historical input.

Activation checked that ~/.config and its lazygit directory were real directories,
and config.yml was still a regular empty file. A same-filesystem temporary file
was written and flushed as the guest user with the original 0644 mode. Before
replacement, destination type, empty size, inode/device and modification time
were checked again. Atomic rename published the candidate and byte equality
verified the final contents. The original empty file had no payload to preserve;
no state.yml, host file, Neovim configuration or real Pi directory was touched.

The header denotes MirrorOS management under the existing native-file policy;
it is not a license header, privilege mechanism or a new adoption framework.
Future product configure must preserve unmarked files and symlinks and test
owned-file rerun behavior. This explicit prototype activation does not authorize
adopting other unmarked user files or changing initialize-only ~/.pi policy.
The native PTY test covered the same settings before addition of the YAML comment;
no post-activation graphical appearance verdict is yet recorded. Task 1 remains
in progress, with its overall review and Task 2 gate still pending.

### Authorized isolated Resurrect/Continuum restoration fixture

After accepting Lazygit activation, the maintainer explicitly authorized an
isolated disposable-session test. Record:
~/.local/state/mirroros-lab/workbench-prototype/tmux-restore.c680xpUi/.
The source plugin checkouts were clean at Resurrect
cff343cf9e81983d3da0c8562b01616f12e8d548 and Continuum
0698e8f4b17d6454c71bf5212895ec055c578da0. No plugin was installed or updated.

check-restoration.sh passes bash -n and ShellCheck. Its sole SC2009 exception
retains upstream's exact ps/grep multiple-server detection, rather than changing
the guard to manufacture a pass. Execution used env -i, a fresh HOME/data/state
area and a unique socket. A test-only tmux wrapper always selects that socket;
no default socket is used. Shell panes run Bash --noprofile --norc with synthetic
HOME and HISTFILE=/dev/null. No host or guest personal session content is captured.
Pane-content capture and process replay are explicitly disabled. The fixture
never sources Continuum's boot/service entrypoint or invokes service helpers.

The test registers native Resurrect bindings/script paths, then creates a keeper
session and workbench-fixture with two windows (code/checks), three panes and
explicit synthetic a/b working directories. It forces the native Continuum
save script's timestamp due, checks its updated timestamp and saved-state
completion, and removes only the named synthetic workbench session. Native
Resurrect restore recovers the same window names, indices, pane counts/indices
and paths. A repeated restore preserves that topology without duplicate panes.
Removing the synthetic workbench session again and invoking native Continuum
restore also recovers the same topology. The upstream multiple-server guard
was not bypassed or mocked and did not inhibit this observed run.

```bash
bash -n check-restoration.sh
shellcheck check-restoration.sh
env -i PATH=/usr/bin:/bin /usr/bin/bash --noprofile --norc \
  "$record/check-restoration.sh" "$record" "$HOME/.config/tmux/plugins"
```

Like the Lazygit fixture, this requires a new record directory containing the
script. results.txt and before.tsv/after.tsv/repeated.tsv/automatic.tsv record
synthetic postconditions. continuum-save.log, manual-restore.log,
repeated-restore.log and continuum-restore.log retain original diagnostics.
The EXIT trap stops only the owned socket/server; a subsequent read-only check
confirmed it is stopped. No personal Tmux server was restarted or terminated.

Important limitations and discovered prerequisite:
- Resurrect helpers invoke hostname even with an explicit state directory.
  The guest lacks that executable and inetutils is not installed. Official
  core metadata offers inetutils 2.8-1 (GPL-3.0-or-later). This must be resolved
  through separately authorized installation and a rerun; do not hide the warning
  behind the successful topology comparisons or declare dependencies complete.
- The detached fixture emits no-current-client and initial session-0 diagnostics.
  It does not validate attached-client focus, active/alternate session selection,
  exact pane geometry, arbitrary process/editor restoration or personal state.
- An asynchronous plugin helper also reported no server after owned cleanup;
  this is retained, not silently removed from the synthetic diagnostic log.
- Directly invoking the native Continuum scripts proves their save/restore
  integration with Resurrect, not first-login/boot plugin activation, periodic
  status-line scheduling or full graphical acceptance. No service was started.

Task 1 remains in progress. Resolve hostname and remaining preparation checks;
Task 2 still owns the blocking prototype/provider/performance acceptance.

### Attended inetutils installation and restoration rerun

The maintainer accepted the initial fixture results and, after an explanation
of Resurrect's hostname usage, explicitly authorized installing inetutils and
rerunning the isolated test. An assistant sudo -n attempt stopped at password
requirement before pacman ran. The maintainer then privately completed:

```bash
sudo pacman -S --needed inetutils
```

Subsequent read-only checks confirm inetutils 2.8-1 and /usr/bin/hostname.
No repository refresh or service start was requested by this installation.
Task 3 must declare inetutils under the Tmux dependency owner; it supplies the
upstream plugin's hostname command without a local plugin patch or command shim.

Rerun record:
~/.local/state/mirroros-lab/workbench-prototype/tmux-restore.q7FPkTmE/.
The unchanged check-restoration.sh was copied into a fresh record and executed
with the same env -i isolation and original installed plugin scripts. Native
Continuum save/timestamp, Resurrect topology/path restoration, repeated restore
without duplicate panes, and native Continuum restore all pass again. The logs
contain no hostname or other command-not-found diagnostics. The owned server
was stopped and that cleanup was independently checked.

Original detached-fixture diagnostics remain: no current client, initial missing
session 0, and an asynchronous helper reporting the stopped socket after cleanup.
These are retained in allowlisted logs rather than suppressed. Attached focus,
exact geometry, editor/process replay, periodic scheduling and startup integration
remain outside this fixture's evidence. The missing hostname prerequisite is
resolved; the overall Task 1 review and blocking Task 2 gate are not complete.

### Authorized fresh editor-tool and parser preparation

The maintainer explicitly authorized a real fresh preparation test, including
network downloads and tool installers, in disposable guest directories without
replacing the daily editor installation or updating plugins beyond the lockfile.
Record: ~/.local/state/mirroros-lab/workbench-prototype/editor-fresh.aBQlkyKU/.
The test completed with overall.exit 0; no installer repair, dependency fallback,
plugin revision change, source amendment, privileged package installation or
publication was required.

Preparation copied the 81 regular tracked/untracked configuration source files
from the reviewed guest Neovim branch, rejecting symlinks and nonregular paths.
It did not copy .git, ignored runtime data, installed tools, credentials or user
editor state. source-manifest.json records per-file SHA256 values. The disabled
local-development plugin remained disabled; no missing local plugin was adopted.
The source checkout remains based on
654973fa0a5e3d5b15e782f8fe449ac347df014f with its previously reviewed dirty changes.

Isolation used env -i, fresh HOME and XDG config/data/state/cache directories,
separate empty npm user/global config files, an npm prefix/cache inside the new
HOME, fresh Go build/module caches and temporary directory, no SSH agent or
private Git configuration/credential helpers, and no terminal Git prompts.
The selected real Node v24.22.0 bin directory was explicit on PATH; NVM startup
was not sourced. Required system build tools were reused, not copied into source.
All installation operations ran as the guest user. No Pi process or provider
conversation was launched by this fixture.

check-fresh-editor.sh passes bash -n and ShellCheck. Its recorded sequence is:

```bash
# Run from the isolated copy, with the fixture's environment and npm prefix.
nvim --headless -u NONE -l tests/prepare-tools.test.lua
nvim --headless -u NONE -l tests/treesitter-preparation.test.lua
nvim --headless '+Lazy! restore' +qa
nvim --headless -c "luafile $record/check-locked-plugins.lua" -c qa
nvim --headless -c "lua require('config.prepare_tools').run()" -c qa
nvim --headless -c "lua require('config.treesitter').run()" -c qa
# Repeat both preparation commands, compare receipts, then run integration checks.
nvim --headless -c 'luafile tests/treesitter.test.lua' -c qa
```

Each phase has its own .log/.exit and an outer 45-minute timeout; the existing
preparers retain their 15-minute per-operation bounds. The lab runner is a
bounded validation artifact, not a new product provisioning framework. Reusing
its populated record does not exercise a fresh installation; create a new isolated
source copy and empty HOME for a fresh test.

Results:
- 15 tool contracts and 11 parser-preparation contracts pass with mocked effects.
- Real plugin installation/restoration succeeds. Native validation checks all
  45 selected plugin HEAD commits against lazy-lock.json, including lazy.nvim;
  every directory is inside the isolated plugin root. The lockfile is unchanged.
- First real preparation installs all 14 Mason tools declared by the authoritative
  prepare_tools module and npm vscode-langservers-extracted 4.10.0. No parallel
  MirrorOS desired-tool list was introduced.
- All 17 declared parsers install and pass revision-receipt, loadability and
  highlight-query postconditions from the authoritative treesitter module.
- The second tool run reports preservation of JSON and all 14 Mason tools.
  Parser preparation succeeds again; sorted hashes of all Mason receipts,
  parser revision receipts, JSON package metadata and the lockfile match exactly
  between runs. This is unchanged-receipt evidence, not a complete filesystem
  mutation audit or proof that no caches/logs were written.
- All 24 normal-configuration Treesitter integration checks pass, covering
  native selection history, textobjects/navigation/swap, Markdown injections,
  Emmet and parserless buffers. They do not replace attended graphical checks.
- All 81 original source files still match source-manifest.json afterward.
  The original lockfile SHA256 remains
  315d619d448a5a784619ec18edb16c495bc22625efa2513c0a34fc2c8fc6539c.
  All three guest tracked-source git diff --check commands pass, with the
  original branch dirty/untracked sets unchanged.

Consumed Mason identities are recorded in tool-identities.json, extracted only
from the newly installed public-source receipts. All reference registry
mason-org/mason-registry 2026-10-19-gaudy-tope, whose recorded registry.json
SHA256 is 6dcae2e5aa6275d2ce66f5069f14e88959ddf0dc6daa7c2af0cc14920a81af00
and registry.json.zip SHA256 is
f75d196f79b2fa00fb331687a12cfd7697d2ef02121b79f42e15ffb4545e7f72.
These are receipt provenance, not an additional upstream signature claim.
The consumed tool versions are goimports v0.52.0, golangci-lint v2.15.0,
gopls v0.23.0, js-debug-adapter v1.140.0, lua-language-server 3.19.2,
prettier 3.9.10, shfmt v3.14.1, stylelint 17.16.0, stylua v2.6.0,
tailwindcss-language-server 0.16.0, terraform-ls v0.39.0, tflint v0.64.0,
typescript-language-server 6.0.2 and vtsls 0.3.0. This list records the run;
it is neither a second desired-tool declaration nor permanent version freezing.
Npm installation alone does not pin all transitive dependencies.
Parser revisions are recorded by the 17 ready-parser lines in parsers-first.log
and matching receipt hashes; the locked Treesitter plugin owns that manifest.

Retain only allowlisted scripts, source identities/manifests, phase logs/statuses,
lock checks, receipt hashes and tool-identities.json as evidence. Never retain
the entire synthetic HOME, downloaded archives, node_modules, plugin clones or
Go caches as acceptance artifacts. No private authentication data was needed.
This resolves the previously untested fresh-preparation entrypoint; interrupted
real installer recovery, product configure integration, upstream publication and
separate-VM reconstruction remain subsequent work. Task 1 overall review and
Task 2 acceptance are still pending.

## Consolidated dependency and notice map for candidate review

This section consolidates the prototype inputs, not shipped configure declarations
or a full transitive license audit. Full consumed commits are in source-map.tsv;
selected installed Arch versions are in package-list.txt. Official package license
labels below were read from the guest's installed pacman metadata without a
package transaction. Pacman owns their transitive dependencies and packaged
notices; do not copy system libraries or replace their license grants.

| Proposed product responsibility | Direct prerequisites / consumed sources | Notice and delivery boundary |
| --- | --- | --- |
| Terminal | foot; ttf-jetbrains-mono-nerd; noto-fonts-emoji | Arch metadata: MIT; OFL-1.1-no-RFN for both fonts. Foot palette derives from Folke Lemaitre's Tokyo Night; retain its source attribution and applicable notices. |
| Node runtime | git, curl, tar, gzip; official nvm v0.40.8 and Node v24.22.0 | NVM LICENSE.md at the consumed commit is MIT, copyright Tim Caswell (2010) and Jordan Harband (2014). Keep downloaded NVM/Node notices; neither becomes MirrorOS-owned code. Versioned installer identity/options are recorded above. |
| Interactive shell | zsh, starship, fzf, zoxide, atuin, fd, bat, tree, ripgrep; Zplug and five selected plugin sources | Arch labels: Zsh custom; Starship ISC; Fzf/Zoxide/Atuin MIT; fd MIT OR Apache-2.0; bat Apache-2.0 OR MIT; tree GPL-2.0-or-later; ripgrep MIT OR Unlicense. Zplug/plugin notices below remain upstream-owned. No terminal-start installation/network work. |
| Tmux | tmux, wl-clipboard, inetutils, fzf; TPM and seven selected plugins | Arch labels: BSD, GPL-3.0-or-later, GPL-3.0-or-later, MIT respectively. Rust/Cargo builds tmux-thumbs; retain upstream sources/notices. Sesh remains conditional, not an official-package claim. |
| Editor prerequisites | installation-owned neovim; lazygit, tree-sitter-cli, unzip, git, base-devel, Go, selected user Node | Neovim labels Apache-2.0 and LicenseRef-vim; Lazygit/tree-sitter-cli MIT; unzip custom; Git GPL-2.0-only; Go BSD-3-Clause. Build prerequisites include make/GCC and Cargo from rust; use official package dependencies, not duplicate capability declarations. |
| Editor configuration / tools | complete external nvim-lua-new, lazy-lock.json, config.prepare_tools and config.treesitter | External repo remains authoritative for plugins, 14 Mason tools, npm JSON provider and 17 parsers. Lockfile, fresh-run source manifest and receipts record consumed inputs. Preserve each downloaded project's own notices; no blanket MirrorOS relicensing or second desired-tool list. Guest source amendments require separately authorized publication before product consumption. |
| Pi executable / external resources | selected pi-config revision, exact Pi 1.3.0, npm --ignore-scripts | Observed dependency/runtime match is not historical installer provenance, configure-selection proof, compatibility repair or transitive pinning. Preserve npm/external repository notices; incoming pi-config lockfile dependencies have not been reconciled after the authorized pull. |
| Pi npm resources | six packages listed below; ffmpeg for the approved capture prerequisite | All six selected npm registry manifests declare MIT. This does not audit their dependency trees or license models. Arch ffmpeg metadata is GPL-3.0-only. Voice/TTS stay disabled; no model payload or authentication is distributed. |
| External manual skills | current resolved teach, wait-what, show-me and archify through skills CLI | Download upstream, preserve notices/support files and amend only disable-model-invocation. Do not vendor these trees into MirrorOS or ISO contents. Archify code/third-party artwork terms remain distinct; upstream installation does not relicense them. Isolated install/loader checks passed; active replacement remains unauthorized. |
| Two owned skills | reviewed aikido-mcp and atlassian-mcp snapshots | Maintainer-authored and expressly authorized under the project's GPL-3.0-only policy. Proposed durable packaging is below; no private mcporter/account configuration is included. |
| Optional private Vertex setup | user-local Google Cloud CLI 589.0.0 and exported environment references | Exact official archive/object verification is recorded above. Preserve Google's bundled notices/terms; no claim that the SDK is covered by the MirrorOS license. Product owner/delivery details need candidate review. Authentication and project identifiers remain private inputs. |
| Repository checks | shellcheck, bats, jq; host-side gitleaks for allowlisted artifacts | Installed Arch labels: GPL, MIT, MIT respectively. Gitleaks results here cover selected staged records only, not the final repository/negative-control/clean-clone gate. |

### Reviewed upstream shell and Tmux notices

Read-only git show of notice files at the consumed local HEADs established:

| Source | Notice at consumed commit |
| --- | --- |
| zplug | LICENSE: MIT; Masaki Ishiyama, 2016-present. |
| jeffreytse/zsh-vi-mode | LICENSE: MIT; Jeffrey Tse, 2020. |
| zsh-users/zsh-syntax-highlighting | COPYING.md: BSD-3-Clause terms; contributors, 2010-2020. |
| zsh-users/zsh-autosuggestions | LICENSE: MIT; Thiago de Arruda, 2013; Eric Freese, 2016-2021. |
| zsh-users/zsh-completions | LICENSE: Zsh license with individual-file precedence; do not relabel as MIT. |
| ohmyzsh/ohmyzsh lib/completion | LICENSE.txt: MIT; Robby Russell and contributors, 2009-2026. |
| tpm, tmux-sensible, tmux-resurrect, tmux-continuum | LICENSE.md: MIT; Bruno Sutic; retain each original notice/year. |
| tmux-yank | LICENSE.md: MIT; Bruno Sutic, 2014/2017; Christian Hoeltje, 2017 (retain the source spelling). |
| tmux-thumbs | LICENSE: MIT; Ferran Basora, 2019. |
| tmux-fzf | LICENSE: MIT; Sainnhepark, 2019. |
| tmux-fzf-url | LICENSE.txt points to https://wfxr.mit-license.org/2018; the referenced notice declares MIT, Wenxuan Zhang, 2018-2026. Preserve the pointer and full applicable notice when packaging copied material. |
| Sesh candidate | LICENSE: MIT; Josh Medeski, 2023. Go builds the consumed source; /usr/local/bin/sesh is prototype installation, not an approved product recipe. |

Additional derived native content needs co-located notices in Task 3:
- Zsh history options: Prezto LICENSE, Robby Russell/contributors 2009-2011 and
  Sorin Ionescu/contributors 2011-2017; upstream MIT text reviewed at
  https://raw.githubusercontent.com/sorin-ionescu/prezto/master/LICENSE.
- Neovim-aware navigation: vim-tmux-navigator License.md declares MIT,
  copyright Chris Toomey, 2017; reviewed public license blob
  046c81da30206ea9c71b1ffc5ed56e6727c62567 via
  https://api.github.com/repos/christoomey/vim-tmux-navigator/license.
  Retain the full notice when incorporating the adapted bindings; this is not
  an assertion that the full plugin is installed in the guest.
- Tmux status layout: retained omerxx/catppuccin-tmux checkout at
  e30336b79986e87b1f99e6bd9ec83cffd1da2017 has LICENSE declaring MIT,
  copyright Catppuccin, 2021. Preserve that notice for adapted layout material;
  the old plugin is not loaded by the candidate.
- Tokyo Night: native candidates identify the translated extras as MIT. The
  reviewed v4.11.0 Kitty extra itself explicitly says MIT, whereas that tag's
  repository LICENSE is Apache-2.0. Record both scopes rather than replacing
  per-file terms with the root license or claiming all upstream code is MIT.
  Reference https://github.com/folke/tokyonight.nvim/tree/v4.11.0. This is a notice
  comparison, not proof of the original host palette's import revision: current
  bright colors differ from that reference. Preserve the approved native colors;
  exact provenance/notice packaging must be reviewed before product promotion.

No license text was inserted into active native configuration or upstream files
by this review. Packaging full notices and updating docs/attribution.md remain
co-located Task 3 work, after the candidate review, not a claim of shipped notices.

### Pi resource registry declarations

Read-only version-specific public npm metadata reports these declarations:

| Package/version | Declared license | Repository |
| --- | --- | --- |
| @codexstar/pi-listen 7.2.2 | MIT | https://github.com/codexstar69/pi-listen |
| pi-mermaid 0.3.0 | MIT | https://github.com/Gurpartap/pi-mermaid |
| pi-extension-manager 0.8.2 | MIT | https://github.com/victor-software-house/pi-extension-manager |
| pi-resource-center 0.3.1 | MIT | https://github.com/sodie2323/pi-resource-center |
| pi-sub-anthropic 0.1.10 | MIT | https://github.com/spksoft/pi-sub-anthropic |
| pi-web-access 0.41.0 | MIT | https://github.com/nicobailon/pi-web-access |

Metadata URLs are https://registry.npmjs.org/<package>/<version> (including the
@codexstar scope). These observations do not reinstall or inspect packages inside
existing ~/.pi. Keep the configured extension-manager disable filter and other
resource selection unchanged. Disabled voice/TTS do not authorize model download,
recording, browser opening or authentication merely to check dependency presence.

### Proposed durable packaging for the two authored skills

This is a Task 2 review input, not an implemented destination policy or permission
to activate/replace skills. Limit owned source to exactly these verified payloads
from pi-skills-snapshot.3lr491yo/snapshot-manifest.json:

| Relative path | SHA256 |
| --- | --- |
| aikido-mcp/README.md | e91628ab05d758ae7f4eb9434dda2b6af2e9507f562ba81519a094998da427ba |
| aikido-mcp/SKILL.md | 6900d5436d1aa1e57b7b60b0f8b3f1813556eff1e77ddaabe4b6081847fc6f9b |
| atlassian-mcp/SKILL.md | 7cc7c7d4de1ba934eeecc53527750f7b8cc93704f4613c8bafdc596dfb9bac03 |

Proposed source ownership is capabilities/workflow/pi/skills/<name>/, with
sources.md recording maintainer authorship, explicit GPL-3.0-only authorization,
snapshot hashes and any later deliberate amendments. Retain original payload
bytes until an amendment is separately reviewed. Use a supplemental notice for
formats where inserting a managed header would alter frontmatter semantics.

For fresh Pi setup, propose a stable user-owned generation outside ~/.pi, under
~/.local/share/mirroros/pi/skills/, with validated resource links published only
as part of successful initial Pi initialization. Never use a temporary lab record
as the product destination. Refuse symlink/nonregular/unrelated destinations;
verify regular allowlisted contents and avoid overwriting a concurrently created
path. Any owned staging cleanup must prove ownership and stay inside its scope.

An existing ~/.pi means no replacement of its links or mutation of their active
owned-skill targets by this delivery. How to expose new owned-skill defaults after
initialization is a manual backup/reset decision, not hidden ongoing convergence.
External pi-config clone synchronization remains the separate accepted policy.
Tests must cover missing/satisfied/conflicting destinations, interrupted staging,
concurrent creation and byte preservation of existing active targets. No generic
skill manager or private MCP bootstrap is proposed. Four upstream skills keep the
separate current-source CLI policy; update/rerun ownership needs explicit review.

## Final Task 1 source/PATH verification continuation

Read-only checks confirmed the three guest branch bases and dirty/untracked sets
recorded in the handoff; all three tracked git diff --check commands pass. With
an explicit provisioning PATH (no nvm_load or shell-startup sourcing):

```bash
export PATH="$HOME/.local/bin:$HOME/.nvm/versions/node/v24.22.0/bin:/usr/local/bin:/usr/bin:/bin"
for tool in node npm pi nvim zsh tmux sesh pi-editor gcloud ffmpeg fzf zoxide atuin fd bat rg wl-copy lazygit hostname; do
  command -v "$tool"
done
node --version
npm --version
for file in zshenv zshrc zprofile environment.zsh; do
  zsh -n "$HOME/.local/state/mirroros-lab/workbench-prototype/$file"
done
foot --check-config --config="$HOME/.config/foot/foot.ini"
```

All listed executables resolve; Node v24.22.0, npm 11.19.1, Neovim 0.12.6,
Zsh 5.9.2, Tmux 3.8 and Lazygit 0.66.2 were observed. Public installed Pi package
metadata reports 1.3.0, equal to the resolved pi-config root exact dependency.
No real Pi process/session or dependency install was needed for that comparison.
All four candidate Zsh syntax checks pass. Native Foot validation exits zero;
SSH's C locale produced a fallback-to-C.UTF-8 warning, not a configuration error.
No Floax/Sessionx @plugin declaration exists in the candidate Tmux configuration.

Candidate zshenv/zshrc/zprofile/environment.zsh and all four Tmux files match
active guest files byte-for-byte. The top-level Foot candidate was stale: it
still had pad=4x4 and omitted the previously approved term=foot, centered 16x16
padding, scrollback/cursor and CSI-u bindings. Only that prototype candidate was
synchronized to the already active, validated regular Foot file; active
configuration was preserved. The matching candidate/active SHA256 is
49dff77d5620ca1c17b7bd3dc6bd6579eafae27ae9f0e25fe459b25e01289c35.

This continuation does not replay accepted fresh-editor/restoration installations,
activate skills, touch existing ~/.pi or publish external branches. Detached
Continuum tests do not prove boot/periodic status scheduling; graphical outcomes,
Sesh product delivery and a numerical startup criterion still require the blocking
Task 2 review. Host product/application checkouts and private state are protected;
the historical explicitly authorized single auth-file transfer remains a recorded
exception, not renewed permission or a claim that credentials were never copied.

## Task 2 candidate review and approved delivery decisions

This addendum supersedes earlier pending candidate and threshold statements.
Task 1 received overall A acceptance in the execution log. The maintainer then
explicitly accepted the demonstrated functional candidate and source/resource
map as the implementation reference, not as completed product/reconstruction
acceptance. No downstream task has been applied by this review.

### Accepted performance criterion

Using the same documented guest PTY method and resources, preserve every required
shell feature and require no perceived blocking, with these numerical limits:

| Measure | Observed complete configuration | Accepted maximum |
| --- | --- | --- |
| Subsequent-start median | 237.446 ms | 300 ms |
| First observation | 455.894 ms | 700 ms |
| First-command-response median | 33.869 ms | 50 ms |

These are not Foot launch/render times, cold-boot measurements, universal hardware
guarantees or a measured host-relative improvement.

### Sesh delivery

The maintainer accepted Sesh functionally and approved the following packaging
approach. The official Arch exact-name query returned no sesh package; AUR offers
sesh-bin 2.33.0-1. Review consumed PKGBUILD revision
`e2965e02ffbbb63fc2af817456c4fde99a843f8c` from
https://aur.archlinux.org/cgit/aur.git/plain/PKGBUILD?h=sesh-bin&id=e2965e02ffbbb63fc2af817456c4fde99a843f8c.
Its x86_64 release-archive SHA256 is
`e04fe35778eaf768a1fbbaa6e01d008ae22038c52b8d7834d38c9e7ad4822daa`,
matching the upstream release asset digest. The recipe incorrectly repeats this
checksum for other architectures and does not explicitly install the license.
Task 3 must produce an attributed reviewed derivative restricted to x86_64,
include applicable license material, build/package unprivileged and install only
through the privileged package effect boundary. Do not source floating AUR code,
use yay or introduce an automatic AUR updater. Updates are explicit MirrorOS
changes; actual archive/package validation is still required before installation.

Upstream v2.33.0 points to `863935c8caa3cc40cac6adcd344ac9742e51739f`,
not the tested prototype commit `ac21f7f832e3e3270d4ba365a29041e070964159`
(which reports version dev). Recheck selection, creation, cancellation and
restoration coexistence with the packaged candidate before accepting its delivery.
No package build, install or functional equivalence is claimed by this review.

### Google Cloud CLI delivery

The maintainer approved workflow/pi ownership of the official versioned 589.0.0
user-local archive installation described above. Add a bounded installer and
contract tests in Task 3, with explicit source identity, the recorded local
SHA256 and original official size/MD5 provenance; do not mislabel that SHA256 as
an independently published upstream checksum. Preserve unrelated installations.
Use ~/.local/opt/google-cloud-sdk-589.0.0 and ~/.local/bin/gcloud without profile
editing, automatic authentication or component updates. Version changes require
an explicit MirrorOS change. No general SDK manager, private account identifiers,
credential distribution or host runtime update is authorized.

### Skills and notice packaging

Package exactly the two authored skill snapshots under the previously approved
project license. Download teach, wait-what, show-me and archify from once-resolved
upstream sources through the reviewed CLI path during fresh initialization only;
retain their notices and set manual-only invocation. Do not embed the four
external trees in MirrorOS source or ISO contents. With existing ~/.pi, preserve
its directory and active skill targets; do not automatically refresh these skills.
New defaults require an explicit documented manual backup/reset. The earlier
owned-skill source/destination proposal is accepted subject to its conflict,
staging, concurrency and preservation checks; no active transition occurred here.

Task 3 must co-locate source attribution and applicable full notices, including
derived native content, and update docs/attribution.md. Unresolved provenance or
license scope remains a blocker, not implicit redistribution permission.

### Host Neovim preservation and external publication

The maintainer explicitly authorized and incrementally accepted creation and
selection of local host branch host/pre-workbench in ~/.config/nvim at
`654973fa0a5e3d5b15e782f8fe449ac347df014f`. Before and after, the checkout
was clean and HEAD unchanged. This is a narrow approved host Git-metadata
exception: tracked files, plugins, tools and runtime were not updated. No push or
remote backup was requested. A local branch does not freeze external plugin/tool
state; avoid host pull/plugin updates until a separately authorized migration.

Guest Neovim and pi-config changes remain on their reviewed development branches.
Present their diffs and tests before requesting separate commit/push authorization;
product consumption must use approved published normal-branch revisions. No
analogous preservation branch is required for pi-config. No publication or host
migration is authorized by these decisions.

### Gate and documentation boundaries

Task 2's overall A/B review remains pending. The packaged Sesh recheck, source
notice delivery, published external revisions, product contracts, both configure
contexts, separate-VM reconstruction and final attended acceptance remain
explicit implementation/verification prerequisites, not passed observations.

The guest interview addenda are workflow inputs under
~/.local/state/mirroros-lab/workbench-inputs/, not copied product runtime files.
They record the approved Task 3 scope additions (gcloud installer/tests, skills,
Lazygit and Compose ownership) without modifying the host MirrorOS checkout.
Historical host-source and single credential-transfer exceptions remain recorded;
none is renewed by this gate. No private Pi directory was inspected or modified
while recording these decisions.

## Task 3 product integration: partial source delivery

Task 2 subsequently received overall maintainer acceptance. Product integration
remains in progress; neither reconstruction nor final workbench acceptance is
complete. Earlier pending prototype/publication statements are historical.

The reviewed Neovim changes were published to normal `master` as
`bdf02dd9b726c215c31d3a64c6cb38e56bbdac58`; reviewed pi-config editor changes were
published to normal `master` as `37ae549ae4de603ab0b9535e9a13187c9d257a26`.
Each host-side temporary-clone commit and push had separate explicit approval.
The host Neovim checkout remains on `host/pre-workbench`. A separately authorized
host pi-config fast-forward preserved its three untracked workflow documents;
this is an explicit host-update exception, not permission for other host changes.
Dirty guest prototype branches remain preserved, not reset or silently adopted.

### Accepted mechanism block

The guest MirrorOS checkout now contains the built-in-only Pi version selector,
its exact/absent/invalid selection contracts, safe context/user-aware external
repository helper, public source provenance records and associated helper-loader
and documentation changes. The maintainer accepted this partial block, not all
of Task 3. Completed guest checks comprised 42 selector cases, 55 capability
contracts, 64 operation contracts and 55 installer apply contracts. Changed Bash
passed syntax and ShellCheck checks. The first combined test invocation exceeded
the tool timeout; no lost completion status was counted as passing. A separate
installer attempt lacked Node on SSH PATH, then passed after explicitly adding
`$HOME/.nvm/versions/node/v24.22.0/bin`, without loading NVM or startup files.

### Native terminal, Compose and editor input block

The terminal source translates the MIT-declared Tokyo Night Kitty extra to the
approved Foot values, with fixed source comparison, full MIT text and explicit
bright-color adaptations in `capabilities/desktop/terminal/sources.md`. Font Mono
14, centered 16x16 padding, `term=foot` and CSI-u bindings retain the approved
candidate's functional bytes. `noto-fonts-emoji` belongs to the terminal owner.
This is not global visual coherence or a historical host-import revision claim.

Session and greeter source declare `compose:ralt` while retaining the shared
layout resolver. Native user-owned overrides can retain AltGr; see the configure
procedure. Contract delivery checks do not establish graphical greeter behavior
or coverage of every layout. No live compositor reload/restart is part of this
source change.

The editor owner contains only the approved portable Lazygit native input and
its provenance at this point. Its full apply step, official dependency delivery,
external Neovim synchronization and explicit tool preparation still need wiring.
No prototype runtime, package manager, private Pi directory or external source
checkout is mutated by these source-only integration checks.

### Remaining integration and verification

The step sequence is still the walking skeleton. Node/NVM, complete Zsh/Tmux,
editor/Pi provisioning, initialize-only Pi resources/skills, Google Cloud CLI and
reviewed Sesh package delivery remain implementation work. Do not apply a partial
checkout as evidence of the complete workbench. Actual running/target configure,
unchanged-input reruns, source/evidence validation and separate-VM reconstruction
remain downstream requirements, followed by final attended acceptance.

## Task 3 continuation: Node.js runtime block

Applied to the guest checkout after Task 2 acceptance; not terminal Task 3 acceptance.

- `workflow/node` is now the second configure step (before shell). It declares `git`, installs the managed
  `~/.config/mirroros/node/environment.zsh` (the single `MIRROROS_NODE_VERSION` declaration, v24.22.0) and runs
  `install-nvm` as the target user through the new `cfg_user_script` helper.
- NVM v0.40.8 (tag object 8db529c5350353f165e1e7f6abb6eb6909f7fd37, commit
  a885b885fef16fac4bc544188fb25e9e37ae83e8) is installed from the versioned installer with SHA-256
  48a0eee9a60e07422dce0eb5774754c83889570ca1ee2566c516acbe8af03a9e, `PROFILE=/dev/null` and
  `NVM_INSTALL_VERSION=v0.40.8`. The checksum is verified before execution, the tree is built in owned staging,
  its commit is verified, and `~/.nvm` is published only if still absent.
- An existing unrelated or modified `~/.nvm` is preserved. It is accepted only when the declared Node.js is already
  present; otherwise the step fails with an actionable message. Satisfied runtimes cause no download.
- Source and Node identities are recorded in `sources.tsv`. NVM and Node.js are downloaded, not incorporated, so no
  attribution index entry is added; `workflow/node/sources.md` carries the notices boundary.
- Verification (guest, explicit Node PATH, no `nvm_load`): `bats tests/capabilities` 71, `bats tests/operations` 64,
  `bats tests/install/engine/apply.contract.bats` 55, `node --test tests/capabilities/pi-version.test.mjs` 42;
  `bash -n`, ShellCheck, `zsh -n` and `git diff --check` clean; limited allowlisted gitleaks scan zero findings.
  The real `install-nvm check` and satisfied `apply` against the existing guest NVM/Node reported
  `unchanged v0.40.8 a885b885fef16fac4bc544188fb25e9e37ae83e8` and changed nothing. A real fresh installation of
  NVM/Node through configure has NOT been run; contracts use command doubles. That belongs to Task 4.
- Remaining Task 3 owners: complete Zsh, Tmux, editor, Pi, gcloud, Sesh, skills, and full-order validation.

## Task 3 continuation: Zsh block

Applied to the guest checkout; not terminal Task 3 acceptance.

- `workflow/shell` now installs the approved `zshenv`, `zshrc` and `zprofile` (managed-file policy), declares
  `zsh fzf zoxide atuin fd bat tree ripgrep` (extra) and `python` (core), runs `install-plugins` as the user and
  sets Zsh as the login shell only when it is currently Bash (`cfg_login_shell`, `usermod`, `/etc/shells` check).
  `usermod` joins the validated base tools. The Bash Starship block is kept.
- `install-plugins` clones Zplug and the plugin sources at identified commits (source-map identities) into
  run-owned staging and publishes without overwriting; existing clones of the expected origin are accepted at the
  user's commit, anything else is preserved. Startup never installs or fetches.
- At maintainer request the host's `plugins/git` and `plugins/common-aliases` (from the identified oh-my-zsh clone)
  and `djui/alias-tips` (commit 41cb143ccc3b8cc444bf20257276cb43275f65c4, resolved once from the public master tip)
  were added to the approved baseline. alias-tips declares NO license (no file in the tree, none detected by
  GitHub); it is downloaded on the user's system, not incorporated or redistributed. It runs python3 from preexec.
- Prezto history options: MIT notice in `workflow/shell/LICENSE.prezto`, attribution entry added.
- NOT measured: startup time with the three added plugins. The accepted thresholds (subsequent median <= 300 ms,
  first <= 700 ms, first-command median <= 50 ms) must be rechecked in Task 4 on a real provisioned system.
- The `~/.local/bin/vim` wrapper that `alias v`/`alias nvim` call belongs to the editor capability (needs an
  executable managed-file path; `cfg_user_file` installs 0644) and is NOT delivered yet.
- Verification (guest, explicit Node PATH): `bats tests/capabilities` all pass except the timing-based signals test
  when run under `--jobs`, which passes alone; `tests/operations` 64 pass; the installer engine suite passes (one
  test failed only under parallel load and passes alone); ShellCheck, `bash -n`, `zsh -n`, `git diff --check` clean.
  Plugin clones use a Git double; a real fresh provisioning has NOT run (Task 4).

### Correction: measured cost of the added aliases and hints

The previous note that startup with the three added plugins was not measured is superseded. Guest PTY
measurements (isolated per-variant zplug copy and cache, `zsh -d -i`, TERM=foot; 1 first-observed start, 6
subsequent; not product tooling, nothing retained in the repository):

| Variant | First start | Subsequent prompt median | First-command response median |
| --- | --- | --- | --- |
| Approved baseline | 460 ms | 242 ms | 24 ms |
| git + common-aliases + alias-tips through `zplug ... from:oh-my-zsh` | 6790 ms | 267 ms | 46 ms |
| git + common-aliases sourced directly, no alias-tips | 497 ms | 253 ms | 24 ms |
| Directly sourced aliases + alias-tips | 550 ms | 250 ms | 47 ms |
| Product `zshrc` (directly sourced aliases + alias-tips) | 527 ms | 252 ms | not separately sampled |

The from:oh-my-zsh plugin loader forced a multi-second zplug cache rebuild at the first start and violated the
700 ms first-observation threshold, so the product `zshrc` sources `plugins/git` and `plugins/common-aliases`
directly from the identified oh-my-zsh clone. alias-tips doubles the per-command latency (python3 in `preexec`),
leaving about 47 ms against the 50 ms threshold. A first measurement that shared one zplug cache across
alternating variants was invalid (it rebuilt the cache on every run) and is not evidence. The product `zshrc`
showed `gst`/`gco`/`l` defined, `ls --color=auto` still overriding, and alias-tips, zsh-vi-mode, autosuggestions,
syntax highlighting and `nvm_load` loaded. Real fresh provisioning and renewed measurement remain Task 4.

### Supersession: alias-tips replaced by a native hint

At maintainer request (a fast shell is the priority) `djui/alias-tips` was removed and replaced by
`mirroros_alias_hint`, MirrorOS-owned pure Zsh in a `preexec` hook that names the longest alias whose expansion
starts the typed command. alias-tips, its pinned commit, the `python` package declaration and the upstream
no-license caveat are gone from the product; the two oh-my-zsh alias sets stay sourced directly from the identified
clone (about 11 ms; a curated own alias file was judged not worth the roughly 10 ms). Guest PTY measurement of the
product `zshrc` (isolated zplug copy, TERM=foot; 1 first-observed start, 7 subsequent; not product tooling):
first start 505 ms, subsequent prompt median 242.3 ms (237.7-253.4), first-command response median 25.1 ms, and
`git status -sb` printed `Alias tip: gst`. This matches the approved baseline (460 ms, 242 ms, 24 ms) and meets the
accepted thresholds. The previous table's alias-tips rows remain as the measured reason for the replacement.
Targeted verification: the five Zsh contract tests (provisioning, existing sources, failed fetch, user-owned files,
static features plus a hint-function behavior check) pass. Real fresh provisioning is still Task 4.

## Task 3 continuation: Tmux block

Delivered in `capabilities/workflow/tmux/` (guest checkout, uncommitted): the four approved native files
(`tmux.conf`, `tmux.bindings.conf`, `tmux.navigator.conf`, `tmux.theme.conf`, byte-identical to the approved
prototype candidates), `install-plugins`, `build-sesh`, `sesh/PKGBUILD`, `LICENSE.notices`, `sources.md`, an
updated `apply` and `packages` (tmux, wl-clipboard, inetutils, rust, base-devel). `capabilities/lib/packages.sh`
gains `cfg_recipe_version`, `cfg_local_package_present` and `cfg_local_package_ensure`, the only extension of the
package effect boundary and only for Sesh. New doubles: `cargo`, `makepkg`; `pacman` gains `-U` and per-package
versions; `git` allows the plugin paths.

- **Plugins:** TPM and seven plugins are cloned by `install-plugins` as the user at the commits of the approved
  source map, in an owned staging directory published without overwriting; an existing clone of the expected origin
  is accepted at the user's commit; anything else is preserved and stops the step. tmux-thumbs is compiled with
  `cargo build --release --locked --target-dir=target` only when its binaries are missing or their version differs
  from the clone (the plugin's own startup check), which replaces its interactive Compile/Download prompt.
  Tmux itself never installs or builds anything. TPM's install/update bindings are not part of the contract.
- **Sesh:** `sesh/PKGBUILD` derives from AUR `sesh-bin` 2.33.0-1 (recipe revision
  `e2965e02ffbbb63fc2af817456c4fde99a843f8c`), x86_64 only, with the reviewed asset checksum
  (`e04fe357...`, re-verified against the downloaded `v2.33.0` asset), `!strip`, `pkgrel=1.1`, and the upstream MIT
  text installed from the tag commit `863935c8caa3cc40cac6adcd344ac9742e51739f` (blob SHA-256 `7a2c197f...`). The
  release archive has no license file, which is why the text is a second checksum-verified `source`. The user builds
  with `makepkg` (no `-s`) from a recipe passed as data (base64 argument; root never executes it), and only
  `pacman -U` runs with privileges. A build happens only when `sesh-bin` is missing or differs from the recipe.
- **Notices:** `LICENSE.notices` reproduces the vim-tmux-navigator license (blob `046c81da...`, verified by
  `git hash-object`) and the omerxx/catppuccin-tmux LICENSE at `e30336b79986e87b1f99e6bd9ec83cffd1da2017`.
  `docs/attribution.md` gains entries for both and for the Sesh recipe (the AUR recipe declares no license of its
  own; its maintainer line is kept) and extends Tokyo Night to the Tmux theme.
- **Wording kept as approved:** the comment above `bind o` in `tmux.bindings.conf` still says "candidate". The file is
  byte-identical to the approved candidate, so it was not reworded here; reword it in a reviewed change if wanted.
- **Packages:** `base-devel` (core) is declared by this step because `makepkg` requires it; the editor step must not
  declare it again. `fzf` and `zoxide` stay with `workflow/shell`, `git` with `workflow/node`.

Verification (guest, explicit Node PATH, targeted): the 8 new mechanism contracts (provisioning plus no-op rerun,
existing/foreign/linked sources, resumable and mismatching thumbs build, Sesh unsupported/failed/install-failed/
replace cases, recipe parsed as data, user-owned files, static content with Floax/Sessionx/host-path exclusion, and
parsing of the bindings, navigator and theme in an isolated Tmux 3.8 server), the target-context Tmux contract
(arch-chroot routing, user build, `SNAP_PAC_SKIP` on `pacman -U`, no service starts, unchanged rerun) and the
existing six-step target contract all pass; the effect-boundary, package-helper, refresh and managed-file contracts
still pass. ShellCheck (repository `.shellcheckrc`), `bash -n` and `git diff --check` are clean; trailing
whitespace checks of the new files are clean; host gitleaks on the touched files reports zero findings (partial scan,
not the full repository gate).

Not verified and still required: no real `makepkg`, `pacman -U`, `cargo` build, plugin clone or `git` network access
ran; every effect used command doubles. The packaged `v2.33.0` binary has not been functionally tested (the reviewed
prototype was a `dev` build of `ac21f7f832e3e3270d4ba365a29041e070964159`); Prefix+o, creation from Zoxide
directories, selection, cancellation and Resurrect coexistence must be rechecked on a configured system. The
guest's `/usr/local/bin/sesh` prototype stays untouched and precedes `/usr/bin` in `PATH`, so it can shadow the
package on this laboratory VM. Building and installing for real is a sensitive effect and belongs to Task 4 after
explicit authorization. Remaining Task 3 work: editor, Pi, order/provenance validation, `mvp-scope`/`epics`, and the
final gate.

## Task 3 continuation: editor, Pi, Google Cloud CLI and step order

Applied to the guest checkout; not terminal Task 3 acceptance. Every check below used command doubles; no real
package, npm, git, `npx`, download or Sesh build ran (those belong to Task 4).

### Configure step order

`capabilities/configure-steps` now runs eight steps, prerequisites before consumers: `desktop/terminal`,
`workflow/node`, `workflow/shell`, `workflow/tmux`, `workflow/editor`, `workflow/pi`,
`desktop/compositor/providers/hyprland`, `desktop/login`. Node precedes shell, Tmux, editor and Pi because they use
its declared bin directory. `base-devel` is declared only by `workflow/tmux`.

### Editor

- `workflow/editor` declares `lazygit tree-sitter-cli unzip go` (extra) and installs the portable Lazygit input,
  the `~/.local/bin/vim` wrapper (byte-identical to the approved guest wrapper, mode 0755) and the
  `~/.config/nvim` link to `~/code/nvim`. `cfg_user_file` gained an optional mode (0644|0755) with drift repair;
  `cfg_user_link` and `cfg_user_link_present` create a link only while the path is absent (`ln -sT`) and treat any
  other path as user-owned.
- `nvim-lua-new` is synchronized by `cfg_repository_sync` (selected branch tip resolved once, fast-forward only).
  `prepare-nvim` runs as the user with the declared Node bin first on the existing `PATH`: `Lazy! restore`,
  `config.prepare_tools` and `config.treesitter`, once per applied commit. Its stamp
  `~/.local/state/mirroros/editor/nvim-prepared` is written only after all three succeed, and the step is skipped
  when `~/.config/nvim` does not resolve to `~/code/nvim` (user-owned).
- Lockfiles are honored; no tracked external file is modified and no language server or debugger outside the
  declared tools is installed.

### Pi executable and pi-config

- `install-pi` (user script) selects the Pi version once with `pi-version.mjs` (exact `devDependencies` value; absent
  declaration resolves the latest stable registry release once; a range, malformed value or malformed JSON fails),
  runs `npm install --global --prefix <nvm prefix> --ignore-scripts` only when the installed version differs, and
  runs `npm ci --ignore-scripts --omit=dev --omit=peer` in `~/code/pi-config` only when `node_modules` is missing or
  the SHA-256 of `package.json` plus `package-lock.json` differs from
  `~/.local/state/mirroros/pi/pi-config-dependencies` (written only after success).
- pi-config is synchronized with `cfg_repository_sync`; `~/.local/bin/pi-editor` is linked only while absent.
  `ffmpeg` (extra) is the only package declared by this owner. The applied selection (`exact_dependency` or
  `stable_registry`, plus version) is recorded in `sources.tsv`.

### Initialize-only `~/.pi`

`init-pi` (user script) treats `~/.pi` as one directory-level policy. Existing paths, symlinks and dangling
symlinks are preserved and reported before anything is written; no settings, keybindings, packages or diagnostics
are touched inside them. For an absent path:

1. A `flock` lock under `~/.local/state/mirroros/pi` serializes runs; stale owned staging (marker file) is removed.
2. Owned sibling staging `~/.pi.mirroros.XXXX` receives the defaults (`settings.json`, `keybindings.json`,
   `APPEND_SYSTEM.md`, seven prompt templates), validated as regular files and JSON with voice and TTS enforced
   disabled, plus the twelve extension links and `node_modules` link into `~/code/pi-config`, checked to resolve
   before publication.
3. Six npm packages (`@codexstar/pi-listen@7.2.2`, `pi-mermaid@0.3.0`, `pi-extension-manager@0.8.2`,
   `pi-resource-center@0.3.1`, `pi-sub-anthropic@0.1.10`, `pi-web-access@0.41.0`, declared as data in
   `npm-packages`) install into `<staging>/agent/npm` with `--ignore-scripts --legacy-peer-deps --no-audit
   --no-fund`, an empty user/global npmrc and HOME/TMPDIR/XDG/cache inside staging. Direct npm was chosen over
   `pi install` after a read-only inspection of Pi 1.3.0: `pi install` passes no `--ignore-scripts` and rewrites the
   shipped `settings.json`. Every `npm:` source in the shipped settings must exist under `agent/npm/node_modules`.
4. Two MirrorOS-authored skills (`aikido-mcp`, `atlassian-mcp`) are delivered to
   `${XDG_DATA_HOME:-~/.local/share}/mirroros/pi/skills/<name>` only if absent and linked only inside the fresh
   staging; identical existing delivery is accepted, anything else fails before publication.
5. Four external skills are declared in `external-skills` (`teach` and `wait-what` from `mattpocock/skills`,
   `show-me` from `humanlayer/skills`, `archify` from `tt-a1i/archify`). Each repository's default branch is
   resolved once (`git ls-remote --symref`), fetched by exact commit inside staging with an isolated git
   environment, and installed with `npx --yes --package=skills@1.7.2 skills add <local checkout> --skill ... --agent
   pi --copy --yes` (project scope, empty npm config, scripts and telemetry off). The installed payload must equal
   the upstream directory (`diff -r`); `manual-skill.mjs` then sets only `disable-model-invocation: true`; the
   repository license is copied only when the skill has none (abort if the repository has none either). Reviewed
   upstream commits (provenance, not pins): `49dd158d`, `653b6411`, `ba701d20`.
6. Publication is `mv -T --no-clobber`; a destination created concurrently is preserved and staging removed; a trap
   removes owned staging on exit, INT and TERM. Any package or skill failure aborts the whole initialization with
   nothing published and no owned skill delivered, so a partial directory never becomes a preserved completed setup.

The seven prompt templates and the two authored skills are original MirrorOS material (GPL-3.0-only, maintainer
authorization), shipped unchanged as initialize-only defaults. External skills are downloaded, not incorporated, so
`docs/attribution.md` has no entry for them. Credentials, sessions, trust decisions, generated state, caches and
voice models are never copied; no model download happens for the disabled voice/TTS features. A multi-harness
`~/.agents/skills` delivery is a separate follow-up decision, not part of this contract.

### Google Cloud CLI

`install-gcloud` (user script, coreutils only) installs SDK 589.0.0 into `~/.local/opt/google-cloud-sdk-589.0.0`
and `apply` links `~/.local/bin/gcloud` through `cfg_user_link`. The archive is verified before extraction by size
(93451089), the published MD5 (`c3d491ff5bb2a19aa9fbf86f2e0e9eba`, converted once from base64) and a locally
computed SHA-256 (`f865da648f6fdae2015abb5b32eaa0eb10520e88f0ca735cfb33795868c8d26f`); that SHA-256 is not an
upstream checksum. Extraction uses owned staging under `~/.local/opt` and `mv -T --no-clobber`. A satisfied install
(matching `VERSION`) downloads nothing; a different-version directory, a symlink or a concurrently created
destination is preserved with an actionable failure. The script never runs `install.sh`, `gcloud init`, component
management or authentication and never edits profiles; the check mode runs `gcloud --version` with a throwaway
`CLOUDSDK_CONFIG`. Private Vertex AI setup stays attended.

### Verification and remaining work

Targeted checks (guest, explicit Node PATH, `bats --jobs 2 -f` on the touched files only, no suite repeats): Pi and
editor mechanism contracts, gcloud 6/6, target `Pi|eight-step` 2/2, repositories 12/12, `manual-skill.test.mjs`
11/11, plus regression selections for Zsh, Tmux, Node and editor; `bash -n`, ShellCheck with the repository rc,
`node --check`, `git diff --check` and trailing-whitespace checks clean; partial host gitleaks on touched files with
zero findings. The full suites and the two timing-sensitive tests (run alone) were verified only in earlier blocks;
the final Task 3 gate is still pending.

Not verified: real fresh provisioning, real npm/registry/git/`npx` and download runs, whether the real
`gcloud --version` writes files inside its installation directory, loading of the six packages and four skills in
Pi, the packaged Sesh binary, and renewed startup measurements. The guest's `~/code/nvim` and `~/code/pi-config`
remain dirty prototype branches that `cfg_repository_sync` rejects by design; move them aside manually or
reconstruct in a fresh VM (Task 4) before a real configure run. Remaining Task 3 work: `mvp-scope`/`epics`,
order/provenance validation and the final gate.

## Task 4 continuation: running-context provisioning and rerun

This chronological addendum supersedes the earlier pending statements only for the checks listed here. Task 3
was accepted after its bounded source gate; Task 4 and the final reconstructed-guest checkpoint remain open.
No commit, push, additional VM launch or disk replacement has been authorized by these running-context checks.

### Candidate and laboratory preparation

The running candidate is the guest `~/mirroros`, branch `workbench-prototype`, based on
`58523d5d9734249f08f9a3cf1e52de24be26552c` with uncommitted changes. This base SHA plus `dirty=yes` is not a
content-addressed identity for the candidate; an approved commit and clean-clone gate remain pending.

The maintainer authorized preserving the stale external prototype clones by rename after closing Neovim and Pi:

- `~/code/nvim` became `~/code/nvim.workbench-prototype-20261020T093911Z`.
- `~/code/pi-config` became `~/code/pi-config.workbench-prototype-20261020T093911Z`.

Both renames used absent-destination checks and `mv -T --no-clobber`; device/inode identity, old-path absence,
Git HEAD and dirty state were checked afterward. No reset, stash or deletion was used. These are recovery steps
for this preconfigured laboratory, not prerequisites for a clean reconstruction. Existing resource links were not
rewritten; product configure recreated the source paths from the public normal branches.

### Real Sesh package and plugin provisioning

With explicit authorization, the guest ran the product `capabilities/workflow/tmux/build-sesh` as the user with
the current recipe passed as base64 data. Existing official prerequisites were already installed. Both declared
source SHA256 checks passed and native build status was zero. The resulting package was:

```text
~/.cache/mirroros/sesh/sesh-bin-2.33.0-1.1-x86_64.pkg.tar.zst
```

The maintainer installed it through attended `sudo pacman -U`. Independent checks confirmed `sesh-bin 2.33.0-1.1`,
`pacman -Qkk` with 13 files and zero altered files, executable version 2.33.0, and packaged manual/MIT notice.
A synthetic HOME/XDG and isolated Tmux socket test verified `/usr/bin/sesh list --tmux --no-cache` and
`/usr/bin/sesh list --zoxide --no-cache`. The first attempt failed before server creation because the Unix socket
pathname was too long; retrying with a short `/tmp/mos-sesh.*` fixture passed and its server was stopped and checked.
Build and smoke-test diagnostics are under `evidence/development-workbench/20261020T093434Z-sesh/`; they have not yet
received the acceptance secret scan. They are not full interactive or reconstruction evidence.

The first running configure attempt stopped safely in `workflow/tmux`: the existing TPM-created plugin origins
used an HTTPS URL containing `git::@` rather than the exact declared plain HTTPS origin. The original diagnostic
identified `tmux-sensible`, child status 4, normalized configure outcome 5. No source-validation relaxation or remote
rewrite was introduced. With the maintainer's explicit approval and no active Tmux processes, the complete plugin
directory was preserved at `~/.config/tmux/plugins.workbench-prototype-20261020T094900Z`, again retaining its inode
and contents. The subsequent product run cloned the declared sources and completed the real thumbs preparation.

A separate prototype executable at `/usr/local/bin/sesh` initially shadowed the package. With separate approval,
the maintainer renamed it to `/usr/local/bin/sesh.workbench-prototype-20261020T100000Z` using no-clobber semantics.
Independent inode verification confirmed that the original executable was preserved; `command -v sesh` now
returns `/usr/bin/sesh` and its version is 2.33.0. No PATH workaround is required for the packaged provider.

### Successful configure and unchanged-input rerun

The maintainer ran both commands in the guest, supplying sudo authentication privately:

```bash
cd ~/mirroros
sudo ./operations/configure --user viespejo
sudo ./operations/configure --user viespejo
```

`--refresh` was not used. All declared official packages were already installed. Reviewed run identities:

| Run | Outcome | Applied state |
| --- | --- | --- |
| `20261020T094929Z-b7313701-0988-447a-97ef-6a5cfbfd6cc5` | 0 | Tmux, editor, Pi and compositor changed; other steps unchanged; all postconditions passed |
| `20261020T095406Z-85533ec1-ad53-4427-9d9a-372e0ec9793e` | 0 | All eight steps unchanged; all postconditions passed |

Both records identify context `running`, target user `viespejo`, the same base SHA with `dirty=yes`, default package
mode and guard `not_needed`. Their `sources.tsv` files are byte-identical. Consumed external normal-branch commits:

- Neovim `master`: `bdf02dd9b726c215c31d3a64c6cb38e56bbdac58`.
- pi-config `master`: `37ae549ae4de603ab0b9535e9a13187c9d257a26`.
- NVM v0.40.8 at `a885b885fef16fac4bc544188fb25e9e37ae83e8`, Node.js v24.22.0.
- Pi 1.3.0 from pi-config's exact dependency; installed public package metadata matches.
- Sesh 2.33.0-1.1 and the plugin commits recorded in `sources.tsv`.

Both recreated external clones are clean. The first successful run restored the locked editor plugins, preserved
already installed editor tools/parsers, and installed 34 pi-config npm dependencies. npm reported the upstream
`uuid@9.0.1` deprecation warning; it was not hidden or automatically repaired. The second complete log contains no
package, npm, plugin, editor-preparation or managed-file transaction. Both logs report the existing `~/.pi` preserved
without applying defaults, and state that SDDM was not started. This is observed running-context rerun evidence,
not a byte/content comparison of the private Pi directory or proof of fresh initialization.

The maintainer exported only `configure-run.tsv`, `packages.tsv`, `sources.tsv` and `configure.log` from these two
root-owned runs to `evidence/development-workbench/running-20261020T095608Z/`. An allowlisted copy was scanned on the
host before log inspection: `gitleaks dir --redact --report-format json` returned zero, no findings, 112829 bytes.
The temporary host review is `/tmp/mirroros-task4-evidence.khUGlipb/running`, with report
`/tmp/mirroros-task4-evidence.khUGlipb/gitleaks-running.json`; it is not a durable product or full repository gate.

### Runtime and attended behavior checks

Active Zsh startup files match the product and the login shell is `/usr/bin/zsh`. A plain noninteractive SSH command
does not source `.zprofile` or `.zshrc`; an initial `command -v node` probe therefore failed. This was a probe
assumption, not repaired by loading NVM. Both interactive startup files source the declared runtime environment.
A clean `zsh -f` with that managed environment explicitly sourced resolves node, npm, pi, nvim, zsh, tmux, sesh,
gcloud and pi-editor without `nvm_load`; Node reports v24.22.0. Provisioning likewise supplies its runtime explicitly.

After the packaged Sesh became the default executable, the maintainer confirmed all five requested running-guest
checks: Prefix+o selects an existing session, selecting a Zoxide directory creates its session, Escape cancels
without switching, Neovim/Tmux pane navigation works, and Shift+Enter works in Pi inside Tmux. No conversation,
authentication data or private session content was retained. These outcomes do not constitute the final acceptance
of a separately reconstructed guest, all graphical behaviors, or restoration coexistence after product provisioning.

### Still pending in Task 4

- Renewed startup measurements and fresh-session graphical checks against the accepted criterion.
- Disposable fresh Pi initialization, package/resource loading and controlled existing-directory preservation.
- Fresh product NVM/Node and Google Cloud CLI provisioning, including real download behavior.
- Product-configured restoration/coexistence checks and broader approved terminal/editor workflows.
- Real target-root configure, a separate disposable VM, approved candidate commit and clean-clone gate.
- Required source/contract validation, repository secret-scanning procedure and scans of all retained evidence.

No private Pi directory, backup, credentials, histories or models were inspected for these checks. Historical,
separately authorized exceptions remain documented in the earlier execution history; this addendum does not
renew them or claim that no such exception ever occurred.

## Task 4 continuation: real fresh Pi initialization and preservation fixtures

The maintainer separately authorized this disposable-HOME test after the session handoff. No actual user Pi directory,
backup, credential, session, history or model was accessed. No sudo, account setup, prompt, VM operation, source repair,
commit or push was performed. This advances Task 4, not the reconstructed-VM acceptance gate.

### Inputs and execution

- Guest product branch: `workbench-prototype`; base `58523d5d9734249f08f9a3cf1e52de24be26552c`, still dirty/uncommitted.
- Product helper and declarations: `capabilities/workflow/pi/{init-pi,defaults/,skills/,npm-packages,external-skills,manual-skill.mjs}`.
  Payloads use the same deterministic tar/gzip/base64 commands as `workflow/pi/apply`; the helper was not modified.
- Fixture: `/home/viespejo/.local/state/mirroros-lab/workbench-prototype/pi-product-fresh.kbHIXiav`.
  Its synthetic HOME links only the satisfied Node v24.22.0 runtime and the clean public pi-config checkout as prerequisites.
  pi-config commit: `37ae549ae4de603ab0b9535e9a13187c9d257a26`.
  This is real helper-level initialization, not a new full configure/target/VM reconstruction or a fresh Node installation.
- Evidence: `evidence/development-workbench/20261020T111014Z-pi-fresh/` (ignored).
  `fresh-pi.sh` records the exact setup/invocation/preservation checks; `load-resources.mjs` records the native SDK probes.
  Before reusing the scripts for another real download run, obtain the applicable authorization; each fresh run makes a new fixture.

The fresh helper runs as the normal guest user under `env -i`, synthetic HOME/TMPDIR, C.UTF-8 and an explicit system PATH.
The product prepends its declared Node binary, isolates npm configuration/cache, disables lifecycle scripts, installs all six
exact declared packages, resolves external source tips once each, and publishes only after validation. Native status: `0`,
`changed initialized`; npm reported 333 packages added. This does not pin all transitive dependencies or constitute an npm audit.

Consumed skill sources (moving default branches, not permanent pins):

| Repository | Branch | Commit |
| --- | --- | --- |
| `mattpocock/skills` | `main` | `5beb35b040e3de97e54fa9e386d7e42d15c295c2` |
| `humanlayer/skills` | `main` | `653b6411c1f70c275a18e37673b042ff99f67ceb` |
| `tt-a1i/archify` | `main` | `25cf37080fc8b1dbe758a4efc3935b55f3327083` |

The first and third differ from earlier prototype observations: the declared moving-input policy permits this and the consumed
commits are recorded in `fresh.stdout`. Skills CLI: `1.7.2`. The installed payload equality and license/frontmatter checks passed.

### Preservation and resource results

Before any SDK loading, added only synthetic unknown/package-state files to the fixture, then reran the unchanged product helper.
Result: `unchanged preserved`, status `0`. Full lstat metadata and regular-file SHA256 manifests of the fixture Pi directory and
owned-skill delivery match before/after. The inventory does not follow symlinks into shared prerequisites. A separate synthetic HOME
with `.pi` symlinked to the initialized fixture also returned `unchanged preserved`, status `0`; link target and full manifests match.
Failing npm/npx/git sentinels were first on PATH during both preservation probes; none ran. This demonstrates fixture preservation,
not a byte audit of the maintainer's private directory. Preservation was checked before SDK startup writes, which are a separate phase.

With the installed Pi 1.3.0 SDK, `DefaultResourceLoader.reload()` succeeded with 17 extensions, six skills (all manual-only), seven
prompts, zero extension errors and zero skill/prompt diagnostics. `createAgentSession` with `SessionManager.inMemory()` and
`bindExtensions` emitted `session_start` successfully without calling `prompt()`, authentication or any model request.
Voice and TTS remained disabled. Fixture-only metadata inventory found only two new two-byte state files, `agent/auth.json` and
`agent/models-store.json`; their contents were not inspected or retained. No model artifacts were observed.

A temporary probe blocked and counted Node fetch/http/https/socket connection attempts before SDK import: zero attempts during
resource reload and session_start, zero lifecycle extension errors. This is a bounded process-level guard, not an OS sandbox or
proof of arbitrary subprocess networking. No audio, model acquisition, real-provider readiness or interactive skill execution is claimed.

Exact post-initialization probe pattern (the script uses explicit SDK paths, fixture-only agentDir and no prompts):

```bash
FIXTURE=/home/viespejo/.local/state/mirroros-lab/workbench-prototype/pi-product-fresh.kbHIXiav
cd "$FIXTURE/workspace"
env -i HOME="$FIXTURE/home" USER=viespejo LOGNAME=viespejo LANG=C.UTF-8 \
  PATH="$FIXTURE/home/.nvm/versions/node/v24.22.0/bin:/usr/bin:/bin" TMPDIR="$FIXTURE/tmp" \
  PI_CODING_AGENT_DIR="$FIXTURE/home/.pi/agent" \
  timeout 90 node "$FIXTURE/load-resources.mjs" --session-start
```

### Verification, evidence and limits

- Temporary shell script: `bash -n` and ShellCheck passed. SDK probe: `node --check` passed.
- Native fresh, preservation, symlink, resource reload and session-start statuses: all `0`.
- Scoped host Gitleaks scan of the exported allowlisted evidence, before log review: zero findings. Final evidence scan includes
  the retained scripts and redacted scan reports; see the adjacent reports. No private runtime directory was scanned/exported.
- Documentation-only product update; no Bats rerun. Product Bash/Node implementation was not changed.
- Pending: fresh NVM/Node/gcloud product provisioning, startup remeasurement, product restoration/fresh graphical observations,
  real target-root and separate-VM reconstruction, full repository/clean-clone gates and both remaining task reviews.
  Existing running-context and packaged-Sesh checks were not repeated.

## Task 4 continuation: fresh NVM, Node.js and Google Cloud CLI

The maintainer explicitly authorized real downloads and installation in a disposable guest HOME, followed by a separately
approved minimal fresh-path repair and retry. No sudo, real-user installation replacement, private Pi access, authentication,
model download, VM operation, commit or push was involved. The earlier pending fresh-runtime item is superseded by these
helper-level results, not by complete configure, target-root or separate-VM reconstruction evidence.

### Fresh-path failure and bounded repair

The first unchanged product run stopped at `nvm-fresh`, native status `4`, before Node or gcloud installation. The official
NVM v0.40.8 installer requires an explicitly selected nondefault `NVM_DIR` to exist. MirrorOS selected `$staging/nvm` but had
not created it. Verified this precondition against the existing public installer source, SHA256
`48a0eee9a60e07422dce0eb5774754c83889570ca1ee2566c516acbe8af03a9e`, matching the reviewed source identity.

After explicit repair authorization:

- `capabilities/workflow/node/install-nvm` creates only its owned `$staging/nvm` before invoking the installer.
  Existing-installation checks, source/checksum validation, profile suppression and no-clobber publication remain unchanged.
- `tests/capabilities/doubles/curl` now emits an installer that rejects a missing custom `NVM_DIR`, matching upstream.
  With this double alone, the existing fresh-provisioning contract failed (native `1`); after the helper fix it passes.
- First failed fixture: `~/.local/state/mirroros-lab/workbench-prototype/runtime-product-fresh.pLMgPfjE`.
  Failed-phase and regression evidence: `evidence/development-workbench/20261020T113051Z-runtime-fresh/`.
  The helper cleaned its owned failed staging; the disposable fixture and diagnostics were retained.

### Successful fresh run and rerun

- Successful fixture: `~/.local/state/mirroros-lab/workbench-prototype/runtime-product-fresh.CGohGtf4`.
- Evidence: `evidence/development-workbench/20261020T113318Z-runtime-fresh/`.
  `fresh-runtimes.sh` records the exact commands, `inputs/` preserves the consumed product scripts, and
  `input-sha256.txt` records their identities. Native phase logs/statuses and filesystem manifests are retained.
- The normal guest user runs the product helpers with `env -i`, synthetic HOME/TMPDIR/XDG paths, C.UTF-8 and
  `/usr/bin:/bin` PATH. The test parses `MIRROROS_NODE_VERSION` from the single product declaration as data.
- NVM `v0.40.8`, commit `a885b885fef16fac4bc544188fb25e9e37ae83e8`, installed successfully with automatic profile editing
  disabled. NVM downloaded Node.js `v24.22.0` and reported matching archive checksums; npm is `11.19.1`.
- Google Cloud CLI `589.0.0` installed from the declared official archive after size, MD5 and SHA256 checks;
  observed SHA256 `f865da648f6fdae2015abb5b32eaa0eb10520e88f0ca735cfb33795868c8d26f` remains a locally computed
  identity, not an upstream-published SHA256. No `install.sh`, component update or authentication command ran.
- Fresh/apply/check/rerun phases all returned `0`; reruns report `unchanged`. NVM regular-file hashes and lstat-style
  metadata match before/after rerun. Google SDK hashes and metadata match between its first completed version check
  and the subsequent apply/check. No repeat download occurred in either rerun.
- Under isolated `zsh -f`, sourcing only the product `environment.zsh` resolves the new node/npm and reports the expected
  versions without invoking `nvm_load`; the on-demand function exists. No host or personal startup file was sourced.

The first `gcloud --version` creates 753 new Python bytecode (`.pyc`) files inside the fresh SDK and corresponding cache
subdirectories, changing directory metadata. No previously present regular-file hash changed. The next apply/version check
is stable. This is observed upstream first-use cache generation, not a silently modified product policy; no byte-for-byte
immutability claim is made for the initial version check. Configuration for version reporting is disposable and unauthenticated.

### Verification and remaining gates

Commands executed in the guest repository, without real host mutations through tests:

```bash
bash -n capabilities/workflow/node/install-nvm tests/capabilities/doubles/curl
shellcheck capabilities/workflow/node/install-nvm tests/capabilities/doubles/curl
bats -f '^node runtime is provisioned as the user' tests/capabilities/mechanism.contract.bats
bats --jobs 2 -f 'node runtime|node installer|NVM|nvm|Node.js' tests/capabilities/mechanism.contract.bats
bats --jobs 2 -f 'a missing base tool|node provisioning stops before' tests/capabilities/mechanism.contract.bats
bats -f '^target node provisioning' tests/capabilities/target.contract.bats
git diff --check
```

The single fresh contract intentionally failed before the repair. After repair, seven selected runtime contracts, two additional
boundary/checksum contracts and one target-routing contract pass. Bash syntax and ShellCheck pass for the helper, double and
bounded diagnostic script; whitespace checks pass. No unrelated suites were repeated. The target contract uses doubles, not a
real mounted target. Scoped Gitleaks before log inspection and over source/scripts/manifests returned zero findings; redacted
reports are retained alongside the ignored evidence. This is not the full repository negative-control/clean-clone gate.

The product candidate remains dirty/uncommitted on `workbench-prototype`, base `58523d5d9734249f08f9a3cf1e52de24be26552c`.
Fresh runtime helper execution is now demonstrated. Remaining Task 4 gates include startup remeasurement, product restoration
and fresh graphical observations, source/repository validation, approved candidate commit and clean clone, and real target-root
plus separate disposable VM reconstruction. Task 5 final graphical/provider acceptance remains blocked on reconstruction.

## Task 4 continuation: isolated product Zsh startup measurements

The maintainer explicitly authorized this bounded measurement after review of the execution history. No installation,
authentication, service operation, VM action or active configuration change was performed. The guest still has two CPUs and
MemTotal 3994820 kB. Active `.zshrc`, `.zprofile` and `.zshenv` match product declarations; the measured product `.zshrc` SHA256
is `0cabbfb29102f8ddc86034fe0543a6d416817a2b60776571419f190e70b7de28`.

Evidence is retained under ignored `evidence/development-workbench/zsh-product-LovuoA/`: `measure-startup.mjs`, `method.json`,
`samples.json`, `summary.json`, `thresholds.json`, `feature-probe.json` and `gitleaks-startup.json`. The bounded Node.js diagnostic
uses native `script` PTYs, not a new product provisioning framework. Reproduction, only after reviewing its effects:

```bash
"$HOME/.nvm/versions/node/v24.22.0/bin/node" --check evidence/development-workbench/zsh-product-LovuoA/measure-startup.mjs
"$HOME/.nvm/versions/node/v24.22.0/bin/node" evidence/development-workbench/zsh-product-LovuoA/measure-startup.mjs
```

Each invocation creates a new measurement directory. Ten alternating samples per variant use non-login `zsh -d -i`, PTY
120x40, TERM `foot`, LC_ALL `C.UTF-8`, the same guest resources and `~/mirroros` working directory. The harness starts with a
clean environment and copies product Zsh into isolated ZDOTDIRs. It redirects history to empty fixture files, isolates Atuin
configuration/database, Zoxide database, cache/state/tmp, omits the user-local fragment loader, and sets STARSHIP_CONFIG to
`/dev/null`. Provisioned plugins and product functions remain; private fragments, histories and databases are not acceptance
inputs. These isolation differences mean this is not a measurement of the exact populated daily session or its visual prompt.

| Variant | First observed prompt | Subsequent prompt median | Subsequent prompt range | Subsequent response median |
| --- | ---: | ---: | ---: | ---: |
| Minimal | 7.316 ms | 5.663 ms | 5.211–6.048 ms | 0.350 ms |
| Product, isolated | 503.745 ms | 238.468 ms | 236.942–245.797 ms | 34.351 ms |

All twenty samples and the additional function/executable probe exited zero. The product meets the accepted first-observation
700 ms, subsequent-median 300 ms and subsequent-response-median 50 ms limits in this isolated measurement. First product
command response was 75.908 ms, retained explicitly; the accepted response criterion concerns subsequent median, not every
sample. The probe confirms presence of `nvm_load`, `mirroros_init`, `zvm_init`, autosuggestions, highlighting and native alias
hint functions, plus resolution of node/npm/pi/nvim/zsh/tmux/sesh/gcloud without calling `nvm_load`. Function presence does not
prove interactive feature parity.

This measures PTY prompt emission, not Foot launch/rendering, cold boot or guaranteed cold caches. Shared plugin caches were
not cleared. There is no host-relative comparison, new optimization or claim of graphical responsiveness acceptance.
Node syntax validation and `git diff --check` pass; active `.zshrc` bytes remain unchanged. Scoped Gitleaks of the exact
allowlisted diagnostic/results returned zero findings (12746 bytes), with the redacted report persisted in guest evidence.
Fixture startup copies, caches and databases are not exported as acceptance evidence. No Bats rerun was needed for this
documentation-only product change. Full repository scans/negative control/clean clone remain separate pending gates.

The candidate remains uncommitted on `workbench-prototype` at base `58523d5d9734249f08f9a3cf1e52de24be26552c`.
The earlier startup-remeasurement pending item is superseded by this result, subject to maintainer review of its isolation
limits. Product restoration/fresh graphical observations, source validation, approved commit/clean clone, real target-root
and separate disposable VM reconstruction remain pending; Task 5 remains blocked. No new build/VM/commit/push authorization
is implied by this measurement.

## Task 4 continuation: bounded product Resurrect/Continuum and Sesh fixture

The maintainer explicitly authorized a disposable-HOME/socket test using the product-configured plugins, without accessing
real session state or replaying personal processes. Both installed clones are clean and match declared identities:
Resurrect `cff343cf9e81983d3da0c8562b01616f12e8d548` and Continuum
`0698e8f4b17d6454c71bf5212895ec055c578da0`. Tmux is 3.8; packaged `/usr/bin/sesh` is 2.33.0.

Ignored evidence: `evidence/development-workbench/tmux-product-fmEoHs4G/`. It contains the bounded
`check-product-restoration.sh`, plugin identities, synthetic topology comparisons, per-operation logs, result/native-status
files and redacted Gitleaks report. Fixture `/tmp/mos-restore.gPK9IVHD` is separate from private user data and retained for
diagnosis. The wrapper forces plugin and Sesh Tmux calls onto its owned socket. Its HOME, XDG paths, pane directories and
Resurrect save directory are synthetic; pane shells use Bash without profile/rc files.

The fixture copies product bindings/navigation/theme byte-for-byte and loads the native product configuration with only
its TPM entry point omitted. This prevents invoking Continuum automatic-service handling. Fixture overrides select Bash,
disable status display, automatic renaming, pane-content capture and process replay, and direct persistence to the synthetic
save directory. It registers native Resurrect bindings/script options and directly invokes the installed Continuum save and
restore scripts; no plugin source is modified, no service handler invoked and no multi-server guard mocked or bypassed.

Reproduction requires review of the script's synthetic-session creation/destruction effects and a new empty evidence directory:

```bash
record="$(mktemp -d "$PWD/evidence/development-workbench/tmux-product-XXXXXXXX")"
env -i HOME="$HOME" USER="$(id -un)" PATH=/usr/bin:/bin LC_ALL=C.UTF-8 \
  bash --noprofile --norc evidence/development-workbench/tmux-product-fmEoHs4G/check-product-restoration.sh \
  "$PWD" "$HOME/.config/tmux/plugins" "$record"
```

Results:

- Native Continuum save and its timestamp update pass.
- Native Resurrect restores two windows/three panes, names, product base-index 1, pane indices and working paths.
- Repeated restore preserves identical topology without duplicate windows/panes.
- Product Prefix+o binding still references Sesh. Packaged Sesh lists the restored synthetic session without topology changes.
  This is source-list coexistence, not another interactive selection/cancellation acceptance.
- Continuum restore is **blocked by its upstream other-server guard**. No claim of automatic restore success is made.
  The guard was evaluated as implemented; real sessions were not inspected, closed or modified.
- No pane-content archive was created; process replay and automatic-service handling were disabled/not invoked.
- Owned server cleanup passes, followed by an independent check against that exact socket confirming no session remains.

Overall diagnostic status zero means its explicit passed-or-blocked classification completed; it does not turn the blocked
Continuum verdict into success. Detached restore logs retain `can't find session: 0` and `no current client` warnings; topology
checks nevertheless pass. Attached focus, exact geometry, editor/process restoration, fresh graphical startup and status-bar
save scheduling remain untested here. A later attended or otherwise authorized isolated run must resolve the automatic
restoration check without disabling its guard or disrupting private sessions.

`bash -n` and ShellCheck pass. An initial SC2016 diagnostic was corrected only by a narrow comment explaining deferred
variable expansion in the generated socket wrapper, before any guest execution. Scoped Gitleaks of the exact exported
synthetic diagnostic/log/result allowlist returns zero findings (8158 bytes); the report is retained in guest evidence.
Private homes, saved real sessions and pane contents were not exported or scanned. `git diff --check` passes; product source
and active configuration are unchanged apart from this procedure addendum. No Bats rerun is needed for documentation only.
Task 4 remains in progress; no VM/build/commit/push operation or final Task 5 acceptance is authorized by this fixture.

## Task 4 continuation: restoration retry and host repository validation

This chronological addendum supersedes only the pending direct-script restoration verdict above. Earlier observations
remain historical evidence, not failures hidden by the retry. The maintainer accepted both slices below without manual
amendments; neither acceptance closes Task 4 or the reconstructed-system gate in Task 5.

### Native Continuum restoration retry

After the maintainer authorized another isolated run and closed guest Tmux, metadata-only checks confirmed no user Tmux
processes before execution. The unchanged bounded diagnostic ran with synthetic HOME/socket and the same product inputs;
no private sessions were inspected or closed by the assistant and the upstream other-server guard was not bypassed.

Guest evidence: `evidence/development-workbench/tmux-product-retry-o1H3JNG1/`.
Reproduction uses the earlier command with `check-restoration.sh` from this evidence directory and a new empty record
path, after separately reviewing the fixture effects and ensuring no competing servers. Do not replay it against a
personal socket or close personal sessions automatically.

- Diagnostic native status: 0. Native Continuum save and direct-script automatic restore pass.
- Before/automatic topology comparison passes: two windows, three panes, names, indices and working paths.
- Manual Resurrect restore, repeated restore without duplicates and packaged Sesh source-list coexistence pass.
- Owned server cleanup and an independent exact-socket absence check pass.
- Pane-content capture and process replay remain disabled; service handling is not invoked.
- Boot restoration, status-bar save scheduling, attached focus/geometry and editor/process restoration remain untested.

`bash -n`, ShellCheck and `git diff --check` pass. Gitleaks of the selected exported script/status/results/topology/log
allowlist returns native 0 with no findings (6966 bytes); `gitleaks-selected.json` is retained in guest evidence. This is
not a full evidence-directory or repository scan. The previous other-server-blocked result is resolved for this native
direct-script check only.

### Repository validation in a temporary host candidate

The maintainer selected host-side validation and stated that eventual integration and commits will also be performed
from the host. This does not authorize an immediate commit, push or modification of active host product checkouts.
A temporary `git clone --no-local` was checked out at base `58523d5d9734249f08f9a3cf1e52de24be26552c`, then received exactly
91 guest modified/new source files after path/type/parent-symlink checks. No credentials, runtime state, `.agents/`,
outputs or unrelated untracked files were transferred. The candidate is still uncommitted; its base plus dirty status
is not a content-addressed final candidate identity.

Persistent HOST evidence: `evidence/development-workbench/repository-validation/20261020T132702Z/`.
The directory contains the exact temporary `validate-repository.sh`, native log, summary and redacted reports. The script
implements `docs/procedures/repository-validation.md` with the explicitly reviewed history deviation below. Its temporary
source location is not a durable dependency; regenerate a source-only candidate from the guest before future use.

- All required tool prerequisites, lifecycle Bash syntax and ShellCheck pass.
- `bats tests/operations`: 64/64, native 0.
- Gitleaks negative control: expected native 1; owned synthetic input removed; retained-evidence value search returns 1
  (absent). No synthetic value is retained in documentation or evidence.
- Initial full candidate directory scan and the successful run's working-tree scan return 0 with no findings.
- Build-directory scan returns 0 after control cleanup; `dist/` is absent in this temporary candidate.
- Validation evidence and persisted evidence scans return 0 with no findings.

The first run stopped at the history scan, which returned native 1 for two `generic-api-key` matches at
`tests/install/confirmation/confirm-plan.contract.bats:691` in commit
`004b1cb76eb570863704ff60ad30e79e0a3e994e`. Both are the same deliberate synthetic environment canary exported under two
variable names in a contract test that checks non-disclosure. Commit `34b37f0` already replaces the literal with a generated
canary; current source does not require a repair. Literal values are not reproduced here.

The maintainer explicitly approved accepting exactly those two historical false positives. A fresh timestamped run
preserves Gitleaks native status 1 and its redacted report, then verifies exact count, rule, commit, path, line,
fingerprint and two distinct redacted variable matches. Any additional or different finding fails. No scanner allowlist,
baseline or history rewriting is used; every other acceptance scan still requires zero findings. The validation wrapper's
native 0 means success WITH this approved deviation, not a claim that the raw history scanner reported zero findings.
Future clean-clone validation must retain this explicit distinction.

The clean-clone gate remains pending candidate-diff review and separate commit authorization. These scans do not cover the
actual host bundle/build outputs or every separate guest acceptance-evidence directory. Real target-root provisioning,
separate-VM reconstruction, fresh graphical observations and final private-provider acceptance also remain pending.
No product code changed during these validation/restoration slices and no VM/build/commit/push operation was performed.

## Task 4 continuation: committed candidate and independent graphical reconstruction

This chronological addendum supersedes the earlier pending commit/build/reconstruction statements only for the
checks recorded here. Task 4 remains in progress; final private-provider acceptance is not implied.

### Candidate, clean clone and build

The separately authorized host-local candidate commit is `dbbea4392c386dc9b6854de06fef2c1b10016016`, based on
`58523d5d9734249f08f9a3cf1e52de24be26552c`: 91 files, 8846 insertions and 60 deletions. Its message cites plan 02-17
and the approved Cloud CLI/Atuin scope expansion. No active-host integration or MirrorOS push was performed.
The preserved source bundle and clean-clone evidence are under HOST
`evidence/development-workbench/clean-clone/20261020T134300Z/`.

The clean-clone gate passed required files, modes, output/workflow-tooling absence, lifecycle syntax and ShellCheck,
and the explicitly approved bounded `bats --jobs 2 tests/operations/configure.contract.bats` selection (9/9).
This test-scope adjustment did not repeat the earlier successful full 64-test operations suite. Current source and
retained evidence scans reported zero findings. The exact-two historical-canary exception above remains explicit.
The maintainer also required preserving the original final blank line in
`capabilities/workflow/pi/defaults/prompts/ubiquitous-language.md`; the precommit full diff check returned native 2
solely for that reviewed whitespace exception, not a clean native 0. No scanner baseline or history rewrite was used.

The first candidate ISO build was interrupted by reported power loss and retained without destructive cleanup.
The separately authorized retry `20261020T152108Z-14d0df60-11c0-43bc-987c-b1691d583744` completed native 0 in 487 seconds,
with publication and cleanup successful. Bundle:
`build/workbench-candidate-dbbea439/dist/20261020T152108Z-14d0df60-11c0-43bc-987c-b1691d583744/`.
The ISO `mirroros-2026.10.20-x86_64.iso` SHA256 is
`5e40311157216d1fe62a21f3ea73ecd097385593a04a683adedd99c92a1b86d0`; all three bundle checksum entries passed.
Build wrapper evidence is under HOST `evidence/development-workbench/iso-build/20261020T152108Z/`.
Build success alone is not release or laptop qualification.

A preceding default reference development-overlay qualification also passed installation, target configure,
disk-only console login and first-boot checks in 663 seconds, with its owned disposable disk cleaned afterward.
It used the older base ISO and approved candidate overlay, was explicitly `counted=false`, and did not retain detailed
target configure records. It is not the persistent graphical reconstruction described next.

### Independent target and running evidence

The maintainer installed the new ISO in a separate VM, reported no installer errors, detached the ISO and confirmed
disk boot and graphical login. No laboratory home state was copied as the reconstruction input.
The installed identity independently reports clean `dbbea4392c386dc9b6854de06fef2c1b10016016`.

- Target run: `20261020T154914Z-e94712f6-b8cf-4923-b2e1-94cd354c2264`, context `target`, user `viespejo`,
  15:49:07 to 15:55:10 UTC, outcome 0, all eight steps changed with passed postconditions.
- Running run: `20261020T221800Z-397eec81-8777-4336-998d-a8858b652052`, same user and clean candidate,
  22:17:56 to 22:18:05 UTC, outcome 0, all eight steps unchanged with passed postconditions.
- Running records: HOST `evidence/development-workbench/graphical-reconstruction/20261020T221832Z-running/`.
- Complete target records: HOST `evidence/development-workbench/graphical-reconstruction/20261020T230856Z-target/`.

Only `configure-run.tsv`, `packages.tsv`, `sources.tsv` and `configure.log` were exported through attended sudo,
without changing the originals. The complete target export was scanned before diagnostic review:
`gitleaks dir <target-export> --redact --report-format json --report-path <target-export>/gitleaks-records.json`
returned native 0, zero findings, approximately 2.02 MB. The target TSV matches the previously reviewed copy exactly.

Comparison by package name confirms all 28 declared package versions and repositories match; row ordering differs.
All 20 common source rows match exactly. Target has 31 source rows: the additional Google Cloud CLI, six npm packages,
skills CLI and three skill-source rows describe fresh provisioning; running intentionally omits these changed/fresh-only
records when the SDK is satisfied and existing Pi configuration is preserved. This is not a claim that the complete
source TSVs are byte-identical.

Consumed identities include NVM v0.40.8 (`a885b885fef16fac4bc544188fb25e9e37ae83e8`), Node v24.22.0,
Pi 1.3.0 from the exact pi-config dependency, Neovim `bdf02dd9b726c215c31d3a64c6cb38e56bbdac58`,
pi-config `37ae549ae4de603ab0b9535e9a13187c9d257a26`, Sesh 2.33.0-1.1 and Google Cloud CLI 589.0.0.
Fresh external skill sources were mattpocock/skills `5beb35b040e3de97e54fa9e386d7e42d15c295c2`,
humanlayer/skills `653b6411c1f70c275a18e37673b042ff99f67ceb`, and
tt-a1i/archify `25cf37080fc8b1dbe758a4efc3935b55f3327083`.

The target log shows chroot-aware package hooks skipping system and user manager reloads and bus reloads;
SDDM is enabled but explicitly not started. The running log reports existing `.pi` preserved, no initialization
or installation transactions, and SDDM not started. No private-directory byte audit is implied.
Retained upstream diagnostics include tmux-thumbs Rust dead-code/lifetime warnings and npm deprecations for
`node-domexception@1.0.0` and `uuid@9.0.1`; successful outcomes do not constitute dependency vulnerability clearance.

### Attended workflows and accepted amendments

In the new VM the maintainer confirmed the requested Zsh/Tmux workflows, followed by Neovim startup without errors,
file/text search, completion, save, cross-application clipboard and Tmux pane navigation. Pi extension loading and
Shift+Enter inside Tmux work; the piw editor write/switch-buffer/return/save round-trip introduces no extra lines.
These are attended reported outcomes, not a retained private conversation or Task 5 acceptance.

The graphical checks exposed two approved additions absent from the built candidate:

- The complete portable Starship TOML was added to the isolated HOST `build/workbench-starship-amendment` source,
  with managed-file provisioning, postcondition, provenance and two extended contracts. The maintainer separately
  authorized replacing the guest TOML; its SHA256 matches the source:
  `a473360d7d8fb8f906c035f050d7ea49b44f2fe2dec06e880e9cda36cab51d4f`.
  This is an explicit post-install intervention, not proof the existing ISO ships the full prompt configuration.
- Session and greeter source defaults now declare keyboard `repeat_delay = 230` and `repeat_rate = 62`, with a contract
  and configure-procedure documentation. The guest change was runtime-only through the reviewed Hyprland API;
  no persistent installed compositor file was updated, so restart persistence is not yet demonstrated.

The maintainer accepted both source amendments. The two Starship contracts and one keyboard contract passed targeted
Bats selections; scoped source scans and changed-source static/whitespace checks passed as recorded in the execution
log. These amendments and this addendum remain uncommitted in the isolated amendment clone. No new ISO build, commit,
push or active-host integration is authorized by those acceptances. Candidate promotion, configure-based application
and rerun/persistence evidence remain pending before claiming complete declared reconstruction. Final Task 5 graphical
review and one privately authenticated real-provider conversation remain required; no credentials or conversation
content belong in retained evidence.

## Task 4 continuation: amendment application and greeter recovery

This chronological addendum supersedes the previous pending amendment-commit and application statements.
The separately authorized local commit `a3ab0039c15d640de81ca11c273cf8a9307fb62a`, parent `dbbea439`, contains
Starship, session/greeter repeat defaults, their contracts and the reconstruction documentation (eight files).
Bounded validation passed three affected Bats contracts, Bash syntax/ShellCheck, Lua syntax and isolated input
checks, TOML parsing, whitespace checks and zero-finding source/evidence scans. An initial supplemental Lua
fixture omitted an existing window-close API mock; it was corrected without changing product code.
HOST evidence and the verified bundle: `evidence/development-workbench/amendment-validation/20261020T231149Z/`.

The maintainer authorized transfer to a new clean guest checkout `~/code/mirroros-workbench-a3ab003` and two
attended running configure executions. Bundle hashes matched; no installed snapshot replacement occurred.
An initial bundle verification outside a Git repository stopped before cloning; verification in the new clone passed.
Run from that checkout with distinct output directories:
`sudo operations/configure --user viespejo --output <new-run-directory>`.

- First run `20261020T231454Z-16292285-f0bc-4c3c-adc7-493704ff0933`: clean `a3ab003`, outcome 0,
  compositor changed, the other seven steps unchanged, all postconditions passed.
- Second run `20261020T231504Z-03151ecd-7d4b-456d-aa07-ad72b4c96f0a`: same clean source, outcome 0,
  all eight steps unchanged with passed postconditions and no installation transactions.
- Package/source TSVs are byte-identical between runs and their mappings match the preceding `dbbea439` running run.
- Both logs report existing `.pi` preserved and SDDM not started. No private-directory byte audit was performed.
- HOST evidence: `evidence/development-workbench/amendment-application/20261020T231542Z/{first,second}/`.
  Its four-record-per-run export passed Gitleaks with zero findings before inspection (8137 bytes).
- On-disk Starship, user-session and greeter files matched `a3ab003`; the installed code snapshot deliberately
  remains clean `dbbea439`. Running configure from a new checkout does not replace that snapshot.

### Failed reentry and bounded A/B recovery

The maintainer logged out with Super+Shift+E and attempted graphical reentry. Authentication succeeded, but SDDM
immediately closed the new user session with helper status 63; the replacement greeter also exited 63.
The display showed a console login without working keyboard input. Kernel foreground-VT metadata did not match
the photographed console, and seat0 had no active session. This is not evidence of a keyboard-layout defect.
The user SDDM session diagnostic file was empty; bounded SDDM/logind/greeter journals did not establish a root cause.

The separately authorized SDDM-only restart at 01:20:31 CEST failed to recover the greeter. No package/provider switch
or repeated automatic restart was used. The maintainer then authorized one old-greeter A/B test with a protected backup:

- Saved the amended `/usr/share/mirroros/sddm/hyprland.lua` exclusively to
  `/usr/share/mirroros/sddm/hyprland.lua.before-ab-a3ab003`, root-owned mode 0600.
- Restored only that active greeter file from the unchanged installed `dbbea439` snapshot, with type/hash guards
  and atomic publication. Its SHA256 is `7facc9395965adad93096900969cfee087b2bdb696e2c6493b2fb2d4f68d8c74`.
- Restarted SDDM once at 01:22:30 CEST. The greeter appeared; the maintainer subsequently logged in successfully.
- The user-session configuration remained byte-identical to `a3ab003`. Fresh Wayland session 75 on VT7 was active;
  `hyprctl -i 0 getoption input:repeat_delay` and `input:repeat_rate` reported 230 and 62, both explicitly set.

The maintainer accepted this recovery. The A/B observation associates recovery with the old greeter configuration,
but does not isolate either repeat field or prove a general upstream cause. No bad-configuration replay was performed.

### Reviewed source correction, not yet committed

The maintainer authorized removing both explicit repeat fields only from the greeter in the isolated source clone,
retaining user-session 230/62, Compose, shared layout resolution and all bindings. The greeter now exactly matches
the tested old-file SHA256 above. The contract requires repeat values in the session and their absence in the greeter.
It failed against `a3ab003` as expected, then passed after the minimal correction. `luac -p` and isolated Lua checks
confirm both input policies. HOST diagnostic evidence:
`evidence/development-workbench/greeter-correction/20261020T232415Z/`.

The correction and these documentation updates remain uncommitted. They have not been applied through configure in
the VM; its greeter is still the deliberately restored A/B file. Do not rerun uncorrected `a3ab003` configure: it would
reapply the failing greeter variant. Further commit, deployment or service/session restart needs separate authorization.
The ISO still contains `dbbea439`; no rebuild, push or active-host integration occurred. Final reconstruction evidence
must distinguish the original ISO, explicit checkout-based updates and this diagnostic intervention. Task 4 and the
Task 5 final graphical/private-provider gate remain open.

## Task 4 continuation: committed greeter correction and converged application

This addendum supersedes only the preceding uncommitted/undeployed correction status. The maintainer separately
approved local commit `51ab92c3fa911be685eaa0cc972c0343794adf47`, parent `a3ab003`, containing the four reviewed
correction/test/documentation files. The isolated HOST checkout is `build/workbench-starship-amendment`.
The verified bundle and commit evidence remain under
`evidence/development-workbench/greeter-correction/20261020T232415Z/`. No push or active-host integration occurred.

The maintainer separately authorized transfer to the new guest checkout `~/code/mirroros-workbench-51ab92c`
and two privately attended running configure executions, without replacing the installed snapshot or restarting
services/sessions. The transferred bundle matched its HOST SHA256; the checkout was clean at the exact commit.

- First run: `20261020T232801Z-8058fe77-6c9b-498e-86ba-453d1fbd3928`.
- Second run: `20261020T232811Z-548dffc4-fd61-4053-9b98-c83445565b04`.
- Both record clean `51ab92c`, running context, outcome 0, all eight steps unchanged and all postconditions passed.
- Both complete logs report existing `.pi` preserved, no installation transactions and SDDM not started.
- Package/source TSVs are byte-identical between runs; mappings also match the preceding `a3ab003` application.
- Persistent Starship, user-session Hyprland and greeter files match corrected source. The restored A/B greeter
  is now the declared product result, not an outstanding configuration divergence.
- The active compositor reports repeat delay 230 and rate 62. Configure did not restart SDDM; this is not a new
  logout/reentry test after corrected application. No private `.pi` content audit was performed.
- HOST evidence: `evidence/development-workbench/corrected-application/20261020T232841Z/{first,second}/`.
  The allowlisted records passed redacted Gitleaks with zero findings before review (7908 bytes).

The maintainer accepted this application/rerun evidence without manual amendments. The installed snapshot and
original target installation remain `dbbea439`; corrected running configuration comes from the explicit checkout
update path. Do not describe this as target provisioning directly from `51ab92c` or an amended ISO reconstruction.
Final clean-clone validation, resolution of that target/corrected-source evidence gap, whole-Task-4 review and the
Task 5 attended graphical/private-provider gate remain pending. This documentation update authorizes no additional
commit, build, VM/target operation, service restart, push or active-host integration.

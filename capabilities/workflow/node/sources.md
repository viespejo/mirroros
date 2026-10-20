# Node.js runtime sources and ownership boundaries

## User runtime declaration

`environment.zsh` is the single MirrorOS declaration of the user's Node.js version
(`MIRROROS_NODE_VERSION`, initially `v24.22.0`) and of the portable PATH entries. Interactive
Zsh sources it so the selected version's bin directory is on PATH without loading NVM.
`nvm_load` loads `nvm.sh` and its completion only on demand. Provisioning reads the same
declaration through `cfg_node_version`; no second version list exists. Runtime updates are
explicit MirrorOS changes, not startup-time probes or background synchronization.

The file follows the managed-file policy: an absent or marked file is installed or updated;
an unmarked file or symbolic link is user-owned and left untouched. Provisioning still uses
the MirrorOS declaration in that case. Non-interactive consumers add the same bin directory
to their command environment explicitly; they do not source NVM or Zsh startup files.

## NVM installation

- Upstream: https://github.com/nvm-sh/nvm, MIT, copyright Tim Caswell (2010) and Jordan
  Harband (2014). Its notices stay upstream-owned; nothing here relicenses NVM or Node.js.
- Release: `v0.40.8`; tag object `8db529c5350353f165e1e7f6abb6eb6909f7fd37`; commit
  `a885b885fef16fac4bc544188fb25e9e37ae83e8`.
- Installer: `https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.8/install.sh`, SHA-256
  `48a0eee9a60e07422dce0eb5774754c83889570ca1ee2566c516acbe8af03a9e`. This is the
  content identity of the Git object at that tag, not an upstream signature.
- Options: `PROFILE=/dev/null` (no profile editing) and `NVM_INSTALL_VERSION=v0.40.8`.

The installer source was reviewed during development; configure performs only automated
checks. `install-nvm` runs as the target user, downloads over HTTPS, refuses a checksum
mismatch before executing anything, builds NVM in a unique sibling staging directory, verifies
the commit and publishes `~/.nvm` only if the path is still absent. It removes only its own
staging directory. An existing `~/.nvm` that is not this unmodified release is never
overwritten: if the selected Node.js is already present it is accepted, otherwise configure
fails and asks for manual resolution.

## Node.js

NVM installs the declared version from nodejs.org and verifies its published checksums. The
installed `node --version` must equal the declaration. Satisfied runtimes cause no download,
and no network probe happens when a shell starts. Installer-environment Node.js remains a
separate live-ISO concern; the future independent `verify` runtime is not decided here.

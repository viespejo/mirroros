# managed by MirrorOS configure
# Single declaration of the user Node.js runtime. The selected version's bin directory is put on PATH
# directly; NVM itself is only loaded on demand through nvm_load.
export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
MIRROROS_NODE_VERSION=v24.22.0

typeset -U path
path=("$HOME/.local/bin" "$NVM_DIR/versions/node/$MIRROROS_NODE_VERSION/bin" $path)

nvm_load() {
  [[ -s "$NVM_DIR/nvm.sh" ]] && . "$NVM_DIR/nvm.sh"
  [[ -s "$NVM_DIR/bash_completion" ]] && . "$NVM_DIR/bash_completion"
}

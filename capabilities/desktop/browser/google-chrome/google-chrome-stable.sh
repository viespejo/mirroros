#!/bin/bash
# managed by MirrorOS configure

XDG_CONFIG_HOME=${XDG_CONFIG_HOME:-~/.config}

# Allow users to override command-line options.
if [[ -f $XDG_CONFIG_HOME/chrome-flags.conf ]]; then
    CHROME_USER_FLAGS="$(grep -v '^#' "$XDG_CONFIG_HOME/chrome-flags.conf")"
fi

# Keep the AUR launcher's whitespace-separated flags without pathname expansion.
set -f
# shellcheck disable=SC2086
exec /opt/google/chrome/google-chrome --password-store=gnome-libsecret ${CHROME_USER_FLAGS:-} "$@"

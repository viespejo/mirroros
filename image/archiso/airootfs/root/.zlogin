~/.automated_script.sh

# MirrorOS guided installer welcome on tty1; returns to the shell when it ends
if [[ -x /usr/local/lib/mirroros/install/confirmation/live-startup ]]; then
    /usr/local/lib/mirroros/install/confirmation/live-startup
fi

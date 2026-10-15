-- managed by MirrorOS configure
hl.config({
    input = { kb_layout = require("/usr/share/mirroros/hypr/keyboard.lua") },
})

hl.bind("SUPER + Return", hl.dsp.exec_cmd("uwsm app -- foot"))
hl.bind("SUPER + SHIFT + Q", hl.dsp.window.close())
hl.bind("SUPER + SHIFT + E", hl.dsp.exec_cmd("uwsm stop"))

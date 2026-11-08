-- managed by MirrorOS configure
-- Omarchy 4.0.6 chords and options; owned commands isolate hardware providers (see UPSTREAM.md).
local hardware = "/usr/share/mirroros/hardware/"
local function action(command)
    return hl.dsp.exec_cmd(hardware .. command)
end

MirrorOSKeys.bind("audio.raise", "XF86AudioRaiseVolume", "Volume up", action("volume raise"), { locked = true, repeating = true })
MirrorOSKeys.bind("audio.lower", "XF86AudioLowerVolume", "Volume down", action("volume lower"), { locked = true, repeating = true })
MirrorOSKeys.bind("audio.mute", "XF86AudioMute", "Mute", action("volume mute-toggle"), { locked = true })
MirrorOSKeys.bind("audio.output-switch", "SHIFT + XF86AudioMute", "Switch audio output", action("audio-device cycle"), { locked = true })
MirrorOSKeys.bind("audio.mic-mute", "XF86AudioMicMute", "Mute microphone", action("volume mic-mute"), { locked = true })
MirrorOSKeys.bind("audio.raise-precise", "ALT + XF86AudioRaiseVolume", "Volume up precise", action("volume +1"), { locked = true, repeating = true })
MirrorOSKeys.bind("audio.lower-precise", "ALT + XF86AudioLowerVolume", "Volume down precise", action("volume -1"), { locked = true, repeating = true })
MirrorOSKeys.bind("brightness.raise", "XF86MonBrightnessUp", "Brightness up", action("brightness +5%"), { locked = true, repeating = true })
MirrorOSKeys.bind("brightness.lower", "XF86MonBrightnessDown", "Brightness down", action("brightness 5%-"), { locked = true, repeating = true })
MirrorOSKeys.bind("brightness.max", "SHIFT + XF86MonBrightnessUp", "Brightness maximum", action("brightness max"), { locked = true, repeating = true })
MirrorOSKeys.bind("brightness.min", "SHIFT + XF86MonBrightnessDown", "Brightness minimum", action("brightness min"), { locked = true, repeating = true })
MirrorOSKeys.bind("brightness.raise-precise", "ALT + XF86MonBrightnessUp", "Brightness up precise", action("brightness +1%"), { locked = true, repeating = true })
MirrorOSKeys.bind("brightness.lower-precise", "ALT + XF86MonBrightnessDown", "Brightness down precise", action("brightness 1%-"), { locked = true, repeating = true })
MirrorOSKeys.bind("media.next", "XF86AudioNext", "Next track", action("media next"), { locked = true })
MirrorOSKeys.bind("media.next-alt", "ALT + XF86AudioPlay", "Next track", action("media next"), { locked = true })
MirrorOSKeys.bind("media.pause", "XF86AudioPause", "Pause", action("media play-pause"), { locked = true })
MirrorOSKeys.bind("media.play", "XF86AudioPlay", "Play", action("media play-pause"), { locked = true })
MirrorOSKeys.bind("media.previous", "XF86AudioPrev", "Previous track", action("media previous"), { locked = true })
MirrorOSKeys.bind("media.previous-alt", "ALT + SHIFT + XF86AudioPlay", "Previous track", action("media previous"), { locked = true })

MirrorOSKeys.bind("display.laptop", "SUPER + CTRL + Delete", "Toggle laptop display", action("display laptop"))
MirrorOSKeys.bind("display.mirror", "SUPER + CTRL + ALT + Delete", "Toggle laptop display mirroring", action("display mirror"))
MirrorOSKeys.bind("display.scale-up", "SUPER + slash", "Increase monitor scale", action("display scale up"))
MirrorOSKeys.bind("display.scale-down", "SUPER + ALT + slash", "Decrease monitor scale", action("display scale down"))
MirrorOSKeys.bind("display.lid-close", "switch:on:Lid Switch", "Clamshell close", action("display clamshell close"), { locked = true, launchable = false })
MirrorOSKeys.bind("display.lid-open", "switch:off:Lid Switch", "Clamshell open", action("display clamshell open"), { locked = true, launchable = false })

if not MirrorOSKeys.staged then MirrorOSKeys.export() end

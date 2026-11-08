import Quickshell
import Quickshell.Hyprland
import qs.Commons

import "services"
import "menu"
import "bar"
import "notifications" as Notifications
import "osd"

// MirrorOS desktop shell entry point. Composes the shell surfaces directly;
// there is no plugin host. Shared services are created here and injected
// into the surfaces that use them (the same injection pattern Omarchy's
// shell.qml uses, without its plugin registry).
ShellRoot {
  id: desktopShell

  property AppLibrary appLibrary: AppLibrary { }
  property SessionActions sessionActions: SessionActions { }
  property KeybindingHelp keybindingHelp: KeybindingHelp { }
  property ShellConfig shellConfigStore: ShellConfig { }
  readonly property var shellConfig: shellConfigStore.shellConfig
  property Notifications.Service notificationService: Notifications.Service {
    shell: desktopShell
  }
  property Osd osdService: Osd { }
  property WallpaperLibrary wallpaperLibrary: WallpaperLibrary { }
  property WallpaperActions wallpaperActions: WallpaperActions {
    picker: desktopShell.wallpaperPicker
    library: desktopShell.wallpaperLibrary
    wallpaper: desktopShell.wallpaper
    notifications: desktopShell.notificationService
  }
  property Wallpaper wallpaper: Wallpaper {
    onSelectorRequested: function(output) { desktopShell.wallpaperActions.openPicker(output) }
  }
  property WallpaperPicker wallpaperPicker: WallpaperPicker {
    images: desktopShell.wallpaperLibrary.images
    onSelected: function(path) { desktopShell.wallpaperActions.selectPath(path) }
  }

  property Bar bar: Bar {
    shell: desktopShell
    barConfig: desktopShell.shellConfigStore.barConfig
  }

  function mutateShellConfig(mutator) {
    return shellConfigStore.mutateShellConfig(mutator)
  }

  function updateEntryInline(id, settings) {
    return shellConfigStore.updateEntryInline(id, settings)
  }

  function firstPartyServiceFor(id) {
    return id === "omarchy.notifications" ? notificationService : null
  }

  function toggle(id) {
    if (id !== "menu") return false
    menu.opened ? menu.cancel() : menu.openRoute("root")
    return true
  }

  function summon(id, json) {
    if (id !== "omarchy.osd" || !osdService) return false
    osdService.open(json)
    return true
  }

  // Panel keys reach the shell through Hyprland's global dispatcher
  // (hl.dsp.global("mirroros:<name>")), so a keypress spawns no process. Modeled
  // on Omarchy v4.5.0 shell/shell.qml GlobalShortcut usage, without its
  // shortcuts file. The panel chords toggle with the bar's focused-monitor
  // routing; panel-at-N toggles the Nth panel of the right section.
  GlobalShortcut {
    appid: "mirroros"
    name: "panel.audio"
    description: "Toggle the audio panel"
    onPressed: desktopShell.bar.requestPanel("omarchy.audio", "toggle")
  }
  GlobalShortcut {
    appid: "mirroros"
    name: "panel.display"
    description: "Toggle the display panel"
    onPressed: desktopShell.bar.requestPanel("omarchy.monitor", "toggle")
  }
  GlobalShortcut {
    appid: "mirroros"
    name: "panel.power"
    description: "Toggle the power panel"
    onPressed: desktopShell.bar.requestPanel("omarchy.power", "toggle")
  }
  GlobalShortcut {
    appid: "mirroros"
    name: "panel.notifications"
    description: "Toggle the notification panel"
    onPressed: desktopShell.notificationService.requestPanel("toggle")
  }
  Variants {
    model: [1, 2, 3, 4, 5, 6, 7, 8, 9]
    GlobalShortcut {
      required property var modelData
      appid: "mirroros"
      name: "panel-at-" + modelData
      description: "Toggle bar panel " + modelData
      onPressed: desktopShell.bar.togglePanelAt("right", modelData)
    }
  }

  Menu {
    id: menu
    appLibrary: desktopShell.appLibrary
    sessionActions: desktopShell.sessionActions
    keybindingHelp: desktopShell.keybindingHelp
    wallpaperActions: desktopShell.wallpaperActions
  }
}

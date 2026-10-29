import Quickshell
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

  Menu {
    id: menu
    appLibrary: desktopShell.appLibrary
    sessionActions: desktopShell.sessionActions
    keybindingHelp: desktopShell.keybindingHelp
    wallpaperActions: desktopShell.wallpaperActions
  }
}

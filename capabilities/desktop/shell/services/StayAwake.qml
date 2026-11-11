import QtQuick
import Quickshell
import Quickshell.Wayland

// MirrorOS Stay Awake service. New code; behavior reference: the Omarchy
// v4.5.0 (ac2690cd7be4f47e4a255f5e2e78d904d436b068) StayAwake indicator.
//
// One native Wayland idle inhibitor while the toggle is on. The state lives in
// memory only and is off on every shell start; nothing is read from or written
// to disk and no process is started. hypridle keeps owning idle detection and
// locking: it honours the inhibitor, so only the idle lock is suspended, while
// lock-session and lock before sleep are unchanged. The shell binds `window`
// to a live bar window, so the inhibitor follows a visible surface.
QtObject {
  id: root

  property bool enabled: false
  property var window: null

  function toggle() {
    root.enabled = !root.enabled
  }

  property IdleInhibitor inhibitor: IdleInhibitor {
    enabled: root.enabled && !!root.window
    window: root.window
  }
}

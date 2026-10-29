import test from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'

const surface = readFileSync('capabilities/desktop/shell/Wallpaper.qml', 'utf8')
const shell = readFileSync('capabilities/desktop/shell/shell.qml', 'utf8')
const actions = readFileSync('capabilities/desktop/shell/services/WallpaperActions.qml', 'utf8')

test('wallpaper shares the reference reveal and starts on the first ready panel', () => {
  assert.match(surface, /property string displayedBackground: ""/)
  assert.match(surface, /panel.maskReady = true/)
  assert.match(surface, /revealStartedVersion === backgroundVersion/)
  assert.match(surface, /duration: 420/)
  assert.match(surface, /easing.type: Easing.InOutCubic/)
  assert.match(surface, /readonly property real slant: -0.18/)
  assert.match(surface, /maskSource: revealMask/)
  assert.doesNotMatch(surface + actions, /loadTimeout|displayTimeout|imageRejected|imageDisplayed|requestGeneration|fallback|WallpaperSelection/)
})

test('composition uses link-backed actions without the discarded JSON state', () => {
  assert.match(shell, /wallpaper: desktopShell.wallpaper/)
  assert.match(shell, /images: desktopShell.wallpaperLibrary.images/)
  assert.match(actions, /\["readlink", "-f", root.backgroundLink\]/)
  assert.match(actions, /if \(code === 0\) root.display\(setterOutput.text\)/)
  assert.doesNotMatch(shell + actions, /WallpaperState|function status|\/usr\/share\/mirroros\/backgrounds/)
})

test('double left-click works even with no decoded startup background', () => {
  assert.match(surface, /acceptedButtons: Qt.LeftButton/)
  assert.match(surface, /root.selectorRequested\(panel.modelData\)/)
  assert.match(surface, /visible: !remapGuard.remapping/)
  assert.match(surface, /color: "transparent"/)
  assert.doesNotMatch(surface, /Qt.RightButton|openThemeSwitcher/)
})

test('background surfaces retain remapping, updates, no focus and no exclusion', () => {
  for (const pattern of [/model: Quickshell.screens/, /ScreenMoveRemap/, /updatesEnabled: true/,
    /WlrLayershell.layer: WlrLayer.Background/, /WlrLayershell.keyboardFocus: WlrKeyboardFocus.None/,
    /exclusionMode: ExclusionMode.Ignore/, /fillMode: Image.PreserveAspectCrop/]) assert.match(surface, pattern)
})

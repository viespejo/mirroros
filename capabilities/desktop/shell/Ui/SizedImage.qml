import QtQuick

// Adapted from Omarchy 520c3ed969d30b58defe03eb19d603f32b4cb002
// shell/Ui/SizedImage.qml (MIT, Copyright (c) David Heinemeier Hansson).
// PNG-only fitted clipboard previews: bounded raster decode and placement;
// no crop, SVG, alignment modes or thin-image retry state.
Item {
  id: root
  property url url: ""

  Image {
    id: image
    readonly property real placedScale: implicitWidth > 0 && implicitHeight > 0
      ? Math.min(root.width / implicitWidth, root.height / implicitHeight) : 0
    width: implicitWidth * placedScale
    height: implicitHeight * placedScale
    anchors.centerIn: parent
    source: root.width > 0 && root.height > 0 ? root.url : ""
    sourceSize.width: Math.max(1, Math.ceil(root.width * Screen.devicePixelRatio))
    sourceSize.height: Math.max(1, Math.ceil(root.height * Screen.devicePixelRatio))
    fillMode: Image.Stretch
    asynchronous: true
    smooth: true
  }
}

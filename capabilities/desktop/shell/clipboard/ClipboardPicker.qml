pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Wayland
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "ClipboardHistoryModel.js" as History

// Adapted from Omarchy 520c3ed969d30b58defe03eb19d603f32b4cb002
// shell/plugins/clipboard/Clipboard.qml (MIT, Copyright (c) David Heinemeier
// Hansson). MirrorOS components and command service replace the JSON store,
// capture/watch processes and paste actions. Enter is copy-only.
Item {
  id: root

  required property var service
  property bool opened: false
  property string filterText: ""
  property int selectedIndex: 0
  property bool clearConfirmOpen: false
  readonly property var rows: History.displayRows(service.history, filterText, I18n.t("clipboard.image"))
  readonly property var activeRow: rows.length ? rows[selectedIndex] : null
  readonly property color background: Commons.Color.menu.background
  readonly property color foreground: Commons.Color.menu.text
  readonly property color selectedBackground: Commons.Color.menu.selectedBackground
  readonly property color selectedText: Commons.Color.menu.selectedText
  readonly property int contentMargin: Style.spacing.panelPadding
  readonly property int headerHeight: Math.max(Style.space(34), Style.font.title + Style.spacing.controlPaddingY * 2)
  readonly property int rowHeight: Math.max(Style.space(50), Style.font.body + Style.font.caption + Style.spacing.rowPaddingX * 2)

  function open() {
    if (root.opened) return
    root.filterText = ""
    filterInput.text = ""
    root.selectedIndex = 0
    root.clearConfirmOpen = false
    pointerGate.reset()
    root.opened = true
    root.service.open()
    Qt.callLater(function() { filterInput.forceActiveFocus() })
  }

  function close() {
    root.opened = false
    root.clearConfirmOpen = false
    root.filterText = ""
    filterInput.text = ""
    root.service.close()
  }

  function toggle() {
    if (root.opened) root.close()
    else root.open()
  }

  function setFilter(value) {
    root.filterText = value
    if (filterInput.text !== value) filterInput.text = value
    root.selectedIndex = 0
    pointerGate.reset()
  }

  function select(value, absolute) {
    root.selectedIndex = History.selection(root.selectedIndex, root.rows.length, value, absolute)
    pointerGate.reset()
    resultList.positionViewAtIndex(root.selectedIndex, ListView.Contain)
  }

  function activate(name) {
    if (root.activeRow && root.service.act(name, root.activeRow.id)) root.close()
  }

  function requestVisiblePreviews() {
    if (!root.opened) return
    if (root.activeRow && root.activeRow.image) root.service.requestPreview(root.activeRow.id)
    var first = Math.max(0, Math.floor(resultList.contentY / root.rowHeight))
    var last = Math.min(root.rows.length, Math.ceil((resultList.contentY + resultList.height) / root.rowHeight))
    for (var i = first; i < last; i++) {
      if (root.rows[i].image) root.service.requestPreview(root.rows[i].id)
    }
  }

  onSelectedIndexChanged: Qt.callLater(root.requestVisiblePreviews)
  onRowsChanged: {
    root.selectedIndex = History.selection(root.selectedIndex, root.rows.length, 0, false)
    Qt.callLater(root.requestVisiblePreviews)
  }

  Connections {
    target: root.service
    function onBusyChanged() { Qt.callLater(root.requestVisiblePreviews) }
  }

  PointerMoveGate { id: pointerGate; referenceItem: card }

  OverlayWindow {
    id: panel
    shown: root.opened
    WlrLayershell.namespace: "mirroros-clipboard"

    Rectangle { anchors.fill: parent; color: Commons.Color.menu.scrim }
    MouseArea { anchors.fill: parent; onClicked: root.close() }

    BorderSurface {
      id: card
      width: Math.min(Style.space(875), panel.width - Style.gapsOut * 2)
      height: Math.min(Style.space(600), panel.height - Style.gapsOut * 2)
      anchors.centerIn: parent
      radius: Style.cornerRadius
      color: root.background
      borderSpec: Border.surfaceSpec("menu", "border", Commons.Color.menu.border, Math.max(1, Style.space(2)))
      padding: root.contentMargin

      MouseArea { anchors.fill: parent; onClicked: {} }

      Item {
        id: keyCatcher
        Keys.onPressed: function(event) {
          if (root.clearConfirmOpen) {
            clearConfirm.handleKey(event)
            event.accepted = true
            return
          }
          if (event.key === Qt.Key_Escape) {
            if (root.filterText) root.setFilter("")
            else root.close()
          } else if (event.key === Qt.Key_Delete) {
            if (event.modifiers & Qt.ShiftModifier) {
              if (!root.service.busy && root.service.history.length) {
                clearConfirm.selectedIndex = 0
                root.clearConfirmOpen = true
              }
            } else if (root.activeRow) root.service.act("delete", root.activeRow.id)
          } else if (event.key === Qt.Key_Up) root.select(-1, false)
          else if (event.key === Qt.Key_Down) root.select(1, false)
          else if (event.key === Qt.Key_PageUp) root.select(-6, false)
          else if (event.key === Qt.Key_PageDown) root.select(6, false)
          else if (event.key === Qt.Key_Home) root.select(0, true)
          else if (event.key === Qt.Key_End) root.select(root.rows.length - 1, true)
          else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            if (!(event.modifiers & (Qt.ShiftModifier | Qt.ControlModifier | Qt.MetaModifier)))
              root.activate(event.modifiers & Qt.AltModifier ? "open" : "copy")
          } else {
            event.accepted = false
            return
          }
          event.accepted = true
        }
      }

      Column {
        anchors.fill: parent
        anchors.topMargin: card.contentTopInset
        anchors.rightMargin: card.contentRightInset
        anchors.bottomMargin: card.contentBottomInset
        anchors.leftMargin: card.contentLeftInset
        spacing: Style.spacing.md

        Item {
          width: parent.width
          height: root.headerHeight
          FilterInput {
            id: filterInput
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            keyHandler: keyCatcher
            color: root.foreground
            font.family: Style.font.menuFamily
            font.pixelSize: Style.font.heading
            onTextChanged: if (text !== root.filterText) root.setFilter(text)
          }
          Text {
            anchors.fill: filterInput
            textFormat: Text.PlainText
            text: I18n.t("clipboard.search")
            visible: !filterInput.text && !filterInput.preeditText
            color: root.foreground
            opacity: 0.58
            font.family: Style.font.menuFamily
            font.pixelSize: Style.font.heading
            verticalAlignment: Text.AlignVCenter
          }
        }

        Item {
          width: parent.width
          height: parent.height - root.headerHeight - Style.spacing.md
          ListView {
            id: resultList
            width: parent.width / 2 - root.contentMargin
            height: parent.height
            clip: true
            model: root.rows
            boundsBehavior: Flickable.StopAtBounds
            onContentYChanged: Qt.callLater(root.requestVisiblePreviews)
            onHeightChanged: Qt.callLater(root.requestVisiblePreviews)
            delegate: Rectangle {
              id: row
              required property int index
              required property var modelData
              width: resultList.width
              height: root.rowHeight
              radius: Style.cornerRadius
              color: index === root.selectedIndex ? root.selectedBackground : "transparent"

              SizedImage {
                id: thumbnail
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: row.modelData.image ? root.rowHeight : 0
                height: root.rowHeight
                url: root.opened && row.modelData.image ? Util.fileUrl(root.service.previews[row.modelData.id] || "") : ""
              }
              Text {
                anchors.left: thumbnail.right
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.margins: Style.space(10)
                textFormat: Text.PlainText
                text: row.modelData.label
                color: row.index === root.selectedIndex ? root.selectedText : root.foreground
                font.family: Style.font.menuFamily
                font.pixelSize: Style.font.title
                elide: Text.ElideRight
              }
              MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onPositionChanged: function(mouse) {
                  if (!root.clearConfirmOpen && pointerGate.moved(row, mouse)) root.selectedIndex = row.index
                }
                onClicked: {
                  if (root.clearConfirmOpen) return
                  root.selectedIndex = row.index
                  root.activate("copy")
                }
              }
            }
          }
          Item {
            anchors.left: parent.horizontalCenter
            anchors.right: parent.right
            height: parent.height
            clip: true
            Text {
              anchors.fill: parent
              textFormat: Text.PlainText
              visible: !!root.activeRow && !root.activeRow.image
              text: root.activeRow ? root.activeRow.text : ""
              color: root.foreground
              font.family: Style.font.menuFamily
              font.pixelSize: Style.font.title
              wrapMode: Text.WrapAnywhere
              elide: Text.ElideRight
            }
            SizedImage {
              anchors.fill: parent
              url: root.opened && root.activeRow && root.activeRow.image ? Util.fileUrl(root.service.previews[root.activeRow.id] || "") : ""
            }
          }
          Text {
            anchors.centerIn: parent
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            textFormat: Text.PlainText
            visible: root.service.failed || root.service.loading || !root.rows.length
            text: root.service.failed ? "Could not read or update clipboard history. Reopen to retry."
              : root.service.loading ? "Loading…"
              : !root.service.history.length ? I18n.t("clipboard.empty") : I18n.t("common.noMatchesFor").arg(root.filterText)
            color: root.foreground
            font.family: Style.font.menuFamily
            font.pixelSize: Style.font.title
            wrapMode: Text.WordWrap
          }
        }
      }

      ConfirmDialog {
        id: clearConfirm
        anchors.fill: parent
        opened: root.clearConfirmOpen
        message: I18n.t("clipboard.deleteHistory")
        confirmText: I18n.t("common.delete")
        background: root.background
        foreground: root.foreground
        selectedBackground: root.selectedBackground
        selectedText: root.selectedText
        onCanceled: {
          root.clearConfirmOpen = false
          Qt.callLater(function() { filterInput.forceActiveFocus() })
        }
        onConfirmed: {
          if (root.service.act("clear", "")) root.clearConfirmOpen = false
          Qt.callLater(function() { filterInput.forceActiveFocus() })
        }
      }
    }
  }
}

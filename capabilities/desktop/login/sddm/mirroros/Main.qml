// MirrorOS SDDM theme (ADR 0014, layout under ADR 0021). Presentation only: SDDM authenticates through its own PAM service when
// sddm.login() is called and starts the configured session. This file runs no process, reads no system file other
// than the greeter layout state file (ADR 0015), and never logs or stores the typed password. Context objects (config, sddm, userModel, sessionModel, keyboard) are
// provided by sddm-greeter.
pragma ComponentBehavior: Bound
import QtQuick
import "LoginModel.js" as LoginModel

Rectangle {
    id: root

    readonly property color foreground: config.foreground
    readonly property color failure: config.failure
    readonly property color fieldColor: config.field
    readonly property string fontFamily: config.font
    readonly property string layoutStatePath: config.layoutState || ""
    readonly property string layoutHint: config.layoutHint || ""
    property var userNames: []
    property var userLabels: []
    property var sessionFiles: []
    property int userIndex: -1
    property bool userChosen: false
    property bool pending: false
    property bool failed: false
    property bool selecting: false
    property bool powerOpen: false
    property string powerAction: ""
    readonly property bool canRestart: sddm.canReboot === true
    readonly property bool canShutDown: sddm.canPowerOff === true
    readonly property bool powerAvailable: canRestart || canShutDown
    readonly property bool powerActionAvailable: powerAction === "restart" ? canRestart
                                               : powerAction === "shutdown" ? canShutDown : false
    onPowerAvailableChanged: if (!powerAvailable && powerOpen) closePower()
    property string stateLayout: ""
    property int stateMisses: 0
    readonly property int session: LoginModel.sessionIndex(sessionFiles, config.session)
    readonly property string reason: LoginModel.unavailableReason(userIndex, session)
    readonly property string layout: LoginModel.layoutLabel(layoutNames(), keyboard ? keyboard.currentLayout : -1,
                                                             stateLayout || config.keyboardLayout)

    width: 1280
    height: 800
    color: config.background
    Keys.onEscapePressed: event => {
        if (root.powerOpen) root.closePower();
        else event.accepted = false;
    }

    function layoutNames() {
        var names = [];
        var layouts = keyboard ? keyboard.layouts : [];
        for (var i = 0; layouts && i < layouts.length; i++)
            names.push(layouts[i] ? layouts[i].longName : "");
        return names;
    }

    function refresh() {
        var names = [], labels = [], files = [];
        for (var i = 0; i < users.count; i++) {
            var user = users.itemAt(i) as UserEntry;
            if (!user) continue;
            names.push(user.name);
            labels.push(LoginModel.displayName(user.name, user.realName));
        }
        for (var j = 0; j < sessions.count; j++) {
            var entry = sessions.itemAt(j) as SessionEntry;
            if (entry) files.push(entry.file);
        }
        userNames = names;
        userLabels = labels;
        sessionFiles = files;
        if (!userChosen || userIndex >= names.length)
            userIndex = LoginModel.initialUserIndex(names, userModel.lastUser);
    }

    // The greeter compositor records the active layout; polling stops after repeated absence (ADR 0015).
    function readLayoutState() {
        if (!layoutStatePath) return;
        var request = new XMLHttpRequest();
        request.onreadystatechange = function() {
            if (request.readyState !== XMLHttpRequest.DONE) return;
            var label = LoginModel.stateLabel(request.responseText);
            root.stateMisses = label === "" ? root.stateMisses + 1 : 0;
            if (label !== "" || root.stateMisses >= 10) root.stateLayout = label;
        };
        request.open("GET", "file://" + layoutStatePath);
        request.send();
    }

    Timer {
        interval: 300
        repeat: true
        triggeredOnStart: true
        running: root.stateMisses < 10
        onTriggered: root.readLayoutState()
    }

    function chooseUser(index) {
        if (pending) return;
        if (index >= 0 && index < userNames.length) {
            userIndex = index;
            userChosen = true;
        }
        password.clear();
        failed = false;
        selecting = false;
        password.forceActiveFocus();
    }

    function openSelector() {
        if (pending || powerOpen || userNames.length < 2) return;
        selector.currentIndex = Math.max(userIndex, 0);
        selecting = true;
        selector.forceActiveFocus();
    }

    function submit() {
        if (powerOpen || !LoginModel.canSubmit(userIndex, session, pending, password.text)) return;
        pending = true;
        failed = false;
        sddm.login(userNames[userIndex], password.text, session);
    }

    // ADR 0016: only SDDM's native power proxy is used, after explicit confirmation.
    function openPower() {
        if (pending || !powerAvailable) return;
        selecting = false;
        password.clear();
        powerAction = "";
        powerOpen = true;
        if (canRestart) restartButton.forceActiveFocus();
        else shutdownButton.forceActiveFocus();
    }

    function closePower() {
        powerOpen = false;
        powerAction = "";
        if (powerAvailable && !pending) powerButton.forceActiveFocus();
        else password.forceActiveFocus();
    }

    function selectPower(action) {
        if (pending || !powerOpen) return;
        if (action !== "restart" && action !== "shutdown") return;
        if (action === "restart" ? !canRestart : !canShutDown) return;
        powerAction = action;
        cancelButton.forceActiveFocus();
    }

    function confirmPower() {
        if (pending || !powerOpen || !powerActionAvailable) return;
        var action = powerAction;
        closePower();
        if (action === "restart") sddm.reboot();
        else sddm.powerOff();
    }

    Connections {
        target: sddm
        function onLoginFailed() {
            root.pending = false;
            root.failed = true;
            password.clear();
            password.forceActiveFocus();
        }
        function onLoginSucceeded() {
            password.clear();
        }
    }

    // Native models are read through delegates so their role names, not role numbers, are used.
    component UserEntry: Item {
        required property string name
        required property string realName
    }
    component SessionEntry: Item {
        required property string file
    }

    Item {
        visible: false
        Repeater {
            id: users
            model: userModel
            delegate: UserEntry {}
            onItemAdded: root.refresh()
            onItemRemoved: root.refresh()
        }
        Repeater {
            id: sessions
            model: sessionModel
            delegate: SessionEntry {}
            onItemAdded: root.refresh()
            onItemRemoved: root.refresh()
        }
    }

    // ADR 0021: the static symbol occupies exactly the splash rectangle. Plymouth works in device pixels, so the
    // 320-pixel cap, the 42%/22% bounds and the rounding are computed in device pixels too.
    Image {
        id: logo
        objectName: "logo"
        readonly property real ratio: sourceSize.height > 0 ? sourceSize.width / sourceSize.height : 1
        readonly property real pixelRatio: Screen.devicePixelRatio > 0 ? Screen.devicePixelRatio : 1
        readonly property int deviceWidth: Math.floor(Math.min(sourceSize.width, root.width * pixelRatio * 0.42,
                                                               root.height * pixelRatio * 0.22 * ratio))
        readonly property int deviceHeight: Math.floor(deviceWidth / ratio)
        x: Math.floor((root.width * pixelRatio - deviceWidth) / 2) / pixelRatio
        y: Math.floor((root.height * pixelRatio - deviceHeight) / 2) / pixelRatio
        width: deviceWidth / pixelRatio
        height: deviceHeight / pixelRatio
        source: config.logo
        fillMode: Image.PreserveAspectFit
        smooth: true
        mipmap: true
    }

    // The form is anchored below the symbol, so the symbol never moves when the form changes.
    Column {
        id: content
        objectName: "form"
        anchors.horizontalCenter: parent.horizontalCenter
        y: logo.y + logo.height + Math.round(root.height * 0.05)
        spacing: 14

        Row {
            id: account
            objectName: "account"
            anchors.horizontalCenter: parent.horizontalCenter
            visible: LoginModel.accountVisible(root.userNames.length)
            spacing: 8

            Text {
                objectName: "user"
                text: root.userIndex >= 0 && root.userIndex < root.userLabels.length ? root.userLabels[root.userIndex] : ""
                color: root.foreground
                opacity: 0.85
                font.family: root.fontFamily
                font.pixelSize: 15
            }

            Text {
                id: switcher
                objectName: "switcher"
                visible: root.userNames.length > 1
                text: root.selecting ? "\u25b4" : "\u25be"
                color: root.foreground
                opacity: activeFocus || switchArea.containsMouse ? 1 : 0.6
                font.family: root.fontFamily
                font.pixelSize: 15
                font.underline: activeFocus
                activeFocusOnTab: true
                Accessible.role: Accessible.Button
                Accessible.name: "Change user"
                KeyNavigation.tab: root.powerAvailable ? powerButton : password
                Keys.onReturnPressed: root.openSelector()
                Keys.onEnterPressed: root.openSelector()
                Keys.onSpacePressed: root.openSelector()

                MouseArea {
                    id: switchArea
                    anchors.fill: parent
                    anchors.margins: -6
                    hoverEnabled: true
                    onClicked: root.selecting ? root.chooseUser(root.userIndex) : root.openSelector()
                }
            }
        }

        Rectangle {
            id: field
            objectName: "field"
            anchors.horizontalCenter: parent.horizontalCenter
            width: 280
            height: 44
            color: root.fieldColor
            border.width: 1
            border.color: root.failed ? root.failure
                : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b,
                          password.length > 0 || root.pending ? 0.85 : 0.35)
            opacity: root.reason === "" ? 1 : 0.4

            TextInput {
                id: password
                objectName: "password"
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                verticalAlignment: TextInput.AlignVCenter
                horizontalAlignment: TextInput.AlignHCenter
                echoMode: TextInput.Password
                // The typed characters are drawn as dots below; the native echo stays invisible.
                color: "transparent"
                selectionColor: "transparent"
                selectedTextColor: "transparent"
                cursorDelegate: Item {}
                font.family: root.fontFamily
                font.pixelSize: 16
                readOnly: root.pending || root.powerOpen || root.reason !== ""
                clip: true
                focus: true
                activeFocusOnTab: true
                Accessible.name: "Password"
                KeyNavigation.tab: switcher.visible ? switcher : powerButton.visible ? powerButton : password
                Keys.onReturnPressed: root.submit()
                Keys.onEnterPressed: root.submit()
                onTextEdited: root.failed = false
            }

            Row {
                objectName: "dots"
                anchors.centerIn: parent
                visible: !root.pending
                spacing: 4
                Repeater {
                    objectName: "dotRepeater"
                    model: Math.min(password.length, Math.floor((field.width - 24) / 14))
                    delegate: Rectangle {
                        width: 10
                        height: 10
                        radius: 5
                        color: root.foreground
                    }
                }
            }

            Text {
                objectName: "status"
                anchors.centerIn: parent
                visible: password.text.length === 0 || root.pending
                text: root.pending ? "Authenticating\u2026"
                    : root.failed ? "Authentication failed"
                    : root.reason !== "" ? "Login unavailable" : "Password"
                color: root.failed ? root.failure : root.foreground
                opacity: root.failed ? 1 : 0.45
                font.family: root.fontFamily
                font.pixelSize: 15
            }
        }

        Text {
            objectName: "reason"
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(implicitWidth, root.width * 0.8)
            visible: root.reason !== ""
            text: root.reason
            wrapMode: Text.Wrap
            horizontalAlignment: Text.AlignHCenter
            color: root.failure
            font.family: root.fontFamily
            font.pixelSize: 14
        }
    }

    // ADR 0021: the active layout and its switching hint, de-emphasized, opposite the power control.
    Row {
        objectName: "layoutRow"
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.margins: 24
        height: 36
        spacing: 10

        Text {
            objectName: "layoutIcon"
            anchors.verticalCenter: parent.verticalCenter
            text: "\udb80\udf0c"
            color: root.foreground
            opacity: 0.6
            font.family: root.fontFamily
            font.pixelSize: 14
        }

        Text {
            objectName: "layout"
            anchors.verticalCenter: parent.verticalCenter
            text: root.layout
            color: root.foreground
            opacity: 0.6
            font.family: root.fontFamily
            font.pixelSize: 14
        }

        Text {
            objectName: "layoutHint"
            anchors.verticalCenter: parent.verticalCenter
            visible: root.stateLayout !== "" && root.layoutHint !== ""
            text: root.layoutHint
            color: root.foreground
            opacity: 0.35
            font.family: root.fontFamily
            font.pixelSize: 14
        }
    }

    // The account list opens below the selected account and overlays the password field.
    Rectangle {
        x: content.x + (content.width - width) / 2
        y: content.y + account.y + account.height + 8
        z: 1
        width: 280
        height: Math.min(selector.contentHeight, root.height * 0.4) + 4
        visible: root.selecting
        color: root.color
        border.width: 1
        border.color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.35)

        ListView {
            id: selector
            objectName: "selector"
            anchors.fill: parent
            anchors.margins: 2
            clip: true
            model: root.userLabels
            keyNavigationEnabled: true
            boundsBehavior: Flickable.StopAtBounds
            Keys.onReturnPressed: root.chooseUser(currentIndex)
            Keys.onEnterPressed: root.chooseUser(currentIndex)
            Keys.onEscapePressed: {
                root.selecting = false;
                switcher.forceActiveFocus();
            }
            onActiveFocusChanged: if (!activeFocus) root.selecting = false

            delegate: Rectangle {
                id: entry
                required property int index
                required property string modelData
                width: selector.width
                height: 32
                color: entry.ListView.isCurrentItem ? root.foreground : root.color

                Text {
                    anchors.centerIn: parent
                    text: entry.modelData
                    color: entry.ListView.isCurrentItem ? root.color : root.foreground
                    font.family: root.fontFamily
                    font.pixelSize: 14
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: root.chooseUser(entry.index)
                }
            }
        }
    }

    // Peripheral controls leave the anchored login layout unchanged.
    component PowerButton: Rectangle {
        id: button
        property string label: ""
        property int textSize: 14
        signal activated()
        width: 208
        height: 36
        color: activeFocus ? root.foreground : root.color
        opacity: !enabled ? 0.35 : activeFocus || buttonArea.containsMouse ? 1 : 0.6
        activeFocusOnTab: true
        Accessible.role: Accessible.Button
        Accessible.name: label
        Accessible.onPressAction: if (enabled) activated()
        Keys.onReturnPressed: activated()
        Keys.onEnterPressed: activated()
        Keys.onSpacePressed: activated()
        Keys.onEscapePressed: root.closePower()

        Text {
            anchors.centerIn: parent
            text: button.label
            color: button.activeFocus ? root.color : root.foreground
            font.family: root.fontFamily
            font.pixelSize: button.textSize
        }

        MouseArea {
            id: buttonArea
            anchors.fill: parent
            hoverEnabled: true
            onClicked: button.activated()
        }
    }

    MouseArea {
        anchors.fill: parent
        z: 2
        visible: root.powerOpen
        onClicked: root.closePower()
    }

    Column {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 24
        spacing: 8
        z: 3

        Rectangle {
            objectName: "powerPanel"
            width: 232
            height: powerContent.implicitHeight + 24
            visible: root.powerOpen
            color: root.color
            border.width: 1
            border.color: root.foreground

            // Consume panel clicks so only clicks outside dismiss it.
            MouseArea { anchors.fill: parent }

            Column {
                id: powerContent
                anchors.centerIn: parent
                spacing: 4

                Text {
                    objectName: "powerQuestion"
                    width: 208
                    height: 36
                    visible: root.powerAction !== ""
                    text: root.powerAction === "restart" ? "Restart the computer?" : "Shut down the computer?"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    color: root.foreground
                    font.family: root.fontFamily
                    font.pixelSize: 14
                }

                PowerButton {
                    id: restartButton
                    objectName: "restartButton"
                    label: "Restart"
                    visible: root.powerAction === "" && root.canRestart
                    KeyNavigation.tab: shutdownButton.visible ? shutdownButton : cancelButton
                    KeyNavigation.backtab: cancelButton
                    KeyNavigation.down: restartButton.KeyNavigation.tab
                    KeyNavigation.up: restartButton.KeyNavigation.backtab
                    onActivated: root.selectPower("restart")
                }

                PowerButton {
                    id: shutdownButton
                    objectName: "shutdownButton"
                    label: "Shut down"
                    visible: root.powerAction === "" && root.canShutDown
                    KeyNavigation.tab: cancelButton
                    KeyNavigation.backtab: restartButton.visible ? restartButton : cancelButton
                    KeyNavigation.down: shutdownButton.KeyNavigation.tab
                    KeyNavigation.up: shutdownButton.KeyNavigation.backtab
                    onActivated: root.selectPower("shutdown")
                }

                PowerButton {
                    id: cancelButton
                    objectName: "powerCancel"
                    label: "Cancel"
                    KeyNavigation.tab: root.powerAction !== "" ? (confirmButton.enabled ? confirmButton : cancelButton)
                                       : restartButton.visible ? restartButton : shutdownButton
                    KeyNavigation.backtab: root.powerAction !== "" ? (confirmButton.enabled ? confirmButton : cancelButton)
                                           : shutdownButton.visible ? shutdownButton : restartButton
                    KeyNavigation.down: cancelButton.KeyNavigation.tab
                    KeyNavigation.up: cancelButton.KeyNavigation.backtab
                    onActivated: root.closePower()
                }

                PowerButton {
                    id: confirmButton
                    objectName: "powerConfirm"
                    label: root.powerAction === "restart" ? "Restart" : "Shut down"
                    visible: root.powerAction !== ""
                    enabled: root.powerActionAvailable && !root.pending
                    KeyNavigation.tab: cancelButton
                    KeyNavigation.backtab: cancelButton
                    KeyNavigation.down: confirmButton.KeyNavigation.tab
                    KeyNavigation.up: confirmButton.KeyNavigation.backtab
                    onActivated: root.confirmPower()
                }
            }
        }

        PowerButton {
            id: powerButton
            objectName: "powerButton"
            anchors.right: parent.right
            width: 36
            label: "\u23fb"
            textSize: 22
            Accessible.name: "Power options"
            KeyNavigation.tab: password
            visible: root.powerAvailable
            enabled: !root.pending
            onActivated: root.powerOpen ? root.closePower() : root.openPower()
        }
    }

    Component.onCompleted: {
        refresh();
        password.forceActiveFocus();
    }
}

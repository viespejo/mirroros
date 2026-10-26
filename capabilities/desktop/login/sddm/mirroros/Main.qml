// MirrorOS SDDM theme (ADR 0014). Presentation only: SDDM authenticates through its own PAM service when
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
    property string stateLayout: ""
    property int stateMisses: 0
    readonly property int session: LoginModel.sessionIndex(sessionFiles, config.session)
    readonly property string reason: LoginModel.unavailableReason(userIndex, session)
    readonly property string layout: LoginModel.layoutLabel(layoutNames(), keyboard ? keyboard.currentLayout : -1,
                                                             stateLayout || config.keyboardLayout)

    width: 1280
    height: 800
    color: config.background

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
        if (pending || userNames.length < 2) return;
        selector.currentIndex = Math.max(userIndex, 0);
        selecting = true;
        selector.forceActiveFocus();
    }

    function submit() {
        if (!LoginModel.canSubmit(userIndex, session, pending, password.text)) return;
        pending = true;
        failed = false;
        sddm.login(userNames[userIndex], password.text, session);
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

    Column {
        id: content
        anchors.centerIn: parent
        spacing: 24

        Image {
            id: logo
            objectName: "logo"
            readonly property real ratio: sourceSize.height > 0 ? sourceSize.width / sourceSize.height : 1
            anchors.horizontalCenter: parent.horizontalCenter
            source: config.logo
            width: Math.min(sourceSize.width, root.width * 0.42, root.height * 0.22 * ratio)
            height: width / ratio
            fillMode: Image.PreserveAspectFit
            smooth: true
            mipmap: true
        }

        Item { width: 1; height: 24 }

        Row {
            id: account
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 10

            Text {
                objectName: "user"
                text: root.userIndex >= 0 && root.userIndex < root.userLabels.length ? root.userLabels[root.userIndex] : ""
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: 16
            }

            Text {
                id: switcher
                objectName: "switcher"
                visible: root.userNames.length > 1
                text: root.selecting ? "\u25b4" : "\u25be"
                color: root.foreground
                opacity: activeFocus || switchArea.containsMouse ? 1 : 0.55
                font.family: root.fontFamily
                font.pixelSize: 16
                font.underline: activeFocus
                activeFocusOnTab: true
                Accessible.role: Accessible.Button
                Accessible.name: "Change user"
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
            anchors.horizontalCenter: parent.horizontalCenter
            // hyprlock draws its 2-pixel outline outside the 300x50 field.
            width: 304
            height: 54
            color: root.color
            border.width: 2
            border.color: root.failed ? root.failure : root.foreground
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
                // The typed characters are drawn as hyprlock-sized dots below; the native echo stays invisible.
                color: "transparent"
                selectionColor: "transparent"
                selectedTextColor: "transparent"
                cursorDelegate: Item {}
                font.family: root.fontFamily
                font.pixelSize: 16
                readOnly: root.pending || root.reason !== ""
                clip: true
                focus: true
                activeFocusOnTab: true
                Accessible.name: "Password"
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
                    model: Math.min(password.length, Math.floor((field.width - 24) / 16))
                    delegate: Rectangle {
                        width: 12
                        height: 12
                        radius: 6
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
                opacity: root.failed ? 1 : 0.6
                font.family: root.fontFamily
                font.pixelSize: 16
            }
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 10

            Text {
                objectName: "layout"
                text: root.layout
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: 16
            }

            Text {
                objectName: "layoutHint"
                visible: root.stateLayout !== "" && root.layoutHint !== ""
                text: root.layoutHint
                color: root.foreground
                opacity: 0.55
                font.family: root.fontFamily
                font.pixelSize: 16
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

    // The account list opens below the selected account and overlays the password field.
    Rectangle {
        x: content.x + (content.width - width) / 2
        y: content.y + account.y + account.height + 8
        z: 1
        width: 300
        height: Math.min(selector.contentHeight, root.height * 0.4) + 4
        visible: root.selecting
        color: root.color
        border.width: 1
        border.color: root.foreground

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

    Component.onCompleted: {
        refresh();
        password.forceActiveFocus();
    }
}

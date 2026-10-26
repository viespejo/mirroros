// Synthetic SDDM models for the MirrorOS theme. theme.test.mjs substitutes @THEME@, @LOGO@ and @STATE@ (a layout
// state file holding "English (US)") and runs this file
// with qmltestrunner on the offscreen platform. sddm.login only records its call; no authentication happens.
import QtQuick
import QtTest

Item {
    id: harness
    width: 1280
    height: 800

    QtObject {
        id: config
        property string background: "#101315"
        property string foreground: "#cacccc"
        property string failure: "#a55555"
        property string font: "monospace"
        property string logo: "@LOGO@"
        property string session: "/usr/share/mirroros/wayland-sessions/hyprland-uwsm.desktop"
        property string keyboardLayout: "es"
        property string layoutState: ""
        property string layoutHint: "Super+I"
    }

    QtObject {
        id: sddm
        property var calls: []
        signal loginFailed()
        signal loginSucceeded()
        function login(user, password, session) {
            calls.push([user, password, session]);
        }
    }

    QtObject {
        id: keyboard
        property int currentLayout: 0
        property var layouts: []
    }

    ListModel {
        id: userModel
        property string lastUser: "bob"
    }

    ListModel {
        id: sessionModel
    }

    Loader {
        id: loader
        anchors.fill: parent
        focus: true
        active: false
        source: "@THEME@/Main.qml"
    }

    TestCase {
        name: "MirrorOSTheme"
        when: windowShown

        function setUsers(list, last) {
            userModel.clear();
            for (var i = 0; i < list.length; i++) userModel.append({ name: list[i][0], realName: list[i][1] });
            userModel.lastUser = last;
        }

        function setSessions(files) {
            sessionModel.clear();
            for (var i = 0; i < files.length; i++) sessionModel.append({ file: files[i] });
        }

        function reload() {
            loader.active = false;
            loader.active = true;
            tryVerify(function() { return loader.status === Loader.Ready; });
            waitForRendering(loader.item);
        }

        function item(name) { return findChild(loader.item, name); }

        function type(text) {
            for (var i = 0; i < text.length; i++) keyClick(text[i]);
        }

        function init() {
            harness.width = 1280;
            harness.height = 800;
            setUsers([["alice", "Alice A"], ["bob", ""], ["carol", "Carol C"]], "bob");
            setSessions(["/usr/share/wayland-sessions/foot.desktop",
                         "/usr/share/mirroros/wayland-sessions/hyprland-uwsm.desktop"]);
            keyboard.layouts = [];
            keyboard.currentLayout = 0;
            config.layoutState = "";
            sddm.calls = [];
            reload();
        }

        function test_last_user_is_selected_with_configured_layout() {
            compare(item("user").text, "bob");
            compare(item("layout").text, "es");
            verify(!item("reason").visible);
            verify(item("switcher").visible);
            verify(item("password").activeFocus);
            compare(item("status").text, "Password");
        }

        function test_absent_last_user_selects_first_listed_user() {
            setUsers([["alice", "Alice A"], ["carol", "Carol C"]], "bob");
            reload();
            compare(item("user").text, "Alice A");
        }

        function test_no_account_disables_submission() {
            setUsers([], "");
            reload();
            verify(item("reason").visible);
            compare(item("reason").text, "No user account is available for login.");
            compare(item("status").text, "Login unavailable");
            verify(!item("switcher").visible);
            type("secret");
            keyClick(Qt.Key_Return);
            compare(sddm.calls.length, 0);
        }

        function test_missing_or_ambiguous_session_disables_submission() {
            setSessions(["/usr/share/wayland-sessions/hyprland.desktop"]);
            reload();
            compare(item("reason").text, "The MirrorOS session is unavailable; run mirroros-configure.");
            keyClick(Qt.Key_Return);
            setSessions([config.session, config.session]);
            reload();
            verify(item("reason").visible);
            type("secret");
            keyClick(Qt.Key_Return);
            compare(sddm.calls.length, 0);
        }

        function test_enter_submits_once_through_the_proxy() {
            type("secret");
            keyClick(Qt.Key_Return);
            keyClick(Qt.Key_Enter);
            compare(sddm.calls.length, 1);
            compare(sddm.calls[0], ["bob", "secret", 1]);
            verify(item("password").readOnly);
        }

        function test_empty_password_is_not_submitted() {
            keyClick(Qt.Key_Return);
            compare(sddm.calls.length, 0);
        }

        function test_failure_clears_password_keeps_focus_and_allows_retry() {
            type("wrong");
            keyClick(Qt.Key_Return);
            sddm.loginFailed();
            compare(item("password").text, "");
            verify(!item("password").readOnly);
            verify(item("password").activeFocus);
            verify(item("status").visible);
            compare(item("status").text, "Authentication failed");
            type("right");
            verify(!item("status").visible);
            keyClick(Qt.Key_Return);
            compare(sddm.calls.length, 2);
            compare(sddm.calls[1], ["bob", "right", 1]);
        }

        function test_keyboard_account_change_clears_password_and_returns_focus() {
            type("typed");
            keyClick(Qt.Key_Tab);
            verify(item("switcher").activeFocus);
            keyClick(Qt.Key_Return);
            verify(item("selector").activeFocus);
            compare(item("selector").currentIndex, 1);
            keyClick(Qt.Key_Down);
            keyClick(Qt.Key_Return);
            compare(item("user").text, "Carol C");
            compare(item("password").text, "");
            verify(item("password").activeFocus);
            verify(!item("selector").visible);
            keyClick(Qt.Key_Tab);
            keyClick(Qt.Key_Space);
            keyClick(Qt.Key_Escape);
            verify(!item("selector").visible);
            verify(item("switcher").activeFocus);
            keyClick(Qt.Key_Tab);
            verify(item("password").activeFocus);
            type("pw");
            keyClick(Qt.Key_Return);
            compare(sddm.calls[0], ["carol", "pw", 1]);
        }

        function test_account_cannot_change_while_pending() {
            type("secret");
            keyClick(Qt.Key_Return);
            keyClick(Qt.Key_Tab);
            keyClick(Qt.Key_Return);
            verify(!item("selector").visible);
            compare(item("user").text, "bob");
        }

        function test_pending_submission_shows_authenticating_instead_of_dots() {
            type("secret");
            keyClick(Qt.Key_Return);
            verify(item("status").visible);
            compare(item("status").text, "Authenticating\u2026");
            verify(!item("dots").visible);
            sddm.loginFailed();
            verify(item("dots").visible);
            compare(item("status").text, "Authentication failed");
        }

        function test_single_account_hides_the_selector() {
            setUsers([["alice", "Alice A"]], "alice");
            reload();
            verify(!item("switcher").visible);
        }

        function test_native_keyboard_layout_takes_precedence() {
            keyboard.layouts = [{ longName: "English (US)" }, { longName: "German" }];
            keyboard.currentLayout = 1;
            compare(item("layout").text, "German");
        }

        function test_layout_state_file_drives_the_label_and_hint() {
            verify(!item("layoutHint").visible);
            config.layoutState = "@STATE@";
            reload();
            tryCompare(item("layout"), "text", "English (US)");
            verify(item("layoutHint").visible);
            compare(item("layoutHint").text, "Super+I");
            config.layoutState = "@STATE@.missing";
            reload();
            wait(400);
            compare(item("layout").text, "es");
            verify(!item("layoutHint").visible);
        }

        function test_password_is_drawn_as_dots_without_native_echo() {
            type("abc");
            compare(item("dotRepeater").count, 3);
            verify(Qt.colorEqual(item("password").color, "transparent"));
            compare(item("status").visible, false);
        }

        function test_logo_is_proportional_and_unclipped() {
            var sizes = [[1280, 800], [800, 480], [3840, 2160]];
            for (var i = 0; i < sizes.length; i++) {
                harness.width = sizes[i][0];
                harness.height = sizes[i][1];
                var logo = item("logo");
                tryVerify(function() { return logo.status === Image.Ready; });
                verify(logo.width > 0);
                verify(logo.width <= logo.sourceSize.width);
                fuzzyCompare(logo.width / logo.height, logo.sourceSize.width / logo.sourceSize.height, 0.01);
                var origin = logo.mapToItem(loader.item, 0, 0);
                verify(origin.x >= 0 && origin.y >= 0);
                verify(origin.x + logo.width <= harness.width && origin.y + logo.height <= harness.height);
            }
        }
    }
}

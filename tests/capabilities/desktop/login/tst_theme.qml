// Synthetic SDDM models for the MirrorOS theme. theme.test.mjs substitutes @THEME@, @LOGO@, @STATE@ (a layout
// state file holding "English (US)") and @SCALE@ (the QT_SCALE_FACTOR of the run) and runs this file
// with qmltestrunner on the offscreen platform. Login and power proxy calls only record requests; no real operation happens.
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
        property string field: "#15191c"
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
        property var powerCalls: []
        property bool canReboot: true
        property bool canPowerOff: true
        function reboot() { powerCalls.push("restart"); }
        function powerOff() { powerCalls.push("shutdown"); }
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
            sddm.powerCalls = [];
            sddm.canReboot = true;
            sddm.canPowerOff = true;
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
            verify(item("powerButton").activeFocus);
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
            verify(!item("account").visible);
            compare(item("field").mapToItem(item("form"), 0, 0).y, 0);
            verify(item("password").activeFocus);
            type("secret");
            keyClick(Qt.Key_Return);
            compare(sddm.calls[0], ["alice", "secret", 1]);
        }

        function test_multiple_accounts_show_the_account_above_the_field() {
            verify(item("account").visible);
            verify(item("field").mapToItem(item("form"), 0, 0).y > item("account").height);
        }

        // ADR 0021: the symbol occupies the Plymouth rectangle (device pixels) and the form starts 5% below it.
        function test_symbol_keeps_the_splash_rectangle_and_anchors_the_form() {
            var ratio = Screen.devicePixelRatio;
            fuzzyCompare(ratio, Number("@SCALE@"), 0.001);
            var sizes = [[1280, 800], [1200, 675], [800, 480], [2560, 1600]];
            for (var i = 0; i < sizes.length; i++) {
                harness.width = sizes[i][0];
                harness.height = sizes[i][1];
                var logo = item("logo");
                tryVerify(function() { return logo.status === Image.Ready; });
                var device = Math.floor(Math.min(320, sizes[i][0] * ratio * 0.42, sizes[i][1] * ratio * 0.22));
                fuzzyCompare(logo.width * ratio, device, 0.001);
                fuzzyCompare(logo.height * ratio, device, 0.001);
                fuzzyCompare(logo.x * ratio, Math.floor((sizes[i][0] * ratio - device) / 2), 0.001);
                fuzzyCompare(logo.y * ratio, Math.floor((sizes[i][1] * ratio - device) / 2), 0.001);
                var form = item("form");
                fuzzyCompare(form.y, logo.y + logo.height + Math.round(sizes[i][1] * 0.05), 0.001);
                fuzzyCompare(form.x + form.width / 2, sizes[i][0] / 2, 1);
                var field = item("field");
                compare(field.width, 280);
                compare(field.height, 44);
                var bottom = field.mapToItem(loader.item, 0, field.height).y;
                verify(bottom <= sizes[i][1] - 24 - 36);
            }
        }

        function test_field_border_follows_typing_authentication_and_failure() {
            var field = item("field");
            verify(Qt.colorEqual(field.color, "#15191c"));
            compare(field.border.width, 1);
            fuzzyCompare(field.border.color.a, 0.35, 0.01);
            type("x");
            fuzzyCompare(field.border.color.a, 0.85, 0.01);
            keyClick(Qt.Key_Return);
            fuzzyCompare(field.border.color.a, 0.85, 0.01);
            sddm.loginFailed();
            verify(Qt.colorEqual(field.border.color, "#a55555"));
            type("y");
            fuzzyCompare(field.border.color.a, 0.85, 0.01);
        }

        function test_layout_sits_in_the_bottom_left_corner() {
            var row = item("layoutRow");
            var origin = row.mapToItem(loader.item, 0, 0);
            compare(origin.x, 24);
            compare(origin.y + row.height, harness.height - 24);
            verify(item("layout").visible);
            verify(item("layoutIcon").visible);
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

        function test_power_menu_requires_confirmation_with_cancel_focused() {
            type("secret");
            keyClick(Qt.Key_Tab);
            keyClick(Qt.Key_Tab);
            verify(item("powerButton").activeFocus);
            keyClick(Qt.Key_Space);
            verify(item("powerPanel").visible);
            verify(item("restartButton").activeFocus);
            compare(item("password").text, "");
            verify(item("password").readOnly);
            keyClick(Qt.Key_Return);
            compare(item("powerQuestion").text, "Restart the computer?");
            verify(item("powerCancel").activeFocus);
            compare(sddm.powerCalls.length, 0);
            keyClick(Qt.Key_Tab);
            verify(item("powerConfirm").activeFocus);
            keyClick(Qt.Key_Tab);
            verify(item("powerCancel").activeFocus);
            keyClick(Qt.Key_Tab, Qt.ShiftModifier);
            verify(item("powerConfirm").activeFocus);
            keyClick(Qt.Key_Return);
            keyClick(Qt.Key_Return);
            compare(sddm.powerCalls, ["restart"]);
            compare(sddm.calls.length, 0);
        }

        function test_power_arrows_cycle_menu_and_confirmation_without_dispatch() {
            mouseClick(item("powerButton"));
            verify(item("restartButton").activeFocus);
            keyClick(Qt.Key_Down);
            verify(item("shutdownButton").activeFocus);
            keyClick(Qt.Key_Down);
            verify(item("powerCancel").activeFocus);
            keyClick(Qt.Key_Down);
            verify(item("restartButton").activeFocus);
            keyClick(Qt.Key_Up);
            verify(item("powerCancel").activeFocus);
            keyClick(Qt.Key_Up);
            verify(item("shutdownButton").activeFocus);
            keyClick(Qt.Key_Up);
            verify(item("restartButton").activeFocus);
            keyClick(Qt.Key_Return);
            verify(item("powerCancel").activeFocus);
            keyClick(Qt.Key_Down);
            verify(item("powerConfirm").activeFocus);
            keyClick(Qt.Key_Down);
            verify(item("powerCancel").activeFocus);
            keyClick(Qt.Key_Up);
            verify(item("powerConfirm").activeFocus);
            keyClick(Qt.Key_Up);
            verify(item("powerCancel").activeFocus);
            compare(sddm.powerCalls.length, 0);
            keyClick(Qt.Key_Escape);
            verify(!item("powerPanel").visible);
            verify(item("powerButton").activeFocus);
        }

        function test_power_arrows_skip_unavailable_actions_data() {
            return [
                { tag: "restart-only", restart: true, shutdown: false, button: "restartButton" },
                { tag: "shutdown-only", restart: false, shutdown: true, button: "shutdownButton" }
            ];
        }

        function test_power_arrows_skip_unavailable_actions(data) {
            sddm.canReboot = data.restart;
            sddm.canPowerOff = data.shutdown;
            mouseClick(item("powerButton"));
            verify(item(data.button).activeFocus);
            keyClick(Qt.Key_Up);
            verify(item("powerCancel").activeFocus);
            keyClick(Qt.Key_Up);
            verify(item(data.button).activeFocus);
            keyClick(Qt.Key_Down);
            verify(item("powerCancel").activeFocus);
            keyClick(Qt.Key_Down);
            verify(item(data.button).activeFocus);
            keyClick(Qt.Key_Return);
            verify(item("powerCancel").activeFocus);
            sddm.canReboot = true;
            sddm.canPowerOff = true;
            sddm.canReboot = !data.restart;
            sddm.canPowerOff = !data.shutdown;
            verify(!item("powerConfirm").enabled);
            keyClick(Qt.Key_Down);
            verify(item("powerCancel").activeFocus);
            keyClick(Qt.Key_Up);
            verify(item("powerCancel").activeFocus);
            compare(sddm.powerCalls.length, 0);
        }

        function test_mouse_shutdown_is_confirmed_once() {
            mouseClick(item("powerButton"));
            mouseClick(item("shutdownButton"));
            compare(item("powerQuestion").text, "Shut down the computer?");
            verify(item("powerCancel").activeFocus);
            compare(sddm.powerCalls.length, 0);
            mouseClick(item("powerConfirm"));
            loader.item.confirmPower();
            compare(sddm.powerCalls, ["shutdown"]);
            verify(!item("powerPanel").visible);
        }

        function test_power_cancel_escape_and_outside_never_request_an_action() {
            mouseClick(item("powerButton"));
            keyClick(Qt.Key_Escape);
            verify(!item("powerPanel").visible);
            verify(item("powerButton").activeFocus);
            keyClick(Qt.Key_Return);
            keyClick(Qt.Key_Return);
            verify(item("powerCancel").activeFocus);
            keyClick(Qt.Key_Return);
            verify(!item("powerPanel").visible);
            mouseClick(item("powerButton"));
            mouseClick(item("shutdownButton"));
            keyClick(Qt.Key_Escape);
            verify(!item("powerPanel").visible);
            mouseClick(item("powerButton"));
            mouseClick(loader.item, 10, 10);
            verify(!item("powerPanel").visible);
            compare(sddm.powerCalls.length, 0);
            compare(sddm.calls.length, 0);
        }

        function test_power_capabilities_gate_visibility_and_are_rechecked() {
            sddm.canReboot = false;
            mouseClick(item("powerButton"));
            verify(!item("restartButton").visible);
            verify(item("shutdownButton").activeFocus);
            keyClick(Qt.Key_Tab);
            verify(item("powerCancel").activeFocus);
            keyClick(Qt.Key_Tab);
            verify(item("shutdownButton").activeFocus);
            keyClick(Qt.Key_Return);
            sddm.canPowerOff = false;
            verify(!item("powerButton").visible);
            verify(!item("powerPanel").visible);
            verify(item("password").activeFocus);
            loader.item.confirmPower();
            loader.item.openPower();
            compare(sddm.powerCalls.length, 0);
            verify(!item("powerPanel").visible);
            sddm.canReboot = true;
            mouseClick(item("powerButton"));
            verify(!item("shutdownButton").visible);
            sddm.canPowerOff = true;
            mouseClick(item("restartButton"));
            sddm.canReboot = false;
            verify(!item("powerConfirm").enabled);
            loader.item.confirmPower();
            compare(sddm.powerCalls.length, 0);
            keyClick(Qt.Key_Escape);
            verify(!item("powerPanel").visible);
        }

        function test_power_and_login_are_mutually_exclusive() {
            mouseClick(item("powerButton"));
            item("password").text = "secret";
            loader.item.submit();
            compare(sddm.calls.length, 0);
            loader.item.closePower();
            item("password").forceActiveFocus();
            keyClick(Qt.Key_Return);
            compare(sddm.calls.length, 1);
            verify(!item("powerButton").enabled);
            loader.item.openPower();
            loader.item.selectPower("restart");
            loader.item.confirmPower();
            verify(!item("powerPanel").visible);
            compare(sddm.powerCalls.length, 0);
            sddm.loginFailed();
            verify(item("powerButton").enabled);
        }

        function test_power_menu_closes_account_selection_and_fits_small_windows() {
            loader.item.openSelector();
            verify(item("selector").visible);
            loader.item.openPower();
            verify(!item("selector").visible);
            var sizes = [[1280, 800], [800, 480]];
            for (var i = 0; i < sizes.length; i++) {
                harness.width = sizes[i][0];
                harness.height = sizes[i][1];
                waitForRendering(loader.item);
                var panel = item("powerPanel");
                var origin = panel.mapToItem(loader.item, 0, 0);
                verify(origin.x >= 0 && origin.y >= 0);
                verify(origin.x + panel.width <= harness.width && origin.y + panel.height <= harness.height);
            }
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

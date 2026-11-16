//@ pragma OmarchyLoadPatch
import QtQuick
import Quickshell
import QtTest
import "velunori.lockscreen" as L

ShellRoot {
    id: tests
    property string failure: ""
    property string entered: ""
    property string submitted: ""
    property int submissions: 0
    function check(value, message) { if (!value) failure += message + "; "; }
    function find(parent, name) {
        if (parent.objectName === name) return parent;
        for (var child of parent.children || []) { var match = find(child, name); if (match) return match; }
        return null;
    }
    TestEvent { id: events }
    FloatingWindow {
        id: window
        visible: true
        implicitWidth: Number(Quickshell.env("VELUNORI_TEST_WIDTH") || 1280)
        implicitHeight: Number(Quickshell.env("VELUNORI_TEST_HEIGHT") || 720)
        L.LockView {
            id: view
            anchors.fill: parent
            now: new Date(2026, 10, 13, 9, 41)
            userName: "szalikdev"
            backgroundPath: Quickshell.env("VELUNORI_PREVIEW_BACKGROUND")
            passwordText: tests.entered
            onPasswordTextEdited: function(value) { tests.entered = value; }
            onSubmitPassword: function(value) { tests.submitted = value; tests.submissions++; }
            onClearFailureRequested: failureMessage = ""
        }
    }
    Timer {
        interval: 350; running: true
        onTriggered: {
            var input = find(view, "lockPassword");
            var submit = find(view, "lockSubmit");
            var field = find(view, "lockField");
            var arrow = find(view, "lockSubmitArrow");
            var arrowPoint = arrow.mapToItem(submit, arrow.width / 2, arrow.height / 2);
            check(Math.abs(arrowPoint.x - submit.width / 2) < 0.1 && Math.abs(arrowPoint.y - submit.height / 2) < 0.1, "submit arrow is geometrically centered");
            check(find(view, "lockClock").text === "09:41", "clock uses live-time interface");
            check(!submit.enabled && input.echoMode === TextInput.Password && input.passwordMaskDelay === 0, "empty field disabled and password masked immediately");
            entered = "fixture";
            check(input.text === "fixture", "service edits synchronize into the view");
            input.text = "typed";
            check(entered === "typed" && submit.enabled, "view edits synchronize into the service");
            view.forcePasswordFocus();
            check(events.keyClick(Qt.Key_Return, Qt.NoModifier, 0), "Enter delivered");
            check(submissions === 1 && submitted === "typed" && entered === "" && input.text === "", "Enter emits once and clears the shared password");
            view.submitEnteredPassword();
            check(submissions === 1, "empty values are never submitted");
            entered = "long-fixture-".repeat(10);
            check(view.passwordDotScale < 1 && input.font.pixelSize >= 1, "long masked input fits");
            check(events.keyClick(Qt.Key_Escape, Qt.NoModifier, 0), "Escape delivered");
            check(entered === "" && submissions === 1, "Escape clears input without submitting");
            entered = "clear with control";
            events.keyClick(Qt.Key_U, Qt.ControlModifier, 0);
            check(entered === "", "Ctrl+U clears input");
            view.failureMessage = "Incorrect password";
            input.text = "retry";
            check(view.failureMessage === "", "typing clears previous failure through the service signal");
            view.authenticatingPassword = true;
            check(!input.enabled && !submit.enabled, "busy authentication disables input and submit");
            view.submitEnteredPassword();
            check(submissions === 1, "busy view cannot submit twice");
            view.authenticatingPassword = false;
            view.inputEnabled = false;
            view.submitEnteredPassword();
            check(submissions === 1 && !input.enabled, "inactive preview cannot authenticate");
            view.inputEnabled = true;
            entered = "";
            view.fingerprintConfigured = true;
            check(find(view, "fingerprintIndicator").visible, "enrolled fingerprint hint is shown");
            var fieldPoint = field.mapToItem(view, 0, 0);
            check(fieldPoint.x >= 0 && fieldPoint.x + field.width <= view.width && fieldPoint.y + field.height <= view.height, "password field fits screen");
            check(find(view,"lockHint").mapToItem(view,0,0).y + find(view,"lockHint").height < find(view,"lockBrand").y, "helper stays clear of branding on short screens");
            var output = Quickshell.env("VELUNORI_PREVIEW_PATH");
            if (output) { view.fingerprintConfigured = false; capture.start(); }
            else { console.log(failure ? "LOCKSCREEN_TEST_FAILED: " + failure : "LOCKSCREEN_TEST_PASSED"); Qt.quit(); }
        }
    }
    Timer {
        id: capture; interval: 350
        onTriggered: view.grabToImage(function(result) {
            console.log(failure ? "LOCKSCREEN_TEST_FAILED: " + failure : result.saveToFile(Quickshell.env("VELUNORI_PREVIEW_PATH")) ? "LOCKSCREEN_PREVIEW_SAVED" : "LOCKSCREEN_TEST_FAILED: preview");
            Qt.quit();
        })
    }
}

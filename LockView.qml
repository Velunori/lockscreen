pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import qs.Commons
import "../lib/kit" as V

// Presentation only. Keep the LockView interface expected by Omarchy's
// unmodified Service.qml: PAM, secure surfaces and unlocking stay there.
Item {
    id: root
    property string backgroundPath: ""
    property string videoPosterPath: ""
    property bool fingerprintUnavailable: false
    property int backgroundVersion: 0
    property bool fingerprintConfigured: false
    property bool authenticatingPassword: false
    property string failureMessage: ""
    property int failedAttempts: 0
    property bool inputEnabled: true
    property bool loadBackground: true
    property string passwordText: ""
    property bool syncingPasswordText: false
    property string userName: Quickshell.env("USER") || Quickshell.env("LOGNAME") || "User"
    property date now: clock.date
    property var appearance: ({})
    readonly property bool compact: height < 560
    readonly property int fieldWidth: Math.max(180, Math.min(360, width - 48))
    readonly property int fieldHeight: compact ? 44 : 52
    readonly property real fingerprintReserve: fingerprintConfigured ? 30 : 0
    readonly property int passwordDotFontSize: compact ? 18 : 20
    readonly property int passwordDotLetterSpacing: 3
    readonly property real passwordDotScale: dotMetrics.advanceWidth > 0 ? Math.min(1, Math.max(1, passwordInput.width - 4) / dotMetrics.advanceWidth) : 1
    readonly property bool errorState: failureMessage.length > 0
    signal submitPassword(string password)
    signal passwordTextEdited(string password)
    signal clearFailureRequested()
    signal wakeRequested()

    V.Theme { id: theme; bar: ({velunori: {apiVersion: 1, accentName: root.appearance.accent || "lavender", motion: root.appearance.motion !== false}}) }
    SystemClock { id: clock; precision: SystemClock.Minutes }
    FileView {
        path: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/omarchy/shell.json"
        watchChanges: true; printErrors: false
        onFileChanged: reload()
        onLoaded: { try { var config = JSON.parse(text()); root.appearance = config.bar && config.bar.velunori || ({}); } catch (error) { root.appearance = ({}); } }
    }
    function fileUrl(path) {
        if (!path) return "";
        return "file://" + String(path).split("/").map(encodeURIComponent).join("/") + "?v=" + backgroundVersion;
    }
    function forcePasswordFocus() { passwordInput.forceActiveFocus(); }
    function clearPassword() { passwordTextEdited(""); }
    function syncPasswordText() {
        if (passwordInput.text === passwordText) return;
        syncingPasswordText = true; passwordInput.text = passwordText; syncingPasswordText = false;
    }
    function submitEnteredPassword() {
        if (!inputEnabled || authenticatingPassword || passwordText.length === 0) return;
        var submitted = passwordText;
        passwordTextEdited("");
        submitPassword(submitted);
    }
    onPasswordTextChanged: syncPasswordText()
    onInputEnabledChanged: if (inputEnabled) Qt.callLater(forcePasswordFocus)
    Component.onCompleted: { syncPasswordText(); if (inputEnabled) Qt.callLater(forcePasswordFocus); }
    TextMetrics { id: dotMetrics; font.family: theme.fontFamily; font.pixelSize: root.passwordDotFontSize; font.letterSpacing: root.passwordDotLetterSpacing; text: "●".repeat(passwordInput.text.length) }

    Rectangle { anchors.fill: parent; color: theme.background }
    Image { id: wallpaper; anchors.fill: parent; source: root.loadBackground ? root.fileUrl(root.videoPosterPath || root.backgroundPath) : ""; fillMode: Image.PreserveAspectCrop; asynchronous: true; cache: false; sourceSize.width: width; sourceSize.height: height }
    MultiEffect { anchors.fill: wallpaper; source: wallpaper; autoPaddingEnabled: false; blurEnabled: root.loadBackground && wallpaper.status === Image.Ready; blur: 1; blurMax: 128; blurMultiplier: 1.25; contrast: -.08 }
    Rectangle { anchors.fill: parent; color: "#66202026" }
    MouseArea { anchors.fill: parent; hoverEnabled: true; onClicked: { root.wakeRequested(); root.forcePasswordFocus(); } onPositionChanged: root.wakeRequested() }

    Column {
        id: clockBlock
        y: root.height * (root.compact ? .1 : .16)
        anchors.horizontalCenter: parent.horizontalCenter; spacing: root.compact ? 4 : 10
        Text {
            objectName: "lockClock"
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatTime(root.now, "HH:mm"); color: theme.text
            font.family: theme.fontFamily; font.pixelSize: Math.round(Math.max(42, Math.min(128, root.height * .14, root.width * .16))); font.weight: Font.Light
        }
        Text { objectName: "lockDate"; anchors.horizontalCenter: parent.horizontalCenter; text: Qt.formatDate(root.now, "dddd, d MMMM"); color: "#d4cedf"; font.family: theme.fontFamily; font.pixelSize: root.compact ? 14 : 21 }
    }
    Column {
        id: identity
        y: root.height * (root.compact ? .42 : .47)
        anchors.horizontalCenter: parent.horizontalCenter
        width: root.fieldWidth; spacing: root.compact ? 10 : 16
        Rectangle {
            width: root.compact ? 36 : 56; height: width; radius: width / 2; color: Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, .16)
            anchors.horizontalCenter: parent.horizontalCenter
            Canvas {
                anchors.fill: parent; anchors.margins: parent.width * .22
                property color ink: theme.accent
                onInkChanged: requestPaint()
                onPaint: {
                    var ctx = getContext("2d"); ctx.reset(); ctx.strokeStyle = ink; ctx.lineWidth = 1.7; ctx.lineCap = "round";
                    ctx.beginPath(); ctx.arc(width / 2, height * .27, width * .2, 0, Math.PI * 2); ctx.stroke();
                    ctx.beginPath(); ctx.moveTo(width * .1, height * .94); ctx.bezierCurveTo(width * .08, height * .44, width * .92, height * .44, width * .9, height * .94); ctx.stroke();
                }
            }
        }
        Text { objectName: "lockUser"; width: parent.width; horizontalAlignment: Text.AlignHCenter; text: root.userName; textFormat: Text.PlainText; elide: Text.ElideRight; color: theme.text; font.family: theme.fontFamily; font.pixelSize: root.compact ? 18 : 23 }
        Rectangle {
            id: inputField; objectName: "lockField"
            width: parent.width; height: root.fieldHeight; radius: 14; color: "#b329292f"
            border.color: root.errorState ? "#eaa7bb" : passwordInput.activeFocus ? theme.accent : theme.border
            TextInput {
                id: passwordInput; objectName: "lockPassword"
                anchors.left: parent.left; anchors.leftMargin: 16
                anchors.right: submit.left; anchors.rightMargin: 12 + root.fingerprintReserve
                anchors.top: parent.top; anchors.bottom: parent.bottom
                verticalAlignment: TextInput.AlignVCenter; horizontalAlignment: TextInput.AlignLeft
                activeFocusOnPress: true; clip: true
                enabled: root.inputEnabled && !root.authenticatingPassword; readOnly: root.authenticatingPassword
                echoMode: TextInput.Password; passwordCharacter: "●"; passwordMaskDelay: 0
                color: theme.text; selectionColor: theme.accent; selectedTextColor: theme.background
                font.family: theme.fontFamily
                font.pixelSize: text.length ? Math.max(1, Math.floor(root.passwordDotFontSize * root.passwordDotScale)) : 16
                font.letterSpacing: text.length ? root.passwordDotLetterSpacing * root.passwordDotScale : 0
                cursorVisible: activeFocus && enabled && text.length > 0 && !root.errorState
                onTextChanged: {
                    if (!root.syncingPasswordText) root.passwordTextEdited(text);
                    if (text.length > 0) root.wakeRequested();
                    if (text.length > 0 && root.failureMessage.length > 0) root.clearFailureRequested();
                }
                onAccepted: root.submitEnteredPassword()
                Keys.onPressed: function(event) {
                    root.wakeRequested();
                    if (event.key === Qt.Key_Escape || (event.modifiers & Qt.ControlModifier && event.key === Qt.Key_U)) { root.passwordTextEdited(""); event.accepted = true; }
                }
            }
            Text { anchors.fill: passwordInput; visible: passwordInput.text.length === 0; text: root.authenticatingPassword ? "Checking…" : "Password"; color: theme.muted; font.family: theme.fontFamily; font.pixelSize: 14; verticalAlignment: Text.AlignVCenter }
            Text { id: fingerprintIcon; objectName: "fingerprintIndicator"; visible: root.fingerprintConfigured; anchors.right: submit.left; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter; text: "󰈷"; color: theme.muted; font.family: Style.font.family; font.pixelSize: 22 }
            AbstractButton {
                id: submit; objectName: "lockSubmit"
                width: root.compact ? 30 : 34; height: width
                padding: 0
                anchors.right: parent.right; anchors.rightMargin: 9; anchors.verticalCenter: parent.verticalCenter
                enabled: root.inputEnabled && !root.authenticatingPassword && root.passwordText.length > 0
                Accessible.name: "Unlock session"
                onClicked: { root.wakeRequested(); root.submitEnteredPassword(); }
                background: Rectangle { radius: width / 2; color: theme.accent; opacity: submit.enabled ? 1 : .5 }
                contentItem: Item {
                    Canvas {
                        objectName: "lockSubmitArrow"
                        anchors.centerIn: parent; width: 16; height: 16
                        property color ink: theme.background
                        onInkChanged: requestPaint()
                        onPaint: {
                            var c = getContext("2d"); c.reset(); c.strokeStyle = ink;
                            c.lineWidth = 1.6; c.lineCap = "round"; c.lineJoin = "round";
                            c.beginPath(); c.moveTo(3, 8); c.lineTo(13, 8);
                            c.moveTo(8, 3); c.lineTo(13, 8); c.lineTo(8, 13); c.stroke();
                        }
                    }
                }
            }
        }
        Text {
            objectName: "lockHint"
            width: parent.width; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap
            text: root.errorState ? root.failureMessage : root.authenticatingPassword ? "Verifying your password…" : root.fingerprintConfigured ? "Enter to unlock · or use fingerprint" : "Enter to unlock"
            textFormat: Text.PlainText; color: root.errorState ? "#eaa7bb" : theme.muted
            font.family: theme.fontFamily; font.pixelSize: root.compact ? 11 : 13
        }
    }
    Text { objectName: "lockBrand"; anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.bottom; anchors.bottomMargin: root.compact ? 16 : 32; text: "VELUNORI"; color: "#c9c3d4"; font.family: theme.fontFamily; font.pixelSize: 11; font.letterSpacing: 5 }
}

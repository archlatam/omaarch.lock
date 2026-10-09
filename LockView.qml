import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import qs.Commons
import qs.Ui

Item {
  id: root

  property string backgroundPath: ""
  property int backgroundVersion: 0
  property bool fingerprintConfigured: false
  property bool authenticatingPassword: false
  property string failureMessage: ""
  property int failedAttempts: 0
  property bool inputEnabled: true
  property bool loadBackground: true
  property string passwordText: ""
  property bool syncingPasswordText: false

  readonly property string placeholderText: "Enter Password"
  readonly property int fieldWidth: 381
  readonly property int fieldHeight: 67
  readonly property int outlineThickness: 3
  readonly property int fieldFontSize: Math.round(Style.font.heading * 1.125)
  readonly property int passwordDotFontSize: Math.round(Style.font.heading * 1.33)
  readonly property int passwordDotLetterSpacing: Math.round(Style.font.heading * 0.19)
  // Space to keep clear on each side of the field for the fingerprint icon
  // (icon width plus a gap) so the centered dots never run under it.
  readonly property real fingerprintReserve: fingerprintConfigured ? Math.round(fingerprintIcon.implicitWidth + 12) : 0
  // Shrink the dots to fit once the password outgrows the field, so every
  // keystroke stays visible — otherwise long passwords clip with no feedback.
  readonly property real passwordDotScale: dotMetrics.advanceWidth > 0
    ? Math.min(1, (passwordInput.width - 4) / dotMetrics.advanceWidth)
    : 1
  readonly property bool showPasswordCursor: inputEnabled && !authenticatingPassword && failureMessage.length === 0
  readonly property bool errorState: failureMessage.length > 0
  readonly property var inputBorderSpec: errorState
    ? Border.surfaceSpec("lock", "border-error", Color.lock.borderError, root.outlineThickness, "border-alpha")
    : Border.surfaceSpec("lock", "border-active", Color.lock.borderActive, root.outlineThickness, "border-alpha")

  // First player with a loaded track, regardless of play state — a paused
  // song is still "what's on".
  // Prefer the Spotify player; fall back to the first player with a track so
  // anything else keeps working if Spotify is closed.
  readonly property var activePlayer: {
    var ps = Mpris.players ? Mpris.players.values : []
    var spotify = null
    for (var i = 0; i < ps.length; i++) {
      if (!ps[i]) continue
      var name = String(ps[i].identity || "") + " " + String(ps[i].desktopEntry || "") + " " + String(ps[i].dbusName || "")
      if (name.toLowerCase().indexOf("spotify") !== -1 && ps[i].trackTitle) return ps[i]
      if (!spotify && ps[i].trackTitle) spotify = ps[i]
    }
    return spotify
  }
  readonly property string userName: Quickshell.env("USER") || Quickshell.env("LOGNAME") || ""
  readonly property bool backgroundIsVideo: /\.(mp4|webm|mov|mkv)$/i.test(backgroundPath)
  readonly property var sink: Pipewire.defaultAudioSink
  readonly property bool outputMuted: sink && sink.audio ? sink.audio.muted : false
  readonly property real outputVolume: sink && sink.audio ? sink.audio.volume : 0

  function volumeIcon() {
    if (outputMuted || outputVolume <= 0) return "󰖁"
    if (outputVolume < 0.5) return "󰕿"
    return "󰕾"
  }

  function setOutputVolume(v) {
    if (sink && sink.audio) sink.audio.volume = v
  }

  function toggleOutputMute() {
    if (sink && sink.audio) sink.audio.muted = !sink.audio.muted
  }

  signal submitPassword(string password)
  signal passwordTextEdited(string password)
  signal clearFailureRequested()
  signal wakeRequested()

  // Cache-busts the lock background by appending `?v=`. Adding a query
  // string keeps Image's loader happy while forcing it to reload when the
  // user picks a new background mid-session.
  function fileUrl(path) {
    if (!path) return ""
    var encoded = String(path).split("/").map(encodeURIComponent).join("/")
    return "file://" + encoded + "?v=" + backgroundVersion
  }

  function forcePasswordFocus() {
    passwordInput.forceActiveFocus()
  }

  function clearPassword() {
    passwordTextEdited("")
  }

  function syncPasswordText() {
    if (passwordInput.text === passwordText) return
    syncingPasswordText = true
    passwordInput.text = passwordText
    syncingPasswordText = false
  }

  onPasswordTextChanged: syncPasswordText()
  onInputEnabledChanged: {
    if (inputEnabled) Qt.callLater(forcePasswordFocus)
  }
  Component.onCompleted: {
    syncPasswordText()
    if (inputEnabled) Qt.callLater(forcePasswordFocus)
  }

  // Measures the masked password at full size; passwordDotScale compares this
  // against the field width to decide how far the dots must shrink to fit.
  TextMetrics {
    id: dotMetrics
    font.family: Style.font.family
    font.pixelSize: root.passwordDotFontSize
    font.letterSpacing: root.passwordDotLetterSpacing
    text: "●".repeat(passwordInput.text.length)
  }

  Rectangle {
    anchors.fill: parent
    color: Color.background

    Image {
      id: wallpaper
      anchors.fill: parent
      source: root.loadBackground ? root.fileUrl(root.backgroundPath) : ""
      fillMode: Image.PreserveAspectCrop
      asynchronous: true
      cache: false
      sourceSize.width: width
      sourceSize.height: height
    }

    MultiEffect {
      anchors.fill: wallpaper
      source: wallpaper
      autoPaddingEnabled: false
      blurEnabled: root.loadBackground && wallpaper.status === Image.Ready
      blur: 1.0
      blurMax: 128
      blurMultiplier: 1.25
      contrast: -0.08
    }

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      onClicked: { root.wakeRequested(); root.forcePasswordFocus() }
      onPositionChanged: root.wakeRequested()
    }

    SystemClock {
      id: clock
      precision: SystemClock.Minutes
    }

    Column {
      id: clockColumn
      anchors.bottom: inputField.top
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.bottomMargin: Style.space(24)
      spacing: Style.space(4)

      Row {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Style.space(6)
        visible: root.userName.length > 0

        Text {
          text: "󰀄"
          color: Color.lock.placeholder
          font.family: Style.font.family
          font.pixelSize: Math.round(Style.font.heading * 1.1)
          verticalAlignment: Text.AlignVCenter
        }

        Text {
          text: root.userName
          color: Color.lock.placeholder
          font.family: Style.font.family
          font.pixelSize: Math.round(Style.font.heading * 1.1)
          verticalAlignment: Text.AlignVCenter
        }
      }

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: Qt.formatDateTime(clock.date, "HH:mm")
        color: Color.lock.text
        font.family: Style.font.family
        font.pixelSize: Math.round(Style.font.heading * 3)
        font.weight: Font.Bold
      }

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: Qt.formatDateTime(clock.date, "dddd, d 'de' MMMM")
        color: Color.lock.placeholder
        font.family: Style.font.family
        font.pixelSize: Math.round(Style.font.heading * 1.25)
      }
    }

    Column {
      id: musicColumn
      anchors.top: inputField.bottom
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.topMargin: Style.space(16)
      spacing: Style.space(8)
      visible: root.activePlayer !== null

      Row {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Style.space(6)

        Text {
          text: "󰎈"
          color: Color.lock.placeholder
          font.family: Style.font.family
          font.pixelSize: Math.round(Style.font.heading * 1.1)
          verticalAlignment: Text.AlignVCenter
        }

        Text {
          text: root.activePlayer
            ? (root.activePlayer.trackTitle + (root.activePlayer.trackArtist ? " — " + root.activePlayer.trackArtist : "") + (root.activePlayer.identity ? " · " + root.activePlayer.identity : ""))
            : ""
          color: Color.lock.placeholder
          font.family: Style.font.family
          font.pixelSize: Math.round(Style.font.heading * 1.0)
          verticalAlignment: Text.AlignVCenter
          elide: Text.ElideRight
          width: Math.min(implicitWidth, root.width - Style.space(80))
        }
      }

      Row {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Style.space(18)

        Text {
          text: "󰒮"
          color: Color.lock.text
          font.family: Style.font.family
          font.pixelSize: Math.round(Style.font.heading * 1.4)
          visible: root.activePlayer && root.activePlayer.canGoPrevious
          MouseArea {
            anchors.fill: parent
            onClicked: { if (root.activePlayer) root.activePlayer.previous() }
          }
        }

        Text {
          text: root.activePlayer && root.activePlayer.isPlaying ? "󰏤" : "󰐊"
          color: Color.lock.text
          font.family: Style.font.family
          font.pixelSize: Math.round(Style.font.heading * 1.4)
          MouseArea {
            anchors.fill: parent
            onClicked: { if (root.activePlayer) root.activePlayer.togglePlaying() }
          }
        }

        Text {
          text: "󰒭"
          color: Color.lock.text
          font.family: Style.font.family
          font.pixelSize: Math.round(Style.font.heading * 1.4)
          visible: root.activePlayer && root.activePlayer.canGoNext
          MouseArea {
            anchors.fill: parent
            onClicked: { if (root.activePlayer) root.activePlayer.next() }
          }
        }
      }
    }

    Row {
      id: volumeRow
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.top: musicColumn.visible ? musicColumn.bottom : inputField.bottom
      anchors.topMargin: Style.space(12)
      spacing: Style.space(18)

      Text {
        text: root.volumeIcon()
        color: Color.lock.text
        font.family: Style.font.family
        font.pixelSize: Math.round(Style.font.heading * 1.4)
        verticalAlignment: Text.AlignVCenter
        MouseArea {
          anchors.fill: parent
          onClicked: root.toggleOutputMute()
        }
      }

      PanelSlider {
        id: volumeSlider
        bar: null
        minimum: 0
        maximum: 1
        step: 0.05
        value: root.outputVolume
        onMoved: function(v) { root.setOutputVolume(v) }
        onRightClicked: root.toggleOutputMute()
        implicitWidth: Style.space(200)
        implicitHeight: Style.space(26)
      }
    }

    AnimatedImage {
      id: sideAnim
      source: Qt.resolvedUrl("omarchy2.webp")
      anchors.bottom: clockColumn.top
      anchors.bottomMargin: Style.space(16)
      anchors.horizontalCenter: parent.horizontalCenter
      width: Style.space(240)
      height: width * 226 / 400
      fillMode: Image.PreserveAspectCrop
      asynchronous: true
      cache: false
      playing: true
      smooth: true
    }

    BorderSurface {
      id: inputField
      width: root.fieldWidth
      height: root.fieldHeight
      anchors.centerIn: parent
      color: Color.lock.background
      borderSpec: root.inputBorderSpec
      radius: Style.cornerRadius
      clip: true

      TextInput {
        id: passwordInput
        anchors.fill: parent
        anchors.topMargin: inputField.borderTop
        // Reserve the fingerprint icon's width on both sides so the centered
        // dots stay symmetric and never slide under the icon as they grow.
        anchors.rightMargin: inputField.borderRight + 18 + root.fingerprintReserve
        anchors.bottomMargin: inputField.borderBottom
        anchors.leftMargin: inputField.borderLeft + 18 + root.fingerprintReserve
        verticalAlignment: TextInput.AlignVCenter
        horizontalAlignment: TextInput.AlignHCenter
        activeFocusOnPress: true
        clip: true
        enabled: root.inputEnabled && !root.authenticatingPassword
        readOnly: root.authenticatingPassword
        echoMode: TextInput.Password
        passwordCharacter: "\u25CF"
        passwordMaskDelay: 0
        color: Color.lock.text
        selectionColor: Color.lock.selection
        selectedTextColor: Color.lock.text
        font.family: Style.font.family
        font.pixelSize: text.length > 0 ? Math.max(1, Math.floor(root.passwordDotFontSize * root.passwordDotScale)) : root.fieldFontSize
        font.letterSpacing: text.length > 0 ? root.passwordDotLetterSpacing * root.passwordDotScale : 0
        cursorVisible: activeFocus && root.showPasswordCursor && text.length > 0
        cursorDelegate: Rectangle {
          width: 2
          color: Color.lock.text
          visible: passwordInput.cursorVisible
        }

        onTextChanged: {
          if (!root.syncingPasswordText) root.passwordTextEdited(text)
          if (text.length > 0) {
            root.wakeRequested()
          }
          if (text.length > 0 && root.failureMessage.length > 0) root.clearFailureRequested()
        }

        onAccepted: {
          var submitted = root.passwordText
          root.passwordTextEdited("")
          if (submitted.length > 0) root.submitPassword(submitted)
        }

        Keys.onPressed: function(event) {
          root.wakeRequested()
          if (event.key === Qt.Key_Escape || (event.modifiers & Qt.ControlModifier && event.key === Qt.Key_U)) {
            root.passwordTextEdited("")
            event.accepted = true
          }
        }
      }

      Text {
        anchors.fill: passwordInput
        text: root.authenticatingPassword ? "Checking…" : (root.failureMessage.length > 0 ? root.failureMessage : root.placeholderText)
        visible: passwordInput.text.length === 0
        color: root.authenticatingPassword ? Color.lock.text : (root.failureMessage.length > 0 ? Color.lock.textError : Color.lock.placeholder)
        font.family: Style.font.family
        font.pixelSize: root.fieldFontSize
        font.italic: !root.authenticatingPassword && root.failureMessage.length > 0
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
      }

      // Fingerprint hint pinned inside the field's right edge when a sensor is
      // enrolled, so the user knows they can touch to unlock instead of typing.
      // Matches hyprlock, which draws its fingerprint icon in the same spot.
      Text {
        id: fingerprintIcon
        objectName: "fingerprintIndicator"
        anchors.right: parent.right
        anchors.rightMargin: inputField.borderRight + 18
        anchors.verticalCenter: parent.verticalCenter
        visible: root.fingerprintConfigured
        text: "󰈷"
        color: Color.lock.placeholder
        font.family: Style.font.family
        font.pixelSize: Math.round(root.fieldFontSize * 1.1)
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
      }
    }
  }
}

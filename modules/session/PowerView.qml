pragma ComponentBehavior: Bound

import QtQuick
import M3Shapes
import Caelestia.Components
import Caelestia.Config
import Caelestia.I18n
import qs.components
import "Dial.js" as Dial

Item {
    id: root

    signal dismissed
    signal actionRequested(string action)
    signal selectionTicked

    required property var colours
    property var actions: Dial.actions
    property string fontFamily: "GoogleSansFlex"
    property string iconFontFamily: "Material Symbols Rounded"

    property bool twelveHourClock: false
    property string timeHours: ""
    property string timeMinutes: ""
    property string timeAmPm: ""
    property string dateWeekday: ""
    property string dateMonthDay: ""

    property string barPosition: "left"
    property real borderThickness: 10
    property real borderRounding: 25
    property bool transparentMode: false
    property bool lightSurface: false

    property bool useVacuitedLogo: true
    property string mascotPath: ""
    property real mascotSpeed: 0.7
    property int mascotRevision: 0
    property int idleHeroShape: MaterialShape.Flower
    property string facePath: ""
    property string dateFormatted: ""
    property string dialStyle: "rim"

    property real reveal: 1
    property real backdropReveal: reveal
    property real contentReveal: 1
    property real clockReveal: contentReveal
    property real detailsReveal: contentReveal
    property real dialReveal: contentReveal
    property real cornerReveal: 1
    property real dialExpansion: 1
    property real handleMorph: Math.max(0, Math.min(1, cornerReveal))
    property font normalPowerFont: Qt.font({ family: "Material Symbols Rounded", pixelSize: 22 })
    property color normalPowerColour: colours.m3error
    property matrix4x4 dialDeformMatrix: Qt.matrix4x4(1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
    property bool acceptingInput: true
    property bool trackingPointer: acceptingInput
    property bool confirmDangerous: true
    property bool statusChipsEnabled: true
    property bool recordingActive: false
    property bool keepAwakeActive: false
    readonly property bool hasStatusChips: statusChipsEnabled && (recordingActive || keepAwakeActive)
    property bool pointerInitialized: false
    property bool initializingPointer: false
    property int selected: -1
    property real angle: 0
    property bool dragging: false
    property bool pressedOnCenter: false
    property string armedActionId: ""
    property real logoPointerX: 0
    property real logoPointerY: 0
    property real logoHover: 0
    property real wheelAccum: 0
    property bool clockRunning: false
    property date now: new Date()

    readonly property real unit: (width > 0 && height > 0) ? Math.max(0.25, Math.min(width / 1920, height / 1200)) : 1
    property bool horizontalBar: false
    property bool flipDialX: false
    property bool flipDialY: false
    readonly property real logicalCenterX: flipDialX ? width - centerX : centerX
    readonly property real logicalCenterY: flipDialY ? height - centerY : centerY
    property real railWidth: 58 * unit
    property point dialOrigin: Qt.point(28 * unit, height - 32 * unit)
    readonly property real centerX: dialOrigin.x
    readonly property real centerY: dialOrigin.y
    readonly property real handleScale: Math.min(unit, Math.max(1, railWidth - 4) / 54)

    readonly property var action: (selected >= 0 && selected < actions.length) ? actions[selected] : null
    readonly property bool isDanger: action?.dangerous === true
    readonly property color accent: isDanger ? colours.m3error : colours.m3primary
    readonly property color accentForeground: isDanger ? colours.m3onError : colours.m3onPrimary

    property color baseColour: colours.m3surfaceContainerLowest
    property color panelColour: colours.m3surface
    property color panelEdgeColour: colours.m3surfaceContainerHigh
    property color optionColour: colours.m3surfaceContainerHigh
    readonly property color outlineColour: colours.m3outlineVariant
    property color glowColor: accent
    property color displayAccent: accent
    property color displayForeground: accentForeground
    readonly property color foreground: colours.m3onSurface

    readonly property string hoursText: root.timeHours !== "" ? root.timeHours : Qt.formatDateTime(root.now, root.twelveHourClock ? "hh ap" : "HH").split(" ")[0]
    readonly property string minutesText: root.timeMinutes !== "" ? root.timeMinutes : Qt.formatDateTime(root.now, "mm")
    readonly property string amPmText: root.twelveHourClock ? (root.timeAmPm !== "" ? root.timeAmPm : Qt.formatDateTime(root.now, "ap")).toLowerCase() : ""
    readonly property string weekdayText: root.dateWeekday !== "" ? root.dateWeekday : Qt.formatDateTime(root.now, "dddd")
    readonly property string monthDayText: root.dateMonthDay !== "" ? root.dateMonthDay : Qt.formatDateTime(root.now, "MMMM d")

    function resolvedAssetUrl(path: string, rev: int): string {
        if (!path)
            return "";
        const base = path.includes("://") ? path : ("file://" + path);
        return rev > 0 ? (base + "?v=" + rev) : base;
    }

    function resolveShape(name: string): int {
        switch (name) {
        case "Gem":
            return MaterialShape.Gem;
        case "Arch":
            return MaterialShape.Arch;
        case "SoftBurst":
            return MaterialShape.SoftBurst;
        case "Clover4Leaf":
            return MaterialShape.Clover4Leaf;
        case "Cookie7Sided":
            return MaterialShape.Cookie7Sided;
        case "Sunny":
            return MaterialShape.Sunny;
        case "Puffy":
            return MaterialShape.Puffy;
        case "Pentagon":
            return MaterialShape.Pentagon;
        case "ClamShell":
            return MaterialShape.ClamShell;
        case "Cookie6Sided":
            return MaterialShape.Cookie6Sided;
        case "Flower":
            return MaterialShape.Flower;
        default:
            return MaterialShape.Cookie9Sided;
        }
    }

    function triggerLogoSurge(): void {
        const item = mascotLoader.item as VoidLogo;
        if (item && typeof item.surge === "function")
            item.surge();
    }

    function syncLogoFromAngle(): void {
        if (selected < 0) {
            logoPointerX = 0;
            logoPointerY = 0;
            logoHover = 0;
            return;
        }
        const rad = -angle * Math.PI / 180;
        logoPointerX = Math.cos(rad) * (flipDialX ? -0.85 : 0.85);
        logoPointerY = Math.sin(rad) * (flipDialY ? -0.85 : 0.85);
        logoHover = 1.0;
    }

    function reset(): void {
        selected = -1;
        angle = 0;
        dragging = false;
        pressedOnCenter = false;
        armedActionId = "";
        wheelAccum = 0;
        logoPointerX = 0;
        logoPointerY = 0;
        logoHover = 0;
        confirmResetTimer.stop();
        wheelResetTimer.stop();
        pointerInitialized = false;
        now = new Date();
        if (visible)
            forceActiveFocus();
    }

    function initializePointer(x: real, y: real): void {
        initializingPointer = true;
        reset();
        updatePointer(x, y);
        pointerInitialized = true;
        details.show(selected, false);
        initializingPointer = false;
    }

    function updatePointer(x: real, y: real): void {
        const dx = (x - centerX) * (flipDialX ? -1 : 1);
        const dy = (y - centerY) * (flipDialY ? -1 : 1);
        const distance = Math.sqrt(dx * dx + dy * dy) / unit;
        selected = Dial.selectionAt(dx, dy, unit, actions);
        angle = distance < 64 ? 0 : Math.max(0, Math.min(90, Dial.angleAt(dx, dy)));

        const mx = mascotSlot.x + mascotSlot.width / 2;
        const my = mascotSlot.y + mascotSlot.height / 2;
        const normScale = Math.max(1, 320 * unit);
        logoPointerX = Math.max(-1, Math.min(1, (x - mx) / normScale));
        logoPointerY = Math.max(-1, Math.min(1, (y - my) / normScale));
        logoHover = selected >= 0 ? 1.0 : Math.max(0, 1 - Math.hypot(x - mx, y - my) / (520 * unit)) * 0.65;
    }

    function step(direction: int): void {
        if (!actions || actions.length === 0)
            return;
        selected = selected < 0 ? (direction > 0 ? 0 : actions.length - 1) : (selected + direction + actions.length) % actions.length;
        angle = actions[selected].angle;
        syncLogoFromAngle();
    }

    function activate(): void {
        if (selected < 0 || selected >= actions.length)
            return;
        const act = actions[selected];
        if (confirmDangerous && (act.confirmable === true || act.dangerous === true) && armedActionId !== act.id) {
            armedActionId = act.id;
            confirmResetTimer.restart();
            triggerLogoSurge();
            selectionTicked();
            return;
        }
        armedActionId = "";
        confirmResetTimer.stop();
        triggerLogoSurge();
        actionRequested(act.id);
    }

    focus: visible
    onSelectedChanged: {
        if (!action || action.id !== armedActionId) {
            armedActionId = "";
            confirmResetTimer.stop();
        }
        if (!initializingPointer && acceptingInput && visible && selected >= 0) {
            triggerLogoSurge();
            selectionTicked();
        }
    }
    onVisibleChanged: {
        if (visible)
            forceActiveFocus();
    }
    Component.onCompleted: reset()

    Behavior on glowColor {
        enabled: !root.initializingPointer
        CAnim {}
    }
    Behavior on displayAccent {
        enabled: !root.initializingPointer
        CAnim {}
    }
    Behavior on displayForeground {
        enabled: !root.initializingPointer
        CAnim {}
    }

    // Standalone fallback clock timer (suppressed in live shell where Time singleton feeds strings)
    Timer {
        interval: 1000
        running: root.visible && root.clockRunning && root.timeHours === ""
        repeat: true
        onTriggered: root.now = new Date()
    }

    Timer {
        id: confirmResetTimer

        interval: 4000
        onTriggered: root.armedActionId = ""
    }

    Timer {
        id: wheelResetTimer

        interval: 180
        onTriggered: root.wheelAccum = 0
    }

    Item {
        id: surface

        objectName: "powerMenuSurface"
        anchors.fill: parent

        PowerBackdrop {
            anchors.fill: parent
            unit: root.unit
            centerX: root.centerX
            centerY: root.centerY
            railWidth: root.railWidth
            barPosition: root.barPosition
            borderThickness: root.borderThickness
            borderRounding: root.borderRounding
            cornerReveal: root.cornerReveal
            frameReveal: root.reveal
            backdropReveal: root.backdropReveal
            baseColour: root.baseColour
            panelColour: root.panelColour
            panelEdgeColour: root.panelEdgeColour
            outlineColour: root.outlineColour
            glowColour: root.glowColor
        }

        // Fixed reference-sized canvas keeps proportions uniform across monitor resolutions.
        Item {
            width: root.width / root.unit
            height: root.height / root.unit
            scale: root.unit
            transformOrigin: Item.TopLeft

            Item {
                id: clock

                objectName: "powerMenuClock"
                x: parent.width / 2 - width / 2
                y: parent.height * 0.095 + (1 - root.clockReveal) * 20
                width: timeRow.implicitWidth
                height: timeRow.implicitHeight
                opacity: Math.max(0, Math.min(1, root.clockReveal))
                scale: 0.92 + 0.08 * root.clockReveal
                transformOrigin: Item.Center

                Row {
                    id: timeRow

                    spacing: 14

                    Text {
                        renderType: Text.CurveRendering
                        text: root.hoursText
                        color: root.colours.m3primary
                        font.family: root.fontFamily
                        font.pixelSize: 224
                        font.variableAxes: ({
                            "wght": 750,
                            "wdth": 30,
                            "ROND": 100
                        })
                    }

                    Column {
                        spacing: 10
                        anchors.top: parent.top

                        Text {
                            renderType: Text.CurveRendering
                            text: root.minutesText
                            color: root.colours.m3secondary
                            font.family: root.fontFamily
                            font.pixelSize: root.twelveHourClock ? 124 : 224
                            font.variableAxes: ({
                                "wght": 750,
                                "wdth": 30,
                                "ROND": 100
                            })
                        }

                        Rectangle {
                            visible: root.twelveHourClock && root.amPmText !== ""
                            width: parent.width
                            height: amPmTextItem.implicitHeight + 18
                            radius: 16
                            color: root.colours.m3surfaceContainerHigh

                            Text {
                                id: amPmTextItem

                                renderType: Text.CurveRendering
                                anchors.centerIn: parent
                                text: root.amPmText.toUpperCase()
                                color: root.colours.m3onSurface
                                font.family: root.fontFamily
                                font.pixelSize: 42
                                font.variableAxes: ({
                                    "wght": 700,
                                    "wdth": 30,
                                    "ROND": 100
                                })
                            }
                        }
                    }
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                y: parent.height * 0.318 + (1 - root.clockReveal) * 16
                opacity: Math.max(0, Math.min(1, root.clockReveal))
                scale: 0.94 + 0.06 * root.clockReveal
                transformOrigin: Item.Center
                renderType: Text.CurveRendering
                text: (root.dateFormatted !== "" ? root.dateFormatted : (root.weekdayText + " • " + root.monthDayText)).toUpperCase()
                color: root.colours.m3onSurface
                font.family: root.fontFamily
                font.pixelSize: 24
                font.letterSpacing: 1.6
                font.variableAxes: ({
                    "wght": 650,
                    "ROND": 100
                })
            }

            Row {
                objectName: "powerMenuStatusChips"
                anchors.horizontalCenter: parent.horizontalCenter
                y: parent.height * 0.365 + (1 - root.detailsReveal) * 16
                spacing: 10
                visible: root.hasStatusChips
                opacity: Math.max(0, Math.min(1, root.detailsReveal))

                Rectangle {
                    visible: root.statusChipsEnabled && root.recordingActive
                    height: 30
                    width: recordingRow.implicitWidth + 24
                    radius: 15
                    color: root.colours.m3errorContainer

                    Row {
                        id: recordingRow

                        anchors.centerIn: parent
                        spacing: 6

                        Text {
                            renderType: Text.CurveRendering
                            anchors.verticalCenter: parent.verticalCenter
                            text: "fiber_manual_record"
                            color: root.colours.m3onErrorContainer
                            font.family: root.iconFontFamily
                            font.pixelSize: 15
                            font.variableAxes: ({ "FILL": 1, "wght": 600, "GRAD": 0, "opsz": 20 })
                        }

                        Text {
                            renderType: Text.CurveRendering
                            anchors.verticalCenter: parent.verticalCenter
                            text: Tr.tr("Recording active")
                            color: root.colours.m3onErrorContainer
                            font.family: root.fontFamily
                            font.pixelSize: 13
                            font.variableAxes: ({ "wght": 600, "ROND": 100 })
                        }
                    }
                }

                Rectangle {
                    visible: root.statusChipsEnabled && root.keepAwakeActive
                    height: 30
                    width: keepAwakeRow.implicitWidth + 24
                    radius: 15
                    color: root.colours.m3tertiaryContainer

                    Row {
                        id: keepAwakeRow

                        anchors.centerIn: parent
                        spacing: 6

                        Text {
                            renderType: Text.CurveRendering
                            anchors.verticalCenter: parent.verticalCenter
                            text: "coffee"
                            color: root.colours.m3onTertiaryContainer
                            font.family: root.iconFontFamily
                            font.pixelSize: 15
                            font.variableAxes: ({ "FILL": 1, "wght": 600, "GRAD": 0, "opsz": 20 })
                        }

                        Text {
                            renderType: Text.CurveRendering
                            anchors.verticalCenter: parent.verticalCenter
                            text: Tr.tr("Keep awake on")
                            color: root.colours.m3onTertiaryContainer
                            font.family: root.fontFamily
                            font.pixelSize: 13
                            font.variableAxes: ({ "wght": 600, "ROND": 100 })
                        }
                    }
                }
            }

            ActionDetails {
                id: details

                objectName: "powerMenuDetails"
                anchors.horizontalCenter: parent.horizontalCenter
                y: parent.height * (root.hasStatusChips ? 0.435 : 0.405) + (1 - root.detailsReveal) * 24
                width: 560
                height: implicitHeight
                opacity: Math.max(0, Math.min(1, root.detailsReveal))
                scale: 0.90 + 0.10 * root.detailsReveal
                transformOrigin: Item.Center
                actions: root.actions
                colours: root.colours
                fontFamily: root.fontFamily
                iconFontFamily: root.iconFontFamily
                selected: root.selected
                immediate: root.initializingPointer || !root.visible
                dragging: root.dragging
                armedActionId: root.armedActionId
                confirmDangerous: root.confirmDangerous
                idleShape: root.idleHeroShape
                facePath: root.facePath
            }
        }
    }

    // Local clipped viewport for diagonal dial reveal & blob deformation.
    Item {
        id: dialViewport

        objectName: "powerMenuDialPopout"
        readonly property real fullWidth: root.logicalCenterX + 450 * root.unit
        readonly property real fullY: Math.max(0, root.logicalCenterY - 450 * root.unit)
        readonly property real fullHeight: root.height - fullY

        x: root.flipDialX ? root.width : 0
        y: root.flipDialY ? height : root.height - height
        transform: Scale {
            xScale: root.flipDialX ? -1 : 1
            yScale: root.flipDialY ? -1 : 1
        }
        width: fullWidth * root.dialExpansion
        height: fullHeight * root.dialExpansion
        clip: true
        opacity: Math.max(0, Math.min(1, root.dialReveal))

        Item {
            objectName: "powerMenuDialSlide"
            x: -(dialViewport.fullWidth + 5 * root.unit) * (1 - root.dialExpansion)
            y: 5 * root.unit * (1 - root.dialExpansion)
            width: dialViewport.fullWidth
            height: dialViewport.fullHeight
            transform: Matrix4x4 { matrix: root.dialDeformMatrix }

            PowerDial {
                colours: root.colours
                actions: root.actions
                width: parent.width / root.unit
                height: parent.height / root.unit
                scale: root.unit
                transformOrigin: Item.TopLeft
                centerX: root.logicalCenterX / root.unit
                centerY: (root.logicalCenterY - dialViewport.fullY) / root.unit
                flipTextX: root.flipDialX
                flipTextY: root.flipDialY
                selected: root.selected
                angle: root.angle
                accent: root.displayAccent
                accentForeground: root.displayForeground
                optionColour: root.optionColour
                immediate: root.initializingPointer
                fontFamily: root.fontFamily
                iconFontFamily: root.iconFontFamily
                dialStyle: root.dialStyle
                reveal: root.dialReveal
            }
        }
    }

    // Center emblem inside the dial pocket: animated VoidLogo by default, or custom Shell Asset.
    Item {
        id: mascotSlot

        objectName: "powerMenuMascot"
        readonly property real cutoutProgress: Math.max(0, Math.min(1, root.cornerReveal))
        readonly property real radialOffset: 68 * root.unit * cutoutProgress

        x: (root.flipDialX ? root.centerX - radialOffset : root.centerX + radialOffset) - width / 2
        y: (root.flipDialY ? root.centerY + radialOffset : root.centerY - radialOffset) - height / 2
        width: 92 * root.unit
        height: 92 * root.unit
        opacity: root.dialReveal * Math.max(0, Math.min(1, (root.cornerReveal - 0.18) / 0.65))
        scale: 0.72 + 0.28 * cutoutProgress
        transformOrigin: Item.Center
        visible: opacity > 0

        WavyLine {
            id: emblemHalo

            readonly property real haloRadius: mascotSlot.width * 0.62
            readonly property real pad: 14

            visible: root.dialStyle === "halo"
            anchors.centerIn: parent
            width: (haloRadius + pad) * 2
            height: width
            lineWidth: Math.max(2, Math.round(3.5 * root.unit))
            color: root.displayAccent
            pathType: WavyLine.Arc
            radius: haloRadius
            startAngle: -90
            fullAngle: 360
            value: 1
            frequency: 8
            amplitudeMultiplier: root.selected >= 0 ? 0.45 : 0
            opacity: root.selected >= 0 ? 0.9 : 0.28

            Anim on waveProgress {
                running: emblemHalo.visible && root.visible && emblemHalo.amplitudeMultiplier > 0.01
                from: 0
                to: 1
                duration: 2400
                easing.type: Easing.Linear
                loops: Animation.Infinite
            }

            Behavior on opacity {
                Anim { type: Anim.FastEffects }
            }
            Behavior on amplitudeMultiplier {
                Anim { type: Anim.DefaultEffects }
            }
            Behavior on color {
                CAnim {}
            }
        }

        Loader {
            id: mascotLoader

            anchors.fill: parent
            active: true
            sourceComponent: (root.useVacuitedLogo || root.mascotPath === "")
                ? vacuitedLogoComp
                : (/\.(gif|webp|apng)(\?.*)?$/i.test(root.mascotPath) ? animatedMascotComp : staticMascotComp)
        }

        Component {
            id: vacuitedLogoComp

            VoidLogo {
                anchors.fill: parent
                interactive: false
                animated: true
                skipIntroAnimation: false
                horizonColor: root.accent
                lightSurface: root.lightSurface
                pointerX: root.logoPointerX
                pointerY: root.logoPointerY
                hoverAmount: root.logoHover
            }
        }

        Component {
            id: animatedMascotComp

            AnimatedImage {
                anchors.fill: parent
                source: root.resolvedAssetUrl(root.mascotPath, root.mascotRevision)
                cache: false
                asynchronous: true
                fillMode: AnimatedImage.PreserveAspectFit
                smooth: true
                playing: visible
                speed: root.mascotSpeed
            }
        }

        Component {
            id: staticMascotComp

            Image {
                anchors.fill: parent
                source: root.resolvedAssetUrl(root.mascotPath, root.mascotRevision)
                sourceSize: Qt.size(Math.max(1, Math.round(width * 2)), Math.max(1, Math.round(height * 2)))
                cache: false
                asynchronous: true
                fillMode: Image.PreserveAspectFit
                smooth: true
                mipmap: true
            }
        }
    }

    // Stationary power handle anchored to the taskbar button outside the dial's transform.
    Item {
        objectName: "powerMenuPowerAnchor"
        x: root.centerX - 27 * root.handleScale
        y: root.centerY - 27 * root.handleScale
        width: 54
        height: 54
        scale: root.handleScale
        transformOrigin: Item.TopLeft
        opacity: 1

        MaterialShape {
            objectName: "powerMenuPowerFlower"
            anchors.fill: parent
            implicitSize: 54
            scale: 0.5 + root.handleMorph * 0.5
            opacity: Math.max(0, Math.min(1, root.handleMorph))
            transformOrigin: Item.Center
            color: root.displayAccent
            shape: root.action ? root.resolveShape(root.action.shape) : MaterialShape.Flower
            animationDuration: Tokens.anim.durations.expressiveFastSpatial
            animationEasing: Tokens.anim.expressiveFastSpatial
            layer.enabled: true
            layer.smooth: true
            layer.mipmap: true
            layer.textureSize: Qt.size(216, 216)
        }

        Text {
            id: normalGlyph

            objectName: "powerMenuNormalPowerGlyph"
            anchors.centerIn: parent
            text: "power_settings_new"
            font: root.normalPowerFont
            color: root.normalPowerColour
            renderType: Text.NativeRendering
            scale: 1 / root.handleScale
            transformOrigin: Item.Center
            opacity: Math.max(0, 1 - root.handleMorph * 2.5)
        }

        TextMetrics {
            id: glyphMetrics
            font: materialGlyph.font
            text: materialGlyph.text
        }

        Text {
            id: materialGlyph

            objectName: "powerMenuMaterialPowerGlyph"
            readonly property real opticalYOffset: root.action?.id === "reboot" ? font.pixelSize * 2.5 / 29 : 0

            x: (parent.width - glyphMetrics.tightBoundingRect.width) / 2 - glyphMetrics.tightBoundingRect.x
            y: (parent.height - glyphMetrics.tightBoundingRect.height) / 2 - glyphMetrics.tightBoundingRect.y - baselineOffset + opticalYOffset
            text: root.action ? root.action.icon : "power_settings_new"
            color: root.displayForeground
            font.family: root.iconFontFamily
            font.pixelSize: 29
            font.variableAxes: ({ "FILL": root.action ? 1 : 0, "wght": 500, "GRAD": 0, "opsz": 29 })
            transform: Scale {
                origin.x: glyphMetrics.tightBoundingRect.x + glyphMetrics.tightBoundingRect.width / 2
                origin.y: materialGlyph.baselineOffset + glyphMetrics.tightBoundingRect.y + glyphMetrics.tightBoundingRect.height / 2 - materialGlyph.opticalYOffset
                xScale: 0.7 + root.handleMorph * 0.3
                yScale: xScale
            }
            renderType: Text.CurveRendering
            opacity: Math.max(0, (root.handleMorph - 0.35) / 0.65)
        }
    }

    MouseArea {
        id: pointer

        property bool entering: false

        anchors.fill: parent
        enabled: root.trackingPointer
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        hoverEnabled: true
        preventStealing: true
        cursorShape: root.dragging || root.selected >= 0 || Math.hypot(mouseX - root.centerX, mouseY - root.centerY) < 64 * root.unit ? Qt.PointingHandCursor : Qt.ArrowCursor

        onEntered: {
            entering = true;
            Qt.callLater(() => entering = false);
            if (root.acceptingInput || !root.pointerInitialized)
                root.updatePointer(mouseX, mouseY);
        }
        onExited: {
            if (root.acceptingInput && !root.dragging) {
                root.selected = -1;
                root.angle = 0;
                root.logoPointerX = 0;
                root.logoPointerY = 0;
                root.logoHover = 0;
            }
        }
        onPressed: mouse => {
            if (!root.acceptingInput)
                return;
            if (mouse.button === Qt.RightButton) {
                root.dragging = false;
                root.pressedOnCenter = false;
                root.dismissed();
                return;
            }
            const dx = mouse.x - root.centerX;
            const dy = mouse.y - root.centerY;
            root.updatePointer(mouse.x, mouse.y);
            const inCenter = Math.hypot(dx, dy) < 64 * root.unit;
            root.pressedOnCenter = inCenter && root.selected < 0;
            root.dragging = root.selected >= 0 || inCenter;
            if (!root.dragging)
                root.dismissed();
        }
        onPositionChanged: mouse => {
            if (!entering)
                root.updatePointer(mouse.x, mouse.y);
        }
        onReleased: mouse => {
            if (!root.acceptingInput) {
                root.dragging = false;
                root.pressedOnCenter = false;
                return;
            }
            if (!root.dragging)
                return;
            root.updatePointer(mouse.x, mouse.y);
            const closeFromCenter = root.pressedOnCenter && root.selected < 0;
            root.pressedOnCenter = false;
            root.dragging = false;
            if (closeFromCenter) {
                root.dismissed();
                return;
            }
            root.activate();
        }
        onCanceled: {
            root.dragging = false;
            root.pressedOnCenter = false;
            if (root.acceptingInput)
                root.selected = -1;
        }
        onWheel: wheel => {
            wheel.accepted = true;
            if (!root.acceptingInput)
                return;
            const delta = wheel.angleDelta.y !== 0 ? wheel.angleDelta.y : wheel.angleDelta.x;
            if (delta === 0)
                return;
            if ((root.wheelAccum > 0 && delta < 0) || (root.wheelAccum < 0 && delta > 0))
                root.wheelAccum = 0;
            root.wheelAccum += delta;
            wheelResetTimer.restart();
            if (Math.abs(root.wheelAccum) >= 90) {
                const dir = (root.wheelAccum > 0 ? -1 : 1) * (root.flipDialY ? -1 : 1);
                root.wheelAccum = 0;
                root.step(dir);
            }
        }
    }

    Keys.onEscapePressed: {
        root.dragging = false;
        root.pressedOnCenter = false;
        root.dismissed();
    }
    Keys.onReturnPressed: if (root.acceptingInput)
        root.activate()
    Keys.onEnterPressed: if (root.acceptingInput)
        root.activate()
    Keys.onPressed: event => {
        if (event.key === Qt.Key_Space && root.acceptingInput) {
            root.activate();
            event.accepted = true;
        } else if (event.key >= Qt.Key_1 && event.key <= Qt.Key_9 && root.acceptingInput) {
            const idx = event.key - Qt.Key_1;
            if (idx < root.actions.length) {
                root.selected = idx;
                root.angle = root.actions[idx].angle;
                root.syncLogoFromAngle();
                event.accepted = true;
            }
        } else if ([Qt.Key_Right, Qt.Key_Down, Qt.Key_Tab, Qt.Key_J, Qt.Key_L].includes(event.key)) {
            root.step(1);
            event.accepted = true;
        } else if ([Qt.Key_Left, Qt.Key_Up, Qt.Key_Backtab, Qt.Key_K, Qt.Key_H].includes(event.key)) {
            root.step(-1);
            event.accepted = true;
        }
    }
}

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Services.UPower
import M3Shapes
import Caelestia.Config
import Caelestia.I18n
import Caelestia.Services
import qs.components
import qs.components.controls
import qs.components.effects
import qs.services
import qs.utils
import "../components"

Item {
    id: root

    required property var wallpaper
    property bool weActive: false
    property bool locked: true
    property string sizeMode: "2x1"
    property real widgetScale: WidgetMetrics.scale
    property string surfaceStyle: ""
    property bool blurEnabled: Config.background.desktopWidgets.blur
    property real plateOpacity: Config.background.desktopWidgets.opacity
    property var widgetOptions: ({})

    readonly property real s: Math.max(0.55, Math.min(2.2, widgetScale > 0 ? widgetScale : WidgetMetrics.scale))
    readonly property string effectiveSize: WidgetMetrics.fallbackSizeFor("resources", sizeMode)
    readonly property string fillStyle: widgetOptions?.fillStyle ?? "shape"
    readonly property string focusMetric: {
        const raw = widgetOptions?.focusMetric ?? "cpu";
        return ["cpu", "ram", "gpu", "disk"].indexOf(raw) >= 0 ? raw : "cpu";
    }
    readonly property bool hasGpu: Gpu.type !== GpuType.None

    readonly property var activeMetricKeys: {
        if (effectiveSize === "1x1")
            return [focusMetric];
        if (effectiveSize === "1x2")
            return ["cpu", "ram"];
        if (effectiveSize === "2x1")
            return hasGpu ? ["cpu", "ram", "gpu"] : ["cpu", "ram", "disk"];
        return hasGpu ? ["cpu", "ram", "gpu", "disk"] : ["cpu", "ram", "disk", "bat"];
    }

    function metricNeedsCpu(): bool {
        return activeMetricKeys.indexOf("cpu") >= 0;
    }

    function metricNeedsRam(): bool {
        return activeMetricKeys.indexOf("ram") >= 0;
    }

    function metricNeedsGpu(): bool {
        return hasGpu && activeMetricKeys.indexOf("gpu") >= 0;
    }

    function metricNeedsDisk(): bool {
        return activeMetricKeys.indexOf("disk") >= 0;
    }

    function metricLabel(kind: string): string {
        switch (kind) {
        case "cpu":
            return Tr.tr("CPU");
        case "ram":
            return Tr.tr("Memory");
        case "gpu":
            return Tr.tr("GPU");
        case "disk":
            return Tr.tr("Storage");
        default:
            return Tr.tr("Battery");
        }
    }

    function metricShape(kind: string): int {
        switch (kind) {
        case "cpu":
            return MaterialShape.Sunny;
        case "ram":
            return MaterialShape.Cookie6Sided;
        case "gpu":
            return MaterialShape.SoftBurst;
        case "disk":
            return MaterialShape.Cookie9Sided;
        default:
            return MaterialShape.Puffy;
        }
    }

    function metricColor(kind: string): color {
        switch (kind) {
        case "cpu":
            return Colours.palette.m3primary;
        case "ram":
            return Colours.palette.m3secondary;
        case "gpu":
            return Colours.palette.m3tertiary;
        case "disk":
            return Colours.palette.m3primary;
        default:
            return ((UPower.displayDevice?.isLaptopBattery ?? false) && (UPower.displayDevice?.percentage ?? 1) <= 0.2)
                ? Colours.palette.m3error
                : Colours.palette.m3tertiary;
        }
    }

    function metricOnColor(kind: string): color {
        switch (kind) {
        case "cpu":
        case "disk":
            return Colours.palette.m3onPrimary;
        case "ram":
            return Colours.palette.m3onSecondary;
        case "gpu":
            return Colours.palette.m3onTertiary;
        default:
            return ((UPower.displayDevice?.isLaptopBattery ?? false) && (UPower.displayDevice?.percentage ?? 1) <= 0.2)
                ? Colours.palette.m3onError
                : Colours.palette.m3onTertiary;
        }
    }

    function metricRatio(kind: string): real {
        if (kind === "cpu")
            return Math.max(0, Math.min(1, Cpu.percentage));
        if (kind === "ram")
            return Math.max(0, Math.min(1, Memory.percentage));
        if (kind === "gpu")
            return Math.max(0, Math.min(1, Gpu.percentage));
        if (kind === "disk")
            return Math.max(0, Math.min(1, Storage.percentage));
        if (UPower.displayDevice?.isLaptopBattery ?? false)
            return Math.max(0, Math.min(1, UPower.displayDevice?.percentage ?? 0));
        return 1.0;
    }

    function metricDetail(kind: string): string {
        if (kind === "cpu")
            return Cpu.temperature > 0 ? Units.formatSensorTemp(Cpu.temperature) : (Cpu.name || Tr.tr("Processor"));
        if (kind === "ram")
            return Units.formatKibUsage(Memory.used, Memory.total);
        if (kind === "gpu")
            return Gpu.temperature > 0 ? Units.formatSensorTemp(Gpu.temperature) : (Gpu.name || Tr.tr("Graphics"));
        if (kind === "disk") {
            const d = Storage.primaryDisk;
            return d ? Units.formatKibUsage(d.used, d.total) : "/";
        }
        return (UPower.displayDevice?.isLaptopBattery ?? false)
            ? `${Math.round((UPower.displayDevice?.percentage ?? 0) * 100)}%`
            : Tr.tr("AC");
    }

    implicitWidth: WidgetMetrics.widthFor(effectiveSize, s)
    implicitHeight: WidgetMetrics.heightFor(effectiveSize, "resources", s)

    Loader {
        active: root.visible && !GameMode.enabled && root.metricNeedsCpu()
        sourceComponent: Component {
            ServiceRef {
                service: Cpu
            }
        }
    }

    Loader {
        active: root.visible && !GameMode.enabled && root.metricNeedsRam()
        sourceComponent: Component {
            ServiceRef {
                service: Memory
            }
        }
    }

    Loader {
        active: root.visible && !GameMode.enabled && root.metricNeedsGpu()
        sourceComponent: Component {
            ServiceRef {
                service: Gpu
            }
        }
    }

    Loader {
        active: root.visible && !GameMode.enabled && root.metricNeedsDisk()
        sourceComponent: Component {
            ServiceRef {
                service: Storage
            }
        }
    }

    WidgetCardShell {
        id: shell

        anchors.fill: parent
        widgetType: "resources"
        sizeMode: root.effectiveSize
        outerShape: root.widgetOptions?.outerShape ?? ""
        wallpaper: root.wallpaper
        weActive: root.weActive
        surfaceStyle: root.surfaceStyle
        blurEnabled: root.blurEnabled
        plateOpacity: root.plateOpacity
        scaleFactor: root.s

        Loader {
            id: layoutLoader

            anchors.fill: parent
            sourceComponent: {
                switch (root.effectiveSize) {
                case "1x2":
                    return layout1x2;
                case "2x1":
                    return layout2x1;
                case "2x2":
                    return layout2x2;
                case "1x3":
                    return layout1x3;
                default:
                    return layout1x1;
                }
            }
        }
    }

    // 1x1 Single Expressive Metric Tile
    Component {
        id: layout1x1

        Item {
            clip: true

            ColumnLayout {
                anchors.centerIn: parent
                width: Math.max(24, parent.width - shell.sidePadding * 2)
                spacing: Math.max(2, Math.round(4 * root.s))

                GaugeBadge {
                    Layout.alignment: Qt.AlignHCenter
                    kind: root.focusMetric
                    gaugeSize: Math.max(36, Math.round(Math.min((shell.isShaped ? 64 : 74) * root.s, shell.safeInnerBox - Math.round(22 * root.s))))
                    activeLayout: root.effectiveSize === "1x1"
                }

                StyledText {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    horizontalAlignment: Text.AlignHCenter
                    text: root.metricLabel(root.focusMetric) + " · " + root.metricDetail(root.focusMetric)
                    font: Tokens.font.label.builders.small.scale(WidgetMetrics.safeFontScale(root.s, 0.86)).weight(Font.DemiBold).build()
                    color: Colours.palette.m3onSurfaceVariant
                    elide: Text.ElideRight
                }
            }
        }
    }

    // 1x2 Dual Horizontal Telemetry
    Component {
        id: layout1x2

        RowLayout {
            anchors.fill: parent
            anchors.margins: shell.contentPadding
            spacing: Math.max(6, Math.round(Tokens.spacing.medium * root.s))

            Repeater {
                model: root.activeMetricKeys

                delegate: StyledRect {
                    id: dualTile

                    required property string modelData

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumWidth: 0
                    implicitWidth: Math.round(80 * root.s)
                    clip: true
                    radius: Math.round(Tokens.rounding.large * Math.min(1.2, Math.max(0.75, root.s)))
                    color: shell.innerSurface
                    border.width: 1
                    border.color: shell.innerBorder

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: Math.max(4, Math.round(Tokens.padding.small * root.s))
                        spacing: Math.max(2, Math.round(3 * root.s))

                        Item { Layout.fillHeight: true }

                        GaugeBadge {
                            Layout.alignment: Qt.AlignHCenter
                            kind: dualTile.modelData
                            gaugeSize: Math.max(32, Math.round(62 * root.s))
                            activeLayout: root.effectiveSize === "1x2"
                        }

                        StyledText {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            horizontalAlignment: Text.AlignHCenter
                            text: root.metricLabel(dualTile.modelData)
                            font: Tokens.font.label.builders.medium.scale(WidgetMetrics.safeFontScale(root.s, 0.94)).weight(Font.Bold).build()
                            color: Colours.palette.m3onSurface
                            elide: Text.ElideRight
                        }

                        StyledText {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            horizontalAlignment: Text.AlignHCenter
                            text: root.metricDetail(dualTile.modelData)
                            font: Tokens.font.label.builders.small.scale(WidgetMetrics.safeFontScale(root.s, 0.88)).build()
                            color: Colours.palette.m3onSurfaceVariant
                            elide: Text.ElideRight
                        }

                        Item { Layout.fillHeight: true }
                    }
                }
            }
        }
    }

    // 2x1 Tall Vertical Column (3 Stacked Gauges)
    Component {
        id: layout2x1

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: shell.contentPadding
            spacing: Math.max(4, Math.round(Tokens.spacing.small * root.s))

            WidgetHeader {
                Layout.fillWidth: true
                title: Tr.tr("System")
                icon: "monitoring"
                scaleFactor: root.s
            }

            Repeater {
                model: root.activeMetricKeys

                delegate: StyledRect {
                    id: colMeter

                    required property string modelData

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumWidth: 0
                    implicitHeight: Math.round(60 * root.s)
                    clip: true
                    radius: Math.round(Tokens.rounding.large * Math.min(1.2, Math.max(0.75, root.s)))
                    color: shell.innerSurface
                    border.width: 1
                    border.color: shell.innerBorder

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: Math.max(4, Math.round(8 * root.s))
                        spacing: Math.max(4, Math.round(8 * root.s))

                        GaugeBadge {
                            Layout.alignment: Qt.AlignVCenter
                            kind: colMeter.modelData
                            gaugeSize: Math.max(28, Math.round(44 * root.s))
                            activeLayout: root.effectiveSize === "2x1"
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            Layout.alignment: Qt.AlignVCenter
                            spacing: 0

                            StyledText {
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                text: root.metricLabel(colMeter.modelData)
                                font: Tokens.font.label.builders.medium.scale(WidgetMetrics.safeFontScale(root.s, 0.92)).weight(Font.Bold).build()
                                color: Colours.palette.m3onSurface
                                elide: Text.ElideRight
                            }

                            StyledText {
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                text: root.metricDetail(colMeter.modelData)
                                font: Tokens.font.label.builders.small.scale(WidgetMetrics.safeFontScale(root.s, 0.86)).build()
                                color: Colours.palette.m3onSurfaceVariant
                                elide: Text.ElideRight
                            }
                        }
                    }
                }
            }
        }
    }

    // 2x2 Quad Resource Grid
    Component {
        id: layout2x2

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: shell.contentPadding
            spacing: Math.max(4, Math.round(Tokens.spacing.small * root.s))

            WidgetHeader {
                Layout.fillWidth: true
                title: SysInfo.hostname || Tr.tr("Resources")
                icon: "monitoring"
                scaleFactor: root.s
            }

            GridLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                columns: 2
                rowSpacing: Math.max(4, Math.round(Tokens.spacing.small * root.s))
                columnSpacing: Math.max(4, Math.round(Tokens.spacing.small * root.s))

                Repeater {
                    model: root.activeMetricKeys

                    delegate: StyledRect {
                        id: sqMeter

                        required property string modelData

                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.minimumWidth: 0
                        implicitWidth: Math.round(80 * root.s)
                        implicitHeight: Math.round(80 * root.s)
                        clip: true
                        radius: Math.round(Tokens.rounding.large * Math.min(1.2, Math.max(0.75, root.s)))
                        color: shell.innerSurface
                        border.width: 1
                        border.color: shell.innerBorder

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: Math.max(4, Math.round(Tokens.padding.small * root.s))
                            spacing: Math.max(2, Math.round(3 * root.s))

                            Item { Layout.fillHeight: true }

                            GaugeBadge {
                                Layout.alignment: Qt.AlignHCenter
                                kind: sqMeter.modelData
                                gaugeSize: Math.max(32, Math.round(58 * root.s))
                                activeLayout: root.effectiveSize === "2x2"
                            }

                            StyledText {
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                horizontalAlignment: Text.AlignHCenter
                                text: root.metricLabel(sqMeter.modelData)
                                font: Tokens.font.label.builders.medium.scale(WidgetMetrics.safeFontScale(root.s, 0.94)).weight(Font.Bold).build()
                                color: Colours.palette.m3onSurface
                                elide: Text.ElideRight
                            }

                            StyledText {
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                horizontalAlignment: Text.AlignHCenter
                                text: root.metricDetail(sqMeter.modelData)
                                font: Tokens.font.label.builders.small.scale(WidgetMetrics.safeFontScale(root.s, 0.88)).build()
                                color: Colours.palette.m3onSurfaceVariant
                                elide: Text.ElideRight
                            }

                            Item { Layout.fillHeight: true }
                        }
                    }
                }
            }
        }
    }

    // 1x3 Ultra-Wide Telemetry Bar
    Component {
        id: layout1x3

        RowLayout {
            anchors.fill: parent
            anchors.margins: shell.contentPadding
            spacing: Math.max(4, Math.round(Tokens.spacing.small * root.s))

            Repeater {
                model: root.activeMetricKeys

                delegate: StyledRect {
                    id: wideStripCard

                    required property string modelData

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumWidth: 0
                    implicitWidth: Math.round(80 * root.s)
                    clip: true
                    radius: Math.round(Tokens.rounding.large * Math.min(1.2, Math.max(0.75, root.s)))
                    color: shell.innerSurface
                    border.width: 1
                    border.color: shell.innerBorder

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: Math.max(4, Math.round(Tokens.padding.small * root.s))
                        spacing: Math.max(2, Math.round(3 * root.s))

                        Item { Layout.fillHeight: true }

                        GaugeBadge {
                            Layout.alignment: Qt.AlignHCenter
                            kind: wideStripCard.modelData
                            gaugeSize: Math.max(32, Math.round(60 * root.s))
                            activeLayout: root.effectiveSize === "1x3"
                        }

                        StyledText {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            horizontalAlignment: Text.AlignHCenter
                            text: root.metricLabel(wideStripCard.modelData)
                            font: Tokens.font.label.builders.small.scale(WidgetMetrics.safeFontScale(root.s, 0.94)).weight(Font.Bold).build()
                            color: Colours.palette.m3onSurface
                            elide: Text.ElideRight
                        }

                        StyledText {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            horizontalAlignment: Text.AlignHCenter
                            text: root.metricDetail(wideStripCard.modelData)
                            font: Tokens.font.label.builders.small.scale(WidgetMetrics.safeFontScale(root.s, 0.85)).build()
                            color: Colours.palette.m3onSurfaceVariant
                            elide: Text.ElideRight
                        }

                        Item { Layout.fillHeight: true }
                    }
                }
            }
        }
    }

    component GaugeBadge: Item {
        id: gRoot

        property string kind: "cpu"
        property int gaugeSize: 64
        property bool showPercent: true
        property bool activeLayout: false

        readonly property real pct: root.metricRatio(kind)
        readonly property color col: root.metricColor(kind)
        readonly property color onCol: root.metricOnColor(kind)
        readonly property bool isShapeMode: root.fillStyle === "shape"
        readonly property bool shapeLayerActive: root.visible && activeLayout && isShapeMode && !GameMode.enabled && width > 0 && height > 0
        readonly property int shapeEnum: root.metricShape(kind)

        implicitWidth: Math.max(16, Math.round(gaugeSize))
        implicitHeight: Math.max(16, Math.round(gaugeSize))

        // Expressive MaterialShape Fill Gauge
        Item {
            anchors.fill: parent
            visible: gRoot.isShapeMode && !GameMode.enabled

            MaterialShape {
                id: gMask

                anchors.fill: parent
                implicitSize: gRoot.implicitWidth
                visible: false
                layer.enabled: gRoot.shapeLayerActive
                shape: gRoot.shapeEnum
                color: "#ffffff"
            }

            Item {
                anchors.fill: parent
                layer.enabled: gRoot.shapeLayerActive
                layer.smooth: true
                layer.effect: Mask {
                    maskSource: gMask
                    maskThresholdMin: 0.5
                    maskSpreadAtMin: 1.0
                }

                Rectangle {
                    anchors.fill: parent
                    color: shell.innerSurfaceStrong
                }

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: Math.max(4, Math.round(parent.height * gRoot.pct))
                    color: Qt.alpha(gRoot.col, shell.isMaterial ? 0.88 : 0.72)

                    Behavior on height {
                        NumberAnimation {
                            duration: Tokens.anim.durations.expressiveDefaultEffects
                        }
                    }
                }
            }

            StyledText {
                anchors.centerIn: parent
                visible: gRoot.showPercent
                text: Math.round(gRoot.pct * 100) + "%"
                font: Tokens.font.clock.size(Math.max(8, Math.round(gRoot.gaugeSize * 0.24))).weight(Font.Bold).build()
                color: gRoot.pct > 0.55 ? gRoot.onCol : Colours.palette.m3onSurface
            }
        }

        // Classic Circular Progress Ring Gauge (also used when GameMode disables FBO masking)
        Item {
            anchors.fill: parent
            visible: !gRoot.isShapeMode || GameMode.enabled

            CircularProgress {
                anchors.fill: parent
                value: gRoot.pct
                strokeWidth: Math.max(3, Math.round(gRoot.gaugeSize * 0.11))
                fgColour: gRoot.col
                bgColour: shell.trackSurface
                implicitSize: gRoot.implicitWidth
            }

            StyledText {
                anchors.centerIn: parent
                visible: gRoot.showPercent
                text: Math.round(gRoot.pct * 100) + "%"
                font: Tokens.font.clock.size(Math.max(8, Math.round(gRoot.gaugeSize * 0.24))).weight(Font.Bold).build()
                color: Colours.palette.m3onSurface
            }
        }
    }
}

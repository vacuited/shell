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
    property string surfaceStyle: ""
    property bool blurEnabled: Config.background.desktopWidgets.blur
    property real plateOpacity: Config.background.desktopWidgets.opacity
    property var widgetOptions: ({})

    readonly property real s: Math.max(0.7, Math.min(1.5, Config.background.desktopWidgets.scale ?? 1.0))
    readonly property string fillStyle: widgetOptions?.fillStyle ?? "shape"
    readonly property string focusMetric: {
        const raw = widgetOptions?.focusMetric ?? "cpu";
        return ["cpu", "ram", "gpu", "disk"].indexOf(raw) >= 0 ? raw : "cpu";
    }
    readonly property bool hasGpu: Gpu.type !== GpuType.None

    readonly property var activeMetricKeys: {
        if (sizeMode === "1x1")
            return [focusMetric];
        if (sizeMode === "1x2")
            return ["cpu", "ram"];
        if (sizeMode === "2x1")
            return hasGpu ? ["cpu", "ram", "gpu"] : ["cpu", "ram", "disk"];
        return hasGpu ? ["cpu", "ram", "gpu", "disk"] : ["cpu", "ram", "disk", "bat"];
    }

    function metricNeedsCpu(): bool {
        return activeMetricKeys.indexOf("cpu") >= 0 || sizeMode === "2x3";
    }

    function metricNeedsRam(): bool {
        return activeMetricKeys.indexOf("ram") >= 0 || sizeMode === "2x3";
    }

    function metricNeedsGpu(): bool {
        return hasGpu && (activeMetricKeys.indexOf("gpu") >= 0 || sizeMode === "2x3");
    }

    function metricNeedsDisk(): bool {
        return activeMetricKeys.indexOf("disk") >= 0 || sizeMode === "2x3";
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

    function metricIcon(kind: string): string {
        switch (kind) {
        case "cpu":
            return "memory";
        case "ram":
            return "memory_alt";
        case "gpu":
            return "developer_board";
        case "disk":
            return "hard_drive";
        default:
            return "battery_full";
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

    implicitWidth: WidgetMetrics.widthFor(sizeMode, s)
    implicitHeight: WidgetMetrics.heightFor(sizeMode, "resources", s)

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
        sizeMode: root.sizeMode
        outerShape: root.widgetOptions?.outerShape ?? ""
        wallpaper: root.wallpaper
        weActive: root.weActive
        surfaceStyle: root.surfaceStyle
        blurEnabled: root.blurEnabled
        plateOpacity: root.plateOpacity
        scaleFactor: root.s

        // 1x1 Single Expressive Metric Tile
        Item {
            anchors.fill: parent
            anchors.topMargin: shell.topPadding
            anchors.bottomMargin: shell.bottomPadding
            anchors.leftMargin: shell.sidePadding
            anchors.rightMargin: shell.sidePadding
            visible: root.sizeMode === "1x1"

            ColumnLayout {
                anchors.centerIn: parent
                width: parent.width
                spacing: Math.round(4 * root.s)

                GaugeBadge {
                    Layout.alignment: Qt.AlignHCenter
                    kind: root.focusMetric
                    gaugeSize: Math.round((shell.isShaped ? 68 : 78) * root.s)
                    activeLayout: root.sizeMode === "1x1"
                }

                StyledText {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: root.metricLabel(root.focusMetric) + " · " + root.metricDetail(root.focusMetric)
                    font: Tokens.font.label.builders.small.scale(Math.max(0.82, root.s * 0.9)).weight(Font.DemiBold).build()
                    color: Colours.palette.m3onSurfaceVariant
                    elide: Text.ElideRight
                }
            }
        }

        // 1x2 Dual Horizontal Telemetry
        RowLayout {
            anchors.fill: parent
            anchors.margins: shell.contentPadding
            visible: root.sizeMode === "1x2"
            spacing: Math.round(Tokens.spacing.medium * root.s)

            Repeater {
                model: ["cpu", "ram"]

                delegate: StyledRect {
                    id: dualTile

                    required property string modelData

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: Tokens.rounding.large
                    color: WidgetMetrics.innerSurface

                    ColumnLayout {
                        anchors.centerIn: parent
                        width: parent.width - Tokens.padding.small * 2
                        spacing: Math.round(4 * root.s)

                        GaugeBadge {
                            Layout.alignment: Qt.AlignHCenter
                            kind: dualTile.modelData
                            gaugeSize: Math.round(68 * root.s)
                            activeLayout: root.sizeMode === "1x2"
                        }

                        StyledText {
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                            text: root.metricLabel(dualTile.modelData)
                            font: Tokens.font.label.builders.medium.weight(Font.Bold).build()
                            color: Colours.palette.m3onSurface
                            elide: Text.ElideRight
                        }

                        StyledText {
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                            text: root.metricDetail(dualTile.modelData)
                            font: Tokens.font.label.small
                            color: Colours.palette.m3onSurfaceVariant
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }

        // 2x1 Native Dash Vertical Column (3 Stacked Gauges)
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: shell.contentPadding
            visible: root.sizeMode === "2x1"
            spacing: Math.round(Tokens.spacing.small * root.s)

            WidgetHeader {
                Layout.fillWidth: true
                title: Tr.tr("System")
                icon: "monitoring"
            }

            Repeater {
                model: root.activeMetricKeys

                delegate: StyledRect {
                    id: colMeter

                    required property string modelData

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: Tokens.rounding.large
                    color: WidgetMetrics.innerSurface

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: Math.round(8 * root.s)
                        spacing: Math.round(8 * root.s)

                        GaugeBadge {
                            Layout.alignment: Qt.AlignVCenter
                            kind: colMeter.modelData
                            gaugeSize: Math.round(52 * root.s)
                            activeLayout: root.sizeMode === "2x1"
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            spacing: 0

                            StyledText {
                                Layout.fillWidth: true
                                text: root.metricLabel(colMeter.modelData)
                                font: Tokens.font.label.builders.medium.weight(Font.Bold).build()
                                color: Colours.palette.m3onSurface
                                elide: Text.ElideRight
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: root.metricDetail(colMeter.modelData)
                                font: Tokens.font.label.small
                                color: Colours.palette.m3onSurfaceVariant
                                elide: Text.ElideRight
                            }
                        }
                    }
                }
            }
        }

        // 2x2 Quad Resource Grid
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: shell.contentPadding
            visible: root.sizeMode === "2x2"
            spacing: Math.round(Tokens.spacing.small * root.s)

            WidgetHeader {
                Layout.fillWidth: true
                title: SysInfo.hostname || Tr.tr("Resources")
                icon: "monitoring"
            }

            GridLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                columns: 2
                rowSpacing: Math.round(Tokens.spacing.small * root.s)
                columnSpacing: Math.round(Tokens.spacing.small * root.s)

                Repeater {
                    model: root.activeMetricKeys

                    delegate: StyledRect {
                        id: sqMeter

                        required property string modelData

                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: Tokens.rounding.large
                        color: WidgetMetrics.innerSurface

                        ColumnLayout {
                            anchors.centerIn: parent
                            width: parent.width - Tokens.padding.small * 2
                            spacing: Math.round(4 * root.s)

                            GaugeBadge {
                                Layout.alignment: Qt.AlignHCenter
                                kind: sqMeter.modelData
                                gaugeSize: Math.round(62 * root.s)
                                activeLayout: root.sizeMode === "2x2"
                            }

                            StyledText {
                                Layout.fillWidth: true
                                horizontalAlignment: Text.AlignHCenter
                                text: root.metricLabel(sqMeter.modelData)
                                font: Tokens.font.label.builders.medium.weight(Font.Bold).build()
                                color: Colours.palette.m3onSurface
                                elide: Text.ElideRight
                            }

                            StyledText {
                                Layout.fillWidth: true
                                horizontalAlignment: Text.AlignHCenter
                                text: root.metricDetail(sqMeter.modelData)
                                font: Tokens.font.label.small
                                color: Colours.palette.m3onSurfaceVariant
                                elide: Text.ElideRight
                            }
                        }
                    }
                }
            }
        }

        // 1x3 Ultra-Wide Telemetry Bar
        RowLayout {
            anchors.fill: parent
            anchors.margins: shell.contentPadding
            visible: root.sizeMode === "1x3"
            spacing: Math.round(Tokens.spacing.small * root.s)

            Repeater {
                model: root.activeMetricKeys

                delegate: StyledRect {
                    id: wideStripCard

                    required property string modelData

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: Tokens.rounding.large
                    color: WidgetMetrics.innerSurface

                    ColumnLayout {
                        anchors.centerIn: parent
                        width: parent.width - Tokens.padding.small * 2
                        spacing: Math.round(3 * root.s)

                        GaugeBadge {
                            Layout.alignment: Qt.AlignHCenter
                            kind: wideStripCard.modelData
                            gaugeSize: Math.round(64 * root.s)
                            activeLayout: root.sizeMode === "1x3"
                        }

                        StyledText {
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                            text: root.metricLabel(wideStripCard.modelData)
                            font: Tokens.font.label.builders.small.weight(Font.Bold).build()
                            color: Colours.palette.m3onSurface
                            elide: Text.ElideRight
                        }

                        StyledText {
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                            text: root.metricDetail(wideStripCard.modelData)
                            font: Tokens.font.label.builders.small.scale(0.88).build()
                            color: Colours.palette.m3onSurfaceVariant
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }

        // 2x3 Full Workstation Telemetry Panorama
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: shell.contentPadding
            visible: root.sizeMode === "2x3"
            spacing: Math.round(Tokens.spacing.medium * root.s)

            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.small

                WidgetHeader {
                    Layout.fillWidth: true
                    title: (SysInfo.hostname || Tr.tr("System")) + " · " + (SysInfo.osName || "Linux")
                    icon: "monitoring"
                }

                StyledRect {
                    Layout.preferredHeight: Math.round(24 * root.s)
                    Layout.preferredWidth: Math.round(upBadgeText.implicitWidth + 16)
                    radius: Math.round(12 * root.s)
                    color: Colours.palette.m3primaryContainer

                    StyledText {
                        id: upBadgeText

                        anchors.centerIn: parent
                        text: Tr.tr("Up %1").arg(SysInfo.uptimeShort || "--")
                        font: Tokens.font.label.small
                        color: Colours.palette.m3onPrimaryContainer
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: Math.round(Tokens.spacing.small * root.s)

                Repeater {
                    model: root.activeMetricKeys

                    delegate: StyledRect {
                        id: panoTile

                        required property string modelData

                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: Tokens.rounding.extraLarge
                        color: WidgetMetrics.innerSurface

                        ColumnLayout {
                            anchors.centerIn: parent
                            width: parent.width - Tokens.padding.small * 2
                            spacing: Math.round(6 * root.s)

                            GaugeBadge {
                                Layout.alignment: Qt.AlignHCenter
                                kind: panoTile.modelData
                                gaugeSize: Math.round(88 * root.s)
                                activeLayout: root.sizeMode === "2x3"
                            }

                            StyledText {
                                Layout.fillWidth: true
                                horizontalAlignment: Text.AlignHCenter
                                text: root.metricLabel(panoTile.modelData)
                                font: Tokens.font.title.builders.small.scale(root.s).weight(Font.Bold).build()
                                color: Colours.palette.m3onSurface
                                elide: Text.ElideRight
                            }

                            StyledText {
                                Layout.fillWidth: true
                                horizontalAlignment: Text.AlignHCenter
                                text: root.metricDetail(panoTile.modelData)
                                font: Tokens.font.label.small
                                color: Colours.palette.m3onSurfaceVariant
                                elide: Text.ElideRight
                            }
                        }
                    }
                }
            }

            StyledRect {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.round(38 * root.s)
                radius: Tokens.rounding.large
                color: WidgetMetrics.innerSurface

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Tokens.padding.medium
                    anchors.rightMargin: Tokens.padding.medium
                    spacing: Tokens.spacing.medium

                    StyledText {
                        Layout.fillWidth: true
                        text: Cpu.name || Tr.tr("CPU")
                        font: Tokens.font.label.small
                        color: Colours.palette.m3onSurfaceVariant
                        elide: Text.ElideRight
                    }

                    StyledText {
                        text: Units.formatKibUsage(Memory.used, Memory.total)
                        font: Tokens.font.label.builders.small.weight(Font.DemiBold).build()
                        color: Colours.palette.m3onSurface
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

        implicitWidth: gaugeSize
        implicitHeight: gaugeSize

        // Expressive MaterialShape Fill Gauge
        Item {
            anchors.fill: parent
            visible: gRoot.isShapeMode && !GameMode.enabled

            MaterialShape {
                id: gMask

                anchors.fill: parent
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
                    color: WidgetMetrics.innerSurfaceStrong
                }

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: Math.max(4, Math.round(parent.height * gRoot.pct))
                    color: Qt.alpha(gRoot.col, 0.78)

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
                font: Tokens.font.clock.size(Math.max(11, Math.round(gRoot.gaugeSize * 0.24))).weight(Font.Bold).build()
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
                strokeWidth: Math.max(4, Math.round(gRoot.gaugeSize * 0.11))
                fgColour: gRoot.col
                bgColour: WidgetMetrics.trackSurface
                implicitSize: width
            }

            StyledText {
                anchors.centerIn: parent
                visible: gRoot.showPercent
                text: Math.round(gRoot.pct * 100) + "%"
                font: Tokens.font.clock.size(Math.max(11, Math.round(gRoot.gaugeSize * 0.24))).weight(Font.Bold).build()
                color: Colours.palette.m3onSurface
            }
        }
    }
}

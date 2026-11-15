pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components.controls
import qs.services
import qs.modules.nexus.common

PageBase {
    id: root

    readonly property var clockConfig: root.targetConfig.background.desktopClock
    readonly property string clockStyle: clockConfig.style || "classic"
    readonly property var clockOptions: clockConfig.options || ({})

    readonly property list<string> positionValues: ["top-left", "top-center", "top-right", "middle-left", "middle-center", "middle-right", "bottom-left", "bottom-center", "bottom-right"]
    readonly property list<MenuItem> positionItems: [
        MenuItem { text: qsTr("Top Left") },
        MenuItem { text: qsTr("Top Center") },
        MenuItem { text: qsTr("Top Right") },
        MenuItem { text: qsTr("Middle Left") },
        MenuItem { text: qsTr("Middle Center") },
        MenuItem { text: qsTr("Middle Right") },
        MenuItem { text: qsTr("Bottom Left") },
        MenuItem { text: qsTr("Bottom Center") },
        MenuItem { text: qsTr("Bottom Right") }
    ]

    readonly property list<string> clockStyleValues: ["classic", "cookie", "pixel", "stacked", "smooth"]
    readonly property list<MenuItem> clockStyleItems: [
        MenuItem { text: qsTr("Classic") },
        MenuItem { text: qsTr("Cookie") },
        MenuItem { text: qsTr("Pixel") },
        MenuItem { text: qsTr("Stacked") },
        MenuItem { text: qsTr("Smooth") }
    ]

    readonly property list<string> surfaceStyleValues: ["glass", "blur", "frosted", "material"]
    readonly property list<MenuItem> surfaceStyleItems: [
        MenuItem { text: qsTr("Glass") },
        MenuItem { text: qsTr("Blur") },
        MenuItem { text: qsTr("Frosted") },
        MenuItem { text: qsTr("Material") }
    ]

    readonly property list<string> cookieShapeValues: ["Cookie9Sided", "Cookie7Sided", "Cookie6Sided", "Cookie4Sided", "Cookie12Sided", "Circle", "Square", "Clover4Leaf", "Clover8Leaf", "SoftBurst", "Sunny", "Flower", "Heart", "Gem", "Puffy", "Ghostish"]
    readonly property list<MenuItem> cookieShapeItems: [
        MenuItem { text: qsTr("Cookie (9-sided)") },
        MenuItem { text: qsTr("Cookie (7-sided)") },
        MenuItem { text: qsTr("Cookie (6-sided)") },
        MenuItem { text: qsTr("Cookie (4-sided)") },
        MenuItem { text: qsTr("Cookie (12-sided)") },
        MenuItem { text: qsTr("Circle") },
        MenuItem { text: qsTr("Square") },
        MenuItem { text: qsTr("Clover (4-leaf)") },
        MenuItem { text: qsTr("Clover (8-leaf)") },
        MenuItem { text: qsTr("Soft burst") },
        MenuItem { text: qsTr("Sunny") },
        MenuItem { text: qsTr("Flower") },
        MenuItem { text: qsTr("Heart") },
        MenuItem { text: qsTr("Gem") },
        MenuItem { text: qsTr("Puffy") },
        MenuItem { text: qsTr("Ghostish") }
    ]

    readonly property list<string> hourHandValues: ["classic", "fill", "hollow", "hide"]
    readonly property list<MenuItem> hourHandItems: [
        MenuItem { text: qsTr("Classic") },
        MenuItem { text: qsTr("Fill") },
        MenuItem { text: qsTr("Hollow") },
        MenuItem { text: qsTr("Hidden") }
    ]

    readonly property list<string> minuteHandValues: ["classic", "thin", "medium", "bold", "hide"]
    readonly property list<MenuItem> minuteHandItems: [
        MenuItem { text: qsTr("Classic") },
        MenuItem { text: qsTr("Thin") },
        MenuItem { text: qsTr("Medium") },
        MenuItem { text: qsTr("Bold") },
        MenuItem { text: qsTr("Hidden") }
    ]

    readonly property list<string> secondHandValues: ["line", "dot", "both", "hide"]
    readonly property list<MenuItem> secondHandItems: [
        MenuItem { text: qsTr("Line") },
        MenuItem { text: qsTr("Dot") },
        MenuItem { text: qsTr("Line + Dot") },
        MenuItem { text: qsTr("Hidden") }
    ]

    readonly property list<string> dialNumberValues: ["full", "dots", "numbers", "none"]
    readonly property list<MenuItem> dialNumberItems: [
        MenuItem { text: qsTr("Full ticks") },
        MenuItem { text: qsTr("Dots") },
        MenuItem { text: qsTr("Numbers") },
        MenuItem { text: qsTr("None") }
    ]

    readonly property list<string> dateStyleValues: ["bubble", "rect", "border", "hide"]
    readonly property list<MenuItem> dateStyleItems: [
        MenuItem { text: qsTr("Bubble") },
        MenuItem { text: qsTr("Filled pill") },
        MenuItem { text: qsTr("Outlined pill") },
        MenuItem { text: qsTr("Hidden") }
    ]

    readonly property list<string> pixelOrientationValues: ["vertical", "horizontal"]
    readonly property list<MenuItem> pixelOrientationItems: [
        MenuItem { text: qsTr("Vertical") },
        MenuItem { text: qsTr("Horizontal") }
    ]

    readonly property list<string> pixelFontValues: ["gsans", "titan"]
    readonly property list<MenuItem> pixelFontItems: [
        MenuItem { text: qsTr("Google Sans") },
        MenuItem { text: qsTr("Titan One") }
    ]

    readonly property list<string> colorRoleValues: ["primary", "secondary", "tertiary", "onSurface", "inverseSurface", "surface", "primaryContainer", "secondaryContainer", "tertiaryContainer"]
    readonly property list<MenuItem> boldColorItems: [
        MenuItem { text: qsTr("Primary") },
        MenuItem { text: qsTr("Secondary") },
        MenuItem { text: qsTr("Tertiary") },
        MenuItem { text: qsTr("On Surface") },
        MenuItem { text: qsTr("Inverse Surface") },
        MenuItem { text: qsTr("Surface") },
        MenuItem { text: qsTr("Primary Container") },
        MenuItem { text: qsTr("Secondary Container") },
        MenuItem { text: qsTr("Tertiary Container") }
    ]
    readonly property list<MenuItem> softColorItems: [
        MenuItem { text: qsTr("Primary") },
        MenuItem { text: qsTr("Secondary") },
        MenuItem { text: qsTr("Tertiary") },
        MenuItem { text: qsTr("On Surface") },
        MenuItem { text: qsTr("Inverse Surface") },
        MenuItem { text: qsTr("Surface") },
        MenuItem { text: qsTr("Primary Container") },
        MenuItem { text: qsTr("Secondary Container") },
        MenuItem { text: qsTr("Tertiary Container") }
    ]

    readonly property list<string> stackedAlignValues: ["left", "center", "right"]
    readonly property list<MenuItem> stackedAlignItems: [
        MenuItem { text: qsTr("Left") },
        MenuItem { text: qsTr("Center") },
        MenuItem { text: qsTr("Right") }
    ]

    readonly property list<string> weightValues: ["light", "regular", "medium", "bold"]
    readonly property list<MenuItem> timeWeightItems: [
        MenuItem { text: qsTr("Light") },
        MenuItem { text: qsTr("Regular") },
        MenuItem { text: qsTr("Medium") },
        MenuItem { text: qsTr("Bold") }
    ]
    readonly property list<MenuItem> labelWeightItems: [
        MenuItem { text: qsTr("Light") },
        MenuItem { text: qsTr("Regular") },
        MenuItem { text: qsTr("Medium") },
        MenuItem { text: qsTr("Bold") }
    ]
    readonly property list<MenuItem> timeColorItems: [
        MenuItem { text: qsTr("Primary") },
        MenuItem { text: qsTr("Secondary") },
        MenuItem { text: qsTr("Tertiary") },
        MenuItem { text: qsTr("On Surface") },
        MenuItem { text: qsTr("Inverse Surface") },
        MenuItem { text: qsTr("Surface") },
        MenuItem { text: qsTr("Primary Container") },
        MenuItem { text: qsTr("Secondary Container") },
        MenuItem { text: qsTr("Tertiary Container") }
    ]
    readonly property list<MenuItem> labelColorItems: [
        MenuItem { text: qsTr("Primary") },
        MenuItem { text: qsTr("Secondary") },
        MenuItem { text: qsTr("Tertiary") },
        MenuItem { text: qsTr("On Surface") },
        MenuItem { text: qsTr("Inverse Surface") },
        MenuItem { text: qsTr("Surface") },
        MenuItem { text: qsTr("Primary Container") },
        MenuItem { text: qsTr("Secondary Container") },
        MenuItem { text: qsTr("Tertiary Container") }
    ]

    function setClockOption(key: string, value: var): void {
        const next = Object.assign({}, root.clockOptions);
        next[key] = value;
        root.clockConfig.options = next;
        root.targetConfig.save();
    }

    function indexOrDefault(values: list<string>, value: string, fallbackIdx: int): int {
        const idx = values.indexOf(value);
        return idx >= 0 ? idx : fallbackIdx;
    }

    title: qsTr("Desktop clock")
    isSubPage: true

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        SectionHeader {
            first: true
            text: qsTr("General")
        }

        ToggleRow {
            first: true
            Layout.fillWidth: true
            text: qsTr("Enable desktop clock")
            configNode: root.clockConfig
            propertyName: "enabled"
            checked: root.clockConfig.enabled
            onToggled: {
                root.clockConfig.enabled = checked;
                root.targetConfig.save();
            }
        }

        ToggleRow {
            Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
            last: true
            Layout.fillWidth: true
            text: qsTr("Edit on desktop")
            subtext: qsTr("Unlock desktop clock and widgets for dragging")
            checked: Visibilities.desktopWidgetsUnlocked
            onToggled: Visibilities.desktopWidgetsUnlocked = checked
        }

        TextButton {
            Layout.alignment: Qt.AlignRight
            Layout.topMargin: Tokens.spacing.extraSmall
            text: qsTr("Reset desktop position")
            type: TextButton.Tonal
            disabled: root.clockConfig.x < 0 && root.clockConfig.y < 0
            onClicked: {
                root.clockConfig.x = -1;
                root.clockConfig.y = -1;
                root.targetConfig.save();
            }
        }

        SectionHeader {
            text: qsTr("Appearance")
        }

        SelectRow {
            first: true
            Layout.fillWidth: true
            label: qsTr("Clock style")
            configNode: root.clockConfig
            propertyName: "style"
            menuItems: root.clockStyleItems
            active: root.clockStyleItems[root.indexOrDefault(root.clockStyleValues, root.clockStyle, 0)]
            onSelected: item => {
                const idx = root.clockStyleItems.indexOf(item);
                if (idx !== -1) {
                    root.clockConfig.style = root.clockStyleValues[idx];
                    root.targetConfig.save();
                }
            }
        }

        SelectRow {
            Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
            Layout.fillWidth: true
            label: qsTr("Surface style")
            configNode: root.clockConfig
            propertyName: "surfaceStyle"
            menuItems: root.surfaceStyleItems
            active: root.surfaceStyleItems[root.indexOrDefault(root.surfaceStyleValues, root.clockConfig.surfaceStyle, 0)]
            onSelected: item => {
                const idx = root.surfaceStyleItems.indexOf(item);
                if (idx !== -1) {
                    root.clockConfig.surfaceStyle = root.surfaceStyleValues[idx];
                    root.targetConfig.save();
                }
            }
        }

        SelectRow {
            Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
            Layout.fillWidth: true
            label: qsTr("Position")
            configNode: root.clockConfig
            propertyName: "position"
            menuItems: root.positionItems
            active: root.positionItems[root.indexOrDefault(root.positionValues, root.clockConfig.position, 4)]
            onSelected: item => {
                const idx = root.positionItems.indexOf(item);
                if (idx !== -1) {
                    root.clockConfig.position = root.positionValues[idx];
                    root.targetConfig.save();
                }
            }
        }

        SliderRow {
            Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
            last: root.clockStyle !== "classic"
            Layout.fillWidth: true
            label: qsTr("Scale")
            configNode: root.clockConfig
            propertyName: "scale"
            value: (root.clockConfig.scale - 0.5) / 2.5
            valueLabel: (0.5 + value * 2.5).toFixed(1) + "x"
            onMoved: v => {
                root.clockConfig.scale = 0.5 + v * 2.5;
                root.targetConfig.save();
            }
        }

        ToggleRow {
            Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
            visible: root.clockStyle === "classic"
            last: true
            Layout.fillWidth: true
            text: qsTr("Invert colors")
            subtext: qsTr("Invert the clock color when using light wallpaper")
            configNode: root.clockConfig
            propertyName: "invertColors"
            checked: root.clockConfig.invertColors
            onToggled: {
                root.clockConfig.invertColors = checked;
                root.targetConfig.save();
            }
        }

        SectionHeader {
            visible: root.clockStyle !== "classic"
            text: qsTr("Style options")
        }

        // Cookie clock options
        ColumnLayout {
            visible: root.clockStyle === "cookie"
            Layout.fillWidth: true
            spacing: Tokens.spacing.extraSmall / 2

            SelectRow {
                first: true
                Layout.fillWidth: true
                label: qsTr("Shape")
                menuItems: root.cookieShapeItems
                active: root.cookieShapeItems[root.indexOrDefault(root.cookieShapeValues, String(root.clockOptions.shape ?? "Cookie9Sided"), 0)]
                onSelected: item => {
                    const idx = root.cookieShapeItems.indexOf(item);
                    if (idx !== -1)
                        root.setClockOption("shape", root.cookieShapeValues[idx]);
                }
            }

            ToggleRow {
                Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
                Layout.fillWidth: true
                text: qsTr("Constantly rotate")
                checked: Boolean(root.clockOptions.constantlyRotate ?? false)
                onToggled: root.setClockOption("constantlyRotate", checked)
            }

            ToggleRow {
                Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
                Layout.fillWidth: true
                text: qsTr("Time indicators")
                checked: Boolean(root.clockOptions.timeIndicators ?? true)
                onToggled: root.setClockOption("timeIndicators", checked)
            }

            SelectRow {
                Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
                Layout.fillWidth: true
                label: qsTr("Hour hand")
                menuItems: root.hourHandItems
                active: root.hourHandItems[root.indexOrDefault(root.hourHandValues, String(root.clockOptions.hourHandStyle ?? "classic"), 0)]
                onSelected: item => {
                    const idx = root.hourHandItems.indexOf(item);
                    if (idx !== -1)
                        root.setClockOption("hourHandStyle", root.hourHandValues[idx]);
                }
            }

            SelectRow {
                Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
                Layout.fillWidth: true
                label: qsTr("Minute hand")
                menuItems: root.minuteHandItems
                active: root.minuteHandItems[root.indexOrDefault(root.minuteHandValues, String(root.clockOptions.minuteHandStyle ?? "classic"), 0)]
                onSelected: item => {
                    const idx = root.minuteHandItems.indexOf(item);
                    if (idx !== -1)
                        root.setClockOption("minuteHandStyle", root.minuteHandValues[idx]);
                }
            }

            SelectRow {
                Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
                Layout.fillWidth: true
                label: qsTr("Second hand")
                menuItems: root.secondHandItems
                active: root.secondHandItems[root.indexOrDefault(root.secondHandValues, String(root.clockOptions.secondHandStyle ?? "line"), 0)]
                onSelected: item => {
                    const idx = root.secondHandItems.indexOf(item);
                    if (idx !== -1)
                        root.setClockOption("secondHandStyle", root.secondHandValues[idx]);
                }
            }

            SelectRow {
                Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
                Layout.fillWidth: true
                label: qsTr("Dial markings")
                menuItems: root.dialNumberItems
                active: root.dialNumberItems[root.indexOrDefault(root.dialNumberValues, String(root.clockOptions.dialNumberStyle ?? "full"), 0)]
                onSelected: item => {
                    const idx = root.dialNumberItems.indexOf(item);
                    if (idx !== -1)
                        root.setClockOption("dialNumberStyle", root.dialNumberValues[idx]);
                }
            }

            SelectRow {
                Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
                last: true
                Layout.fillWidth: true
                label: qsTr("Date badge")
                menuItems: root.dateStyleItems
                active: root.dateStyleItems[root.indexOrDefault(root.dateStyleValues, String(root.clockOptions.dateStyle ?? "bubble"), 0)]
                onSelected: item => {
                    const idx = root.dateStyleItems.indexOf(item);
                    if (idx !== -1)
                        root.setClockOption("dateStyle", root.dateStyleValues[idx]);
                }
            }
        }

        // Pixel clock options
        ColumnLayout {
            visible: root.clockStyle === "pixel"
            Layout.fillWidth: true
            spacing: Tokens.spacing.extraSmall / 2

            SelectRow {
                first: true
                Layout.fillWidth: true
                label: qsTr("Orientation")
                menuItems: root.pixelOrientationItems
                active: root.pixelOrientationItems[root.indexOrDefault(root.pixelOrientationValues, String(root.clockOptions.orientation ?? "vertical"), 0)]
                onSelected: item => {
                    const idx = root.pixelOrientationItems.indexOf(item);
                    if (idx !== -1)
                        root.setClockOption("orientation", root.pixelOrientationValues[idx]);
                }
            }

            SelectRow {
                Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
                Layout.fillWidth: true
                label: qsTr("Font")
                menuItems: root.pixelFontItems
                active: root.pixelFontItems[root.indexOrDefault(root.pixelFontValues, String(root.clockOptions.font ?? "gsans"), 0)]
                onSelected: item => {
                    const idx = root.pixelFontItems.indexOf(item);
                    if (idx !== -1)
                        root.setClockOption("font", root.pixelFontValues[idx]);
                }
            }

            SelectRow {
                Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
                Layout.fillWidth: true
                label: qsTr("Bold digit color")
                menuItems: root.boldColorItems
                active: root.boldColorItems[root.indexOrDefault(root.colorRoleValues, String(root.clockOptions.boldColor ?? "inverseSurface"), 4)]
                onSelected: item => {
                    const idx = root.boldColorItems.indexOf(item);
                    if (idx !== -1)
                        root.setClockOption("boldColor", root.colorRoleValues[idx]);
                }
            }

            SelectRow {
                Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
                Layout.fillWidth: true
                label: qsTr("Soft digit color")
                menuItems: root.softColorItems
                active: root.softColorItems[root.indexOrDefault(root.colorRoleValues, String(root.clockOptions.softColor ?? "primary"), 0)]
                onSelected: item => {
                    const idx = root.softColorItems.indexOf(item);
                    if (idx !== -1)
                        root.setClockOption("softColor", root.colorRoleValues[idx]);
                }
            }

            ToggleRow {
                Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
                last: true
                Layout.fillWidth: true
                text: qsTr("Card background")
                checked: Boolean(root.clockOptions.showBackground ?? false)
                onToggled: root.setClockOption("showBackground", checked)
            }
        }

        // Stacked clock options
        ColumnLayout {
            visible: root.clockStyle === "stacked"
            Layout.fillWidth: true
            spacing: Tokens.spacing.extraSmall / 2

            SelectRow {
                first: true
                Layout.fillWidth: true
                label: qsTr("Alignment")
                menuItems: root.stackedAlignItems
                active: root.stackedAlignItems[root.indexOrDefault(root.stackedAlignValues, String(root.clockOptions.alignment ?? "left"), 0)]
                onSelected: item => {
                    const idx = root.stackedAlignItems.indexOf(item);
                    if (idx !== -1)
                        root.setClockOption("alignment", root.stackedAlignValues[idx]);
                }
            }

            SelectRow {
                Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
                Layout.fillWidth: true
                label: qsTr("Time weight")
                menuItems: root.timeWeightItems
                active: root.timeWeightItems[root.indexOrDefault(root.weightValues, String(root.clockOptions.weight ?? root.clockOptions.fontWeight ?? "medium"), 2)]
                onSelected: item => {
                    const idx = root.timeWeightItems.indexOf(item);
                    if (idx !== -1)
                        root.setClockOption("weight", root.weightValues[idx]);
                }
            }

            SelectRow {
                Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
                Layout.fillWidth: true
                label: qsTr("Label weight")
                menuItems: root.labelWeightItems
                active: root.labelWeightItems[root.indexOrDefault(root.weightValues, String(root.clockOptions.labelFontWeight ?? "light"), 0)]
                onSelected: item => {
                    const idx = root.labelWeightItems.indexOf(item);
                    if (idx !== -1)
                        root.setClockOption("labelFontWeight", root.weightValues[idx]);
                }
            }

            SelectRow {
                Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
                Layout.fillWidth: true
                label: qsTr("Time color")
                menuItems: root.timeColorItems
                active: root.timeColorItems[root.indexOrDefault(root.colorRoleValues, String(root.clockOptions.timeColor ?? "primary"), 0)]
                onSelected: item => {
                    const idx = root.timeColorItems.indexOf(item);
                    if (idx !== -1)
                        root.setClockOption("timeColor", root.colorRoleValues[idx]);
                }
            }

            SelectRow {
                Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
                Layout.fillWidth: true
                label: qsTr("Date color")
                menuItems: root.labelColorItems
                active: root.labelColorItems[root.indexOrDefault(root.colorRoleValues, String(root.clockOptions.labelColor ?? "onSurface"), 3)]
                onSelected: item => {
                    const idx = root.labelColorItems.indexOf(item);
                    if (idx !== -1)
                        root.setClockOption("labelColor", root.colorRoleValues[idx]);
                }
            }

            StepperRow {
                Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
                Layout.fillWidth: true
                label: qsTr("Time font size")
                value: Math.round(Number(root.clockOptions.fontSize ?? 84))
                from: 36
                to: 160
                stepSize: 4
                onMoved: v => root.setClockOption("fontSize", Math.round(v))
            }

            StepperRow {
                Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
                Layout.fillWidth: true
                label: qsTr("Date font size")
                value: Math.round(Number(root.clockOptions.labelFontSize ?? 42))
                from: 16
                to: 96
                stepSize: 2
                onMoved: v => root.setClockOption("labelFontSize", Math.round(v))
            }

            ToggleRow {
                Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
                Layout.fillWidth: true
                text: qsTr("Show date")
                checked: Boolean(root.clockOptions.showDate ?? true)
                onToggled: root.setClockOption("showDate", checked)
            }

            ToggleRow {
                Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
                last: true
                Layout.fillWidth: true
                text: qsTr("Card background")
                checked: Boolean(root.clockOptions.showBackground ?? false)
                onToggled: root.setClockOption("showBackground", checked)
            }
        }

        // Smooth clock options
        ColumnLayout {
            visible: root.clockStyle === "smooth"
            Layout.fillWidth: true
            spacing: Tokens.spacing.extraSmall / 2

            ToggleRow {
                first: true
                Layout.fillWidth: true
                text: qsTr("Show date and weather")
                checked: Boolean(root.clockOptions.showDateAndWeather ?? true)
                onToggled: root.setClockOption("showDateAndWeather", checked)
            }

            ToggleRow {
                Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
                last: true
                Layout.fillWidth: true
                text: qsTr("Card background")
                checked: Boolean(root.clockOptions.showBackground ?? false)
                onToggled: root.setClockOption("showBackground", checked)
            }
        }

        SectionHeader {
            text: qsTr("Background")
        }

        ToggleRow {
            first: true
            Layout.fillWidth: true
            text: qsTr("Enable background")
            configNode: root.clockConfig.background
            propertyName: "enabled"
            checked: root.clockConfig.background.enabled
            onToggled: {
                root.clockConfig.background.enabled = checked;
                root.targetConfig.save();
            }
        }

        SliderRow {
            Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
            Layout.fillWidth: true
            label: qsTr("Opacity")
            configNode: root.clockConfig.background
            propertyName: "opacity"
            value: root.clockConfig.background.opacity
            valueLabel: Math.round(value * 100) + "%"
            enabled: root.clockConfig.background.enabled || root.clockStyle !== "classic"
            onMoved: v => {
                root.clockConfig.background.opacity = v;
                root.targetConfig.save();
            }
        }

        ToggleRow {
            Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
            last: true
            Layout.fillWidth: true
            text: qsTr("Blur")
            configNode: root.clockConfig.background
            propertyName: "blur"
            checked: root.clockConfig.background.blur
            enabled: root.clockConfig.background.enabled || root.clockStyle !== "classic"
            onToggled: {
                root.clockConfig.background.blur = checked;
                root.targetConfig.save();
            }
        }

        SectionHeader {
            text: qsTr("Shadow")
        }

        ToggleRow {
            first: true
            Layout.fillWidth: true
            text: qsTr("Enable shadow")
            configNode: root.clockConfig.shadow
            propertyName: "enabled"
            checked: root.clockConfig.shadow.enabled
            onToggled: {
                root.clockConfig.shadow.enabled = checked;
                root.targetConfig.save();
            }
        }

        SliderRow {
            Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
            Layout.fillWidth: true
            label: qsTr("Opacity")
            configNode: root.clockConfig.shadow
            propertyName: "opacity"
            value: root.clockConfig.shadow.opacity
            valueLabel: Math.round(value * 100) + "%"
            enabled: root.clockConfig.shadow.enabled
            onMoved: v => {
                root.clockConfig.shadow.opacity = v;
                root.targetConfig.save();
            }
        }

        SliderRow {
            Layout.topMargin: Tokens.spacing.extraSmall / 2 - parent.spacing
            last: true
            Layout.fillWidth: true
            label: qsTr("Blur strength")
            configNode: root.clockConfig.shadow
            propertyName: "blur"
            value: root.clockConfig.shadow.blur / 2.0
            valueLabel: (value * 2.0).toFixed(1)
            enabled: root.clockConfig.shadow.enabled
            onMoved: v => {
                root.clockConfig.shadow.blur = v * 2.0;
                root.targetConfig.save();
            }
        }
    }
}

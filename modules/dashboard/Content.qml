pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.filedialog
import "../../services"

Item {
    id: root

    required property ScreenState screenState
    required property FileDialog facePicker

    readonly property var tabDefs: ({
        dashboard: {
            id: "dashboard",
            component: dashComponent,
            iconName: "dashboard",
            text: Tr.tr("Dashboard")
        },
        media: {
            id: "media",
            component: mediaComponent,
            iconName: "queue_music",
            text: Tr.tr("Media")
        },
        weather: {
            id: "weather",
            component: weatherComponent,
            iconName: "cloud",
            text: Tr.tr("Weather")
        },
        performance: {
            id: "performance",
            component: performanceComponent,
            iconName: "speed",
            text: Tr.tr("Performance")
        },
        hardware: {
            id: "hardware",
            component: hardwareComponent,
            iconName: "tune",
            text: Tr.tr("Hardware"),
            available: Hardware.isSupported
        },
        terminal: {
            id: "terminal",
            component: terminalComponent,
            iconName: "terminal",
            text: qsTr("Terminal")
        },
        focus: {
            id: "focus",
            component: focusComponent,
            iconName: "timer",
            text: Tr.tr("Focus")
        },
        notes: {
            id: "notes",
            component: notesComponent,
            iconName: "edit_note",
            text: Tr.tr("Notes")
        }
    })

    readonly property var dashboardTabs: {
        const tabsConfig = Config.dashboard.tabs;
        if (tabsConfig && tabsConfig.values && tabsConfig.values.length > 0) {
            const seenIds = new Set();
            const list = [];
            for (const entry of tabsConfig.values) {
                if (!entry.enabled || seenIds.has(entry.id))
                    continue;
                seenIds.add(entry.id);
                const def = tabDefs[entry.id];
                if (def && (def.available === undefined || def.available)) {
                    list.push(def);
                }
            }
            return list;
        }

        const defaultOrder = ["dashboard", "media", "weather", "performance", "hardware", "terminal", "focus", "notes"];
        return defaultOrder
            .map(id => tabDefs[id])
            .filter(def => def && (def.available === undefined || def.available));
    }

    readonly property real nonAnimWidth: view.implicitWidth + viewWrapper.anchors.margins * 2
    readonly property real nonAnimHeight: tabs.implicitHeight + tabs.anchors.topMargin + view.implicitHeight + viewWrapper.anchors.margins * 2

    implicitWidth: nonAnimWidth
    implicitHeight: nonAnimHeight

    Tabs {
        id: tabs

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: CUtils.clamp(anchors.margins - Config.border.thickness, 0, anchors.margins)
        anchors.margins: Tokens.padding.large

        nonAnimWidth: root.nonAnimWidth - anchors.margins * 2
        screenState: root.screenState
        tabs: root.dashboardTabs
    }

    ClipRect {
        id: viewWrapper

        anchors.top: tabs.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: Tokens.padding.large

        radius: Tokens.rounding.large
        color: "transparent"

        Flickable {
            id: view

            readonly property int currentIndex: root.screenState.dashboardTab
            readonly property Item currentItem: {
                CUtils.dependency(repeater.count); // Trigger update on count change
                return repeater.itemAt(currentIndex);
            }

            anchors.fill: parent

            flickableDirection: Flickable.HorizontalFlick

            property real lastValidImplicitWidth: 0
            implicitWidth: currentItem ? currentItem.implicitWidth : lastValidImplicitWidth
            onImplicitWidthChanged: {
                if (currentItem) lastValidImplicitWidth = currentItem.implicitWidth;
            }

            property real lastValidImplicitHeight: 0
            implicitHeight: currentItem ? currentItem.implicitHeight : lastValidImplicitHeight
            onImplicitHeightChanged: {
                if (currentItem) lastValidImplicitHeight = currentItem.implicitHeight;
            }

            property real lastValidContentX: 0
            contentX: currentItem ? currentItem.x : lastValidContentX
            contentWidth: row.implicitWidth
            contentHeight: row.implicitHeight

            onContentXChanged: {
                if (currentItem && !moving) {
                    lastValidContentX = contentX;
                }

                if (!moving || !currentItem)
                    return;

                const x = contentX - currentItem.x;
                if (x > currentItem.implicitWidth / 2)
                    root.screenState.dashboardTab = Math.min(root.screenState.dashboardTab + 1, tabs.count - 1);
                else if (x < -currentItem.implicitWidth / 2)
                    root.screenState.dashboardTab = Math.max(root.screenState.dashboardTab - 1, 0);
            }

            onDragEnded: {
                if (!currentItem)
                    return;

                const x = contentX - currentItem.x;
                if (x > currentItem.implicitWidth / 10)
                    root.screenState.dashboardTab = Math.min(root.screenState.dashboardTab + 1, tabs.count - 1);
                else if (x < -currentItem.implicitWidth / 10)
                    root.screenState.dashboardTab = Math.max(root.screenState.dashboardTab - 1, 0);
                else
                    contentX = Qt.binding(() => currentItem?.x ?? 0);
            }

            RowLayout {
                id: row

                Repeater {
                    id: repeater

                    model: ScriptModel {
                        values: root.dashboardTabs
                    }

                    delegate: Loader {
                        id: paneLoader

                        required property int index
                        required property var modelData

                        Layout.alignment: Qt.AlignTop

                        sourceComponent: modelData.component

                        property bool wasActive: false
                        onActiveChanged: if (active) wasActive = true

                        Component.onCompleted: active = Qt.binding(() => {
                            if (wasActive || index === view.currentIndex)
                                return true;
                            const vx = Math.floor(view.visibleArea.xPosition * view.contentWidth);
                            const vex = Math.floor(vx + view.visibleArea.widthRatio * view.contentWidth);
                            return (vx >= x && vx <= x + implicitWidth) || (vex >= x && vex <= x + implicitWidth);
                        })
                    }
                }
            }

            Component {
                id: dashComponent

                Dash {
                    screenState: root.screenState
                    facePicker: root.facePicker
                }
            }

            Component {
                id: mediaComponent

                Media {
                    screenState: root.screenState
                }
            }

            // >>> caelestia-notes: managed block - do not edit; `install.sh --uninstall` removes it >>>
            Component {
                id: notesComponent

                // A wrapper Item + URL Loader (not a direct "NotesTab {}") so that a missing or broken
                // Notes file can never stop this file - and therefore the whole dashboard - from loading.
                Item {
                    implicitWidth: notesLoader.item ? notesLoader.item.implicitWidth : 840
                    implicitHeight: notesLoader.item ? notesLoader.item.implicitHeight : 480

                    Loader {
                        id: notesLoader

                        anchors.fill: parent
                        source: Qt.resolvedUrl("NotesTab.qml")
                    }

                    StyledText {
                        anchors.centerIn: parent
                        visible: notesLoader.status === Loader.Error
                        text: Tr.tr("Notes failed to load. Re-run the Caelestia Notes installer.")
                    }
                }
            }
            // <<< caelestia-notes <<<

            Component {
                id: performanceComponent

                Performance {}
            }

            Component {
                id: weatherComponent

                WeatherTab {}
            }

            Component {
                id: hardwareComponent

                HardwareTab {}
            }

            Component {
                id: terminalComponent

                TerminalTab {}
            }

            Component {
                id: focusComponent

                FocusTab {}
            }

            Behavior on contentX {
                Anim {}
            }
        }
    }

    Behavior on implicitWidth {
        Anim {}
    }

    Behavior on implicitHeight {
        Anim {}
    }
}

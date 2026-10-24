pragma ComponentBehavior: Bound

import QtQuick
import Caelestia
import Caelestia.Config
import qs.components
import qs.services

Item {
    id: root

    required property ScreenState screenState
    property var popouts
    property var utilities
    readonly property Props props: Props {}

    readonly property bool shouldBeActive: screenState.sidebar && Config.sidebar.enabled
    property real offsetScale: shouldBeActive ? 0 : 1

    readonly property bool isAiTab: root.visible
        ? (content.item ? content.item.activeTab === "ai" : Visibilities.initialSidebarTab === "ai")
        : Visibilities.initialSidebarTab === "ai"

    visible: offsetScale < 0.999
    property real slideAmount: (-implicitWidth - Config.border.thickness - Tokens.spacing.medium) * offsetScale
    anchors.leftMargin: slideAmount
    anchors.rightMargin: slideAmount
    implicitWidth: isAiTab
        ? Math.round(Tokens.sizes.sidebar.width * 1.18)
        : Tokens.sizes.sidebar.width
    opacity: 1 - offsetScale

    Behavior on implicitWidth {
        Anim { type: Anim.DefaultSpatial }
    }

    Behavior on offsetScale {
        Anim {}
    }

    property bool isStreaming: AiEngine.isStreaming

    Loader {
        id: content

        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.leftMargin: Tokens.padding.large
        anchors.margins: CUtils.clamp(anchors.leftMargin - Config.border.thickness, 0, anchors.leftMargin)
        anchors.bottomMargin: 0

        active: root.shouldBeActive || root.visible || root.isStreaming

        sourceComponent: Content {
            implicitWidth: root.implicitWidth - content.anchors.leftMargin - content.anchors.margins
            props: root.props
            screenState: root.screenState
            popouts: root.popouts
            utilities: root.utilities
            onSidebarStreamingChanged: root.isStreaming = sidebarStreaming
        }
    }
}

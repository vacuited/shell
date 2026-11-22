pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.containers
import qs.components.controls
import qs.services
import qs.modules.nexus.common

PageBase {
    id: root

    readonly property list<MenuItem> intervalItems: [
        MenuItem {
            text: qsTr("Every 1 hour")
            value: 1
        },
        MenuItem {
            text: qsTr("Every 6 hours")
            value: 6
        },
        MenuItem {
            text: qsTr("Every 12 hours")
            value: 12
        },
        MenuItem {
            text: qsTr("Every 24 hours")
            value: 24
        }
    ]

    property bool showLogs: false
    property string confirmingBackup: ""

    function formatRelativeTime(isoStr: string): string {
        if (!isoStr)
            return qsTr("Never checked");
        const ms = Date.parse(isoStr);
        if (isNaN(ms))
            return isoStr;
        const diffSec = Math.max(0, Math.floor((Date.now() - ms) / 1000));
        if (diffSec < 60)
            return qsTr("Just now");
        const mins = Math.floor(diffSec / 60);
        if (mins < 60)
            return qsTr("%1m ago").arg(mins);
        const hrs = Math.floor(mins / 60);
        if (hrs < 24)
            return qsTr("%1h ago").arg(hrs);
        const days = Math.floor(hrs / 24);
        return qsTr("%1d ago").arg(days);
    }

    function formatShortDate(isoStr: string): string {
        if (!isoStr)
            return "";
        const d = new Date(isoStr);
        if (isNaN(d.getTime()))
            return "";
        return Qt.formatDate(d, "MMM d");
    }

    title: Tr.tr("Updates")

    ColumnLayout {
        id: mainCol

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        Timer {
            id: confirmResetTimer
            interval: 4000
            repeat: false
            onTriggered: root.confirmingBackup = ""
        }

        // Hero status card
        ConnectedRect {
            id: heroCard
            Layout.fillWidth: true
            first: true
            last: true
            implicitHeight: heroCol.implicitHeight + Tokens.padding.extraLarge * 2

            ColumnLayout {
                id: heroCol

                anchors.centerIn: parent
                width: parent.width - Tokens.padding.extraLarge * 2
                spacing: Tokens.spacing.medium

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.large

                    StyledRect {
                        Layout.preferredWidth: 48
                        Layout.preferredHeight: 48
                        Layout.fillWidth: false
                        radius: Tokens.rounding.full
                        color: Updates.lastError !== ""
                            ? Colours.palette.m3errorContainer
                            : Updates.hasAnyUpdate
                                ? Colours.palette.m3primaryContainer
                                : Colours.palette.m3secondaryContainer

                        MaterialIcon {
                            anchors.centerIn: parent
                            fill: 1
                            fontStyle: Tokens.font.icon.large
                            text: Updates.updating
                                ? "sync"
                                : Updates.checking
                                    ? "manage_search"
                                    : Updates.lastError !== ""
                                        ? "error"
                                        : Updates.hasAnyUpdate
                                            ? "system_update"
                                            : Updates.baselineMissing
                                                ? "sync_problem"
                                                : "check_circle"
                            color: Updates.lastError !== ""
                                ? Colours.palette.m3onErrorContainer
                                : Updates.hasAnyUpdate
                                    ? Colours.palette.m3onPrimaryContainer
                                    : Colours.palette.m3onSecondaryContainer
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Tokens.spacing.extraSmall / 2

                        StyledText {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            elide: Text.ElideRight
                            font: Tokens.font.title.medium
                            text: {
                                if (Updates.updating)
                                    return Updates.phase || qsTr("Updating Vacuited...");
                                if (Updates.checking)
                                    return qsTr("Checking for updates...");
                                if (Updates.lastError !== "")
                                    return qsTr("Update issue");
                                if (Updates.hasAnyUpdate)
                                    return qsTr("%1 commit%2 available").arg(Updates.totalUpdateCommits).arg(Updates.totalUpdateCommits === 1 ? "" : "s");
                                if (Updates.baselineMissing)
                                    return qsTr("Baseline not recorded");
                                return qsTr("Vacuited is up to date");
                            }
                        }

                        StyledText {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            elide: Text.ElideRight
                            color: Colours.palette.m3onSurfaceVariant
                            font: Tokens.font.body.small
                            text: {
                                const checked = qsTr("Checked %1").arg(root.formatRelativeTime(Updates.lastCheckedIso));
                                const sh = Updates.shellInfo?.installedShort ? `Shell ${Updates.shellInfo.installedShort}` : "";
                                const cl = Updates.cliInfo?.installedShort ? `CLI ${Updates.cliInfo.installedShort}` : "";
                                return [checked, sh, cl].filter(x => x).join(" · ");
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: false
                        spacing: Tokens.spacing.small

                        IconTextButton {
                            visible: Updates.updating
                            type: IconTextButton.Tonal
                            icon: "close"
                            disabled: Updates.canceling
                            text: Updates.canceling ? qsTr("Canceling...") : qsTr("Cancel")
                            onClicked: Updates.cancelUpdate()
                        }

                        IconTextButton {
                            visible: !Updates.updating
                            type: IconTextButton.Filled
                            disabled: Updates.checking
                            icon: Updates.hasAnyUpdate ? "download" : (Updates.baselineMissing ? "check" : "refresh")
                            text: {
                                if (Updates.hasAnyUpdate) {
                                    if (Updates.shellHasUpdate && Updates.cliHasUpdate)
                                        return qsTr("Update all");
                                    return Updates.shellHasUpdate ? qsTr("Update Shell") : qsTr("Update CLI");
                                }
                                if (Updates.baselineMissing)
                                    return qsTr("Mark synced");
                                return qsTr("Check now");
                            }
                            onClicked: {
                                if (Updates.hasAnyUpdate) {
                                    const target = (Updates.shellHasUpdate && Updates.cliHasUpdate)
                                        ? "all"
                                        : (Updates.shellHasUpdate ? "shell" : "cli");
                                    Updates.updateComponent(target, false);
                                } else if (Updates.baselineMissing) {
                                    Updates.markSynced("all");
                                } else {
                                    Updates.checkForUpdates(true, true);
                                }
                            }
                        }

                        TextButton {
                            visible: !Updates.updating && !Updates.hasAnyUpdate && Updates.baselineMissing
                            type: TextButton.Tonal
                            disabled: Updates.checking
                            text: qsTr("Reinstall latest")
                            onClicked: Updates.updateComponent("all", false)
                        }

                        IconButton {
                            visible: !Updates.updating && (Updates.hasAnyUpdate || Updates.baselineMissing)
                            type: IconButton.Tonal
                            icon: "refresh"
                            disabled: Updates.checking
                            onClicked: Updates.checkForUpdates(true, true)
                        }

                        IconButton {
                            visible: Updates.logLines.length > 0
                            type: IconButton.Tonal
                            isToggle: true
                            checked: root.showLogs
                            icon: "terminal"
                            onClicked: root.showLogs = !root.showLogs
                        }
                    }
                }

                StyledProgressBar {
                    visible: Updates.checking || Updates.updating
                    Layout.fillWidth: true
                    indeterminate: Updates.checking || Updates.progress <= 0
                    wavy: Updates.updating
                    value: Updates.progress
                }

                StyledRect {
                    visible: !Updates.updating && !Updates.hasAnyUpdate && Updates.baselineMissing && Updates.lastError === ""
                    Layout.fillWidth: true
                    radius: Tokens.rounding.large
                    color: Colours.layer(Colours.palette.m3surfaceContainerHigh, 1)
                    implicitHeight: baselineRow.implicitHeight + Tokens.padding.medium * 2

                    RowLayout {
                        id: baselineRow
                        anchors.fill: parent
                        anchors.margins: Tokens.padding.medium
                        spacing: Tokens.spacing.medium

                        MaterialIcon {
                            text: "info"
                            fontStyle: Tokens.font.icon.medium
                            color: Colours.palette.m3onSurfaceVariant
                        }

                        StyledText {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            wrapMode: Text.WordWrap
                            font: Tokens.font.body.small
                            color: Colours.palette.m3onSurfaceVariant
                            text: qsTr("No install baseline recorded yet. Click Mark synced if you're already up to date, or Reinstall latest to pull origin/main.")
                        }
                    }
                }

                StyledRect {
                    visible: Updates.lastError !== ""
                    Layout.fillWidth: true
                    radius: Tokens.rounding.large
                    color: Colours.palette.m3errorContainer
                    implicitHeight: errRow.implicitHeight + Tokens.padding.medium * 2

                    RowLayout {
                        id: errRow
                        anchors.fill: parent
                        anchors.margins: Tokens.padding.medium
                        spacing: Tokens.spacing.medium

                        MaterialIcon {
                            text: "error"
                            fontStyle: Tokens.font.icon.medium
                            color: Colours.palette.m3onErrorContainer
                        }

                        StyledText {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            wrapMode: Text.WordWrap
                            font: Tokens.font.body.small
                            color: Colours.palette.m3onErrorContainer
                            text: Updates.lastError
                        }

                        IconTextButton {
                            visible: Updates.canTerminalFallback
                            type: IconTextButton.Filled
                            icon: "terminal"
                            text: qsTr("Run in terminal")
                            onClicked: Updates.runTerminalFallback()
                        }
                    }
                }

                StyledRect {
                    visible: Boolean(Updates.shellInfo?.touchesDeps) || Boolean(Updates.cliInfo?.touchesDeps)
                    Layout.fillWidth: true
                    radius: Tokens.rounding.large
                    color: Colours.palette.m3tertiaryContainer
                    implicitHeight: depsRow.implicitHeight + Tokens.padding.medium * 2

                    RowLayout {
                        id: depsRow
                        anchors.fill: parent
                        anchors.margins: Tokens.padding.medium
                        spacing: Tokens.spacing.medium

                        MaterialIcon {
                            text: "info"
                            fontStyle: Tokens.font.icon.medium
                            color: Colours.palette.m3onTertiaryContainer
                        }

                        StyledText {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            wrapMode: Text.WordWrap
                            font: Tokens.font.body.small
                            color: Colours.palette.m3onTertiaryContainer
                            text: qsTr("Incoming changes update dependencies in install.sh. Package installs stay manual—review install.sh if new packages are required.")
                        }
                    }
                }
            }
        }

        // Components
        SectionHeader {
            text: qsTr("Components")
        }

        ComponentCard {
            first: true
            title: qsTr("Vacuited Shell")
            icon: "deployed_code"
            componentKey: "shell"
            info: Updates.shellInfo
        }

        ComponentCard {
            last: true
            title: qsTr("Vacuited CLI")
            icon: "terminal"
            componentKey: "cli"
            info: Updates.cliInfo
        }

        // Live output log
        SectionHeader {
            visible: Updates.logLines.length > 0 && (root.showLogs || Updates.updating || Updates.lastError !== "")
            text: qsTr("Output log")
        }

        ConnectedRect {
            visible: Updates.logLines.length > 0 && (root.showLogs || Updates.updating || Updates.lastError !== "")
            first: true
            last: true
            Layout.fillWidth: true
            implicitHeight: 220

            StyledFlickable {
                id: logFlick

                anchors.fill: parent
                anchors.margins: Tokens.padding.medium
                clip: true
                contentWidth: width
                contentHeight: logEdit.implicitHeight

                StyledScrollBar.vertical: StyledScrollBar {
                    flickable: logFlick
                }

                TextEdit {
                    id: logEdit

                    width: logFlick.width
                    readOnly: true
                    selectByMouse: true
                    wrapMode: TextEdit.Wrap
                    font: Tokens.font.mono.small
                    color: Colours.palette.m3onSurfaceVariant
                    selectionColor: Colours.palette.m3primaryContainer
                    selectedTextColor: Colours.palette.m3onPrimaryContainer
                    text: Updates.logLines.map(e => e.line).join("\n")

                    onTextChanged: {
                        if (logFlick.contentHeight > logFlick.height)
                            logFlick.contentY = Math.max(0, logFlick.contentHeight - logFlick.height);
                    }
                }
            }
        }

        // Backups & Rollback
        SectionHeader {
            text: qsTr("Snapshots & rollback")
        }

        InfoRow {
            visible: Updates.backups.length === 0
            first: true
            last: true
            icon: "history"
            label: qsTr("No shell backups yet")
            value: qsTr("Saved automatically before each update")
        }

        Repeater {
            model: Updates.backups

            ConnectedRect {
                id: bakRow

                required property var modelData
                required property int index

                first: index === 0
                last: index === Updates.backups.length - 1
                Layout.fillWidth: true
                implicitHeight: bakLayout.implicitHeight + root.Tokens.padding.medium * 2

                RowLayout {
                    id: bakLayout

                    anchors.fill: parent
                    anchors.margins: root.Tokens.padding.medium
                    anchors.leftMargin: root.Tokens.padding.largeIncreased
                    anchors.rightMargin: root.Tokens.padding.largeIncreased
                    spacing: root.Tokens.spacing.medium

                    MaterialIcon {
                        text: "history"
                        fontStyle: root.Tokens.font.icon.medium
                        color: Colours.palette.m3onSurfaceVariant
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: root.Tokens.spacing.small

                            StyledText {
                                Layout.minimumWidth: 0
                                elide: Text.ElideRight
                                font: root.Tokens.font.body.small
                                text: bakRow.modelData.name
                            }

                            StyledRect {
                                Layout.fillWidth: false
                                radius: root.Tokens.rounding.full
                                implicitWidth: abiLabel.implicitWidth + root.Tokens.padding.small * 2
                                implicitHeight: abiLabel.implicitHeight + root.Tokens.padding.extraSmall
                                color: bakRow.modelData.pluginAbiMatch === false
                                    ? Colours.palette.m3errorContainer
                                    : bakRow.modelData.pluginAbiMatch === true
                                        ? Colours.palette.m3secondaryContainer
                                        : Colours.layer(Colours.palette.m3surfaceContainerHighest, 1)

                                StyledText {
                                    id: abiLabel
                                    anchors.centerIn: parent
                                    font: root.Tokens.font.label.small
                                    color: bakRow.modelData.pluginAbiMatch === false
                                        ? Colours.palette.m3onErrorContainer
                                        : bakRow.modelData.pluginAbiMatch === true
                                            ? Colours.palette.m3onSecondaryContainer
                                            : Colours.palette.m3onSurfaceVariant
                                    text: bakRow.modelData.pluginAbiMatch === false
                                        ? qsTr("Plugin SHA differs · QML only")
                                        : bakRow.modelData.pluginAbiMatch === true
                                            ? qsTr("Plugin matches")
                                            : qsTr("QML snapshot")
                                }
                            }

                            Item {
                                Layout.fillWidth: true
                            }
                        }

                        StyledText {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            elide: Text.ElideRight
                            font: root.Tokens.font.label.small
                            color: Colours.palette.m3outline
                            text: {
                                const sha = bakRow.modelData.shellShort ? `Commit ${bakRow.modelData.shellShort}` : qsTr("Unrecorded commit");
                                const dateStr = root.formatRelativeTime(bakRow.modelData.createdAt);
                                return `${sha} · ${dateStr}`;
                            }
                        }
                    }

                    TextButton {
                        readonly property bool isConfirming: root.confirmingBackup === bakRow.modelData.name

                        type: isConfirming ? TextButton.Filled : TextButton.Tonal
                        disabled: Updates.updating || Updates.checking || !bakRow.modelData.valid
                        text: isConfirming ? qsTr("Confirm?") : qsTr("Restore")
                        onClicked: {
                            if (isConfirming) {
                                confirmResetTimer.stop();
                                root.confirmingBackup = "";
                                Updates.rollback(bakRow.modelData.name);
                            } else {
                                root.confirmingBackup = bakRow.modelData.name;
                                confirmResetTimer.restart();
                            }
                        }
                    }

                    IconButton {
                        icon: "delete"
                        type: IconButton.Text
                        disabled: Updates.updating || Updates.checking
                        onClicked: Updates.deleteBackup(bakRow.modelData.name)
                    }
                }
            }
        }

        // Preferences
        SectionHeader {
            text: qsTr("Preferences")
        }

        ToggleRow {
            first: true
            text: qsTr("Check automatically in background")
            subtext: qsTr("Checks remote commits quietly on schedule without installing")
            checked: Updates.autoCheck
            onToggled: {
                Updates.autoCheck = checked;
                Updates.savePrefs();
            }
        }

        SelectRow {
            enabled: Updates.autoCheck
            label: qsTr("Check interval")
            subtext: qsTr("How often to check for new commits on main")
            menuItems: root.intervalItems
            active: root.intervalItems.find(i => i.value === Updates.checkIntervalHours) ?? root.intervalItems[1]
            onSelected: item => {
                Updates.checkIntervalHours = item.value;
                Updates.savePrefs();
            }
        }

        ToggleRow {
            last: true
            enabled: Updates.autoCheck
            text: qsTr("Notify once per new update")
            subtext: qsTr("Shows one dismissible toast per new commit, muted in Game Mode & DND")
            checked: Updates.notifyOnUpdate
            onToggled: {
                Updates.notifyOnUpdate = checked;
                Updates.savePrefs();
            }
        }
    }

    component ComponentCard: ConnectedRect {
        id: card

        required property string title
        required property string icon
        required property string componentKey
        required property var info

        readonly property bool isShell: componentKey === "shell"
        readonly property bool hasUpdate: Boolean(info?.hasUpdate)
        readonly property bool baselineMissing: Boolean(info?.baselineMissing)
        readonly property var commits: Array.isArray(info?.commits) ? info.commits : []
        readonly property int aheadBy: Number(info?.aheadBy) || commits.length

        Layout.fillWidth: true
        implicitHeight: cardCol.implicitHeight + root.Tokens.padding.large * 2

        ColumnLayout {
            id: cardCol

            anchors.fill: parent
            anchors.margins: root.Tokens.padding.large
            spacing: root.Tokens.spacing.medium

            RowLayout {
                Layout.fillWidth: true
                spacing: root.Tokens.spacing.medium

                StyledRect {
                    Layout.preferredWidth: 36
                    Layout.preferredHeight: 36
                    Layout.fillWidth: false
                    radius: root.Tokens.rounding.full
                    color: card.hasUpdate ? Colours.palette.m3primaryContainer : Colours.palette.m3secondaryContainer

                    MaterialIcon {
                        anchors.centerIn: parent
                        fill: 1
                        fontStyle: root.Tokens.font.icon.medium
                        text: card.icon
                        color: card.hasUpdate ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSecondaryContainer
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: root.Tokens.spacing.small

                        StyledText {
                            Layout.minimumWidth: 0
                            elide: Text.ElideRight
                            font: root.Tokens.font.body.medium
                            text: card.title
                        }

                        StyledRect {
                            Layout.fillWidth: false
                            radius: root.Tokens.rounding.full
                            implicitWidth: modeLabel.implicitWidth + root.Tokens.padding.small * 2
                            implicitHeight: modeLabel.implicitHeight + root.Tokens.padding.extraSmall
                            color: card.isShell && card.info?.needsPluginRebuild
                                ? Colours.palette.m3tertiaryContainer
                                : Colours.palette.m3secondaryContainer

                            StyledText {
                                id: modeLabel
                                anchors.centerIn: parent
                                font: root.Tokens.font.label.small
                                color: card.isShell && card.info?.needsPluginRebuild
                                    ? Colours.palette.m3onTertiaryContainer
                                    : Colours.palette.m3onSecondaryContainer
                                text: {
                                    if (!card.isShell)
                                        return qsTr("Rootless wheel");
                                    if (card.info?.needsPluginRebuild)
                                        return qsTr("Plugin rebuild · auth");
                                    return qsTr("Fast QML");
                                }
                            }
                        }

                        Item {
                            Layout.fillWidth: true
                        }
                    }

                    StyledText {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        elide: Text.ElideRight
                        font: root.Tokens.font.label.small
                        color: Colours.palette.m3onSurfaceVariant
                        text: {
                            const inst = card.info?.installedShort || qsTr("untracked");
                            const rem = card.info?.remoteShort || "";
                            const ver = card.info?.version ? `v${card.info.version} · ` : "";
                            if (card.hasUpdate && rem)
                                return `${ver}${inst} → ${rem} (${card.aheadBy} ahead)`;
                            if (card.baselineMissing && rem)
                                return `${ver}${qsTr("Untracked")} · ${qsTr("remote %1").arg(rem)}`;
                            return `${ver}${inst}`;
                        }
                    }
                }

                TextButton {
                    visible: card.hasUpdate || card.baselineMissing
                    type: TextButton.Tonal
                    disabled: Updates.updating || Updates.checking
                    text: card.baselineMissing ? qsTr("Reinstall") : qsTr("Update")
                    onClicked: Updates.updateComponent(card.componentKey, false)
                }

                TextButton {
                    visible: card.isShell && !card.hasUpdate && !card.baselineMissing
                    type: TextButton.Text
                    disabled: Updates.updating || Updates.checking
                    text: qsTr("Rebuild C++")
                    onClicked: Updates.updateComponent("shell", true)
                }
            }

            // Rate limit / error notice
            StyledText {
                visible: Boolean(card.info?.checkError)
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                wrapMode: Text.WordWrap
                font: root.Tokens.font.label.small
                color: Colours.palette.m3outline
                text: card.info?.rateLimited
                    ? qsTr("GitHub API rate limit reached; commit list unavailable (%1).").arg(card.info.checkError)
                    : String(card.info?.checkError || "")
            }

            // Incoming or recent commits
            ColumnLayout {
                visible: card.commits.length > 0
                Layout.fillWidth: true
                spacing: root.Tokens.spacing.extraSmall

                StyledText {
                    Layout.fillWidth: true
                    font: root.Tokens.font.label.small
                    color: Colours.palette.m3outline
                    text: card.baselineMissing
                        ? qsTr("Recent commits on main")
                        : qsTr("Incoming commits (%1)").arg(card.aheadBy)
                }

                Repeater {
                    model: card.commits.slice(0, 10)

                    RowLayout {
                        id: commitRow

                        required property var modelData

                        Layout.fillWidth: true
                        spacing: root.Tokens.spacing.small

                        StyledRect {
                            Layout.fillWidth: false
                            radius: root.Tokens.rounding.small
                            color: Colours.layer(Colours.palette.m3surfaceContainerHigh, 1)
                            implicitWidth: shaText.implicitWidth + root.Tokens.padding.small * 2
                            implicitHeight: shaText.implicitHeight + root.Tokens.padding.extraSmall

                            StyledText {
                                id: shaText
                                anchors.centerIn: parent
                                font: root.Tokens.font.mono.small
                                color: Colours.palette.m3primary
                                text: commitRow.modelData.shortSha || ""
                            }
                        }

                        StyledText {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            elide: Text.ElideRight
                            font: root.Tokens.font.body.small
                            text: commitRow.modelData.title || ""
                        }

                        StyledText {
                            Layout.fillWidth: false
                            font: root.Tokens.font.label.small
                            color: Colours.palette.m3outline
                            text: root.formatShortDate(commitRow.modelData.date || "")
                        }
                    }
                }

                StyledText {
                    visible: card.aheadBy > 10
                    Layout.fillWidth: true
                    font: root.Tokens.font.label.small
                    color: Colours.palette.m3outline
                    text: qsTr("+ %1 older commit(s)").arg(card.aheadBy - 10)
                }

                RowLayout {
                    visible: Boolean(card.info?.compareUrl)
                    Layout.fillWidth: true

                    Item {
                        Layout.fillWidth: true
                    }

                    IconTextButton {
                        type: IconTextButton.Text
                        icon: "open_in_new"
                        text: qsTr("View diff on GitHub")
                        onClicked: Qt.openUrlExternally(card.info.compareUrl)
                    }
                }
            }
        }
    }
}

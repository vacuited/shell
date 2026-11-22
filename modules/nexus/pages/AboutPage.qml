import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import Caelestia
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.services
import qs.utils
import qs.modules.nexus
import qs.modules.nexus.common

PageBase {
    id: root

    // Plugin support is not wired up yet; always 0 for now
    readonly property int pluginCount: 0

    property string quickshellVersion
    property string cliVersion

    title: Tr.tr("About")

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        // e.g. "Quickshell 0.3.0 (revision ...)"
        Process {
            running: true
            command: ["quickshell", "--version"]
            stdout: StdioCollector {
                onStreamFinished: root.quickshellVersion = text.trim().split(" ")[1] ?? ""
            }
        }

        // Parsed from the caelestia CLI's package listing; the sh wrapper avoids a
        // warning when the (optional) CLI isn't installed
        Process {
            running: true
            command: ["sh", "-c", "caelestia --version 2>/dev/null"]
            stdout: StdioCollector {
                onStreamFinished: {
                    const m = text.match(/caelestia-cli\S*\s+(\d+(?:\.\d+)*)/);
                    root.cliVersion = m ? m[1] : "";
                }
            }
        }

        // Hero
        ConnectedRect {
            Layout.fillWidth: true
            first: true
            last: true
            implicitHeight: hero.implicitHeight + Tokens.padding.extraLarge * 2

            ColumnLayout {
                id: hero

                anchors.centerIn: parent
                width: parent.width - Tokens.padding.largeIncreased * 2
                spacing: Tokens.spacing.small

                property int clicks: 0

                VoidLogo {
                    id: aboutLogo

                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: 164
                    Layout.preferredHeight: 164
                    interactive: true
                }

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: Tokens.spacing.small
                    text: "Vacuited"
                    font: Tokens.font.headline.builders.large.width(110).build()
                }

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: Tokens.spacing.small
                    text: qsTr("by vacuit")
                    color: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.label.medium
                    opacity: 0.8
                }

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: CUtils.version ? `v${CUtils.version}` : "…"
                    color: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.body.medium

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            aboutLogo.surge();
                            if (GlobalConfig.general.developerMode) {
                                Toaster.toast(qsTr("Developer Options"), qsTr("No need, you are already a developer."), "construction");
                                return;
                            }

                            hero.clicks++;
                            const remaining = 7 - hero.clicks;
                            if (remaining > 0 && remaining <= 4) {
                                Toaster.toast(qsTr("Developer Options"), qsTr("You are now %1 steps away from being a developer.").arg(remaining), "construction");
                            } else if (remaining === 0) {
                                root.nState.justUnlockedDevMode = true;
                                GlobalConfig.general.developerMode = true;
                                Toaster.toast(qsTr("Developer Options"), qsTr("You are now a developer!"), "construction");
                            }
                        }
                    }
                }
            }
        }

        // Update status
        NavRow {
            first: true
            last: true
            Layout.topMargin: Tokens.spacing.small
            icon: Updates.updating ? "sync" : Updates.hasAnyUpdate ? "system_update" : Updates.baselineMissing ? "sync_problem" : "check_circle"
            iconLabel.color: Updates.hasAnyUpdate ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
            text: {
                if (Updates.updating)
                    return Updates.phase || qsTr("Updating Vacuited...");
                if (Updates.checking)
                    return qsTr("Checking for updates...");
                if (Updates.hasAnyUpdate)
                    return qsTr("Updates available (%1 commit%2)").arg(Updates.totalUpdateCommits).arg(Updates.totalUpdateCommits === 1 ? "" : "s");
                if (Updates.baselineMissing)
                    return qsTr("Updates — baseline not synced");
                return qsTr("Vacuited is up to date");
            }
            subtext: {
                const s = Updates.shellInfo?.installedShort ? `Shell ${Updates.shellInfo.installedShort}` : "";
                const c = Updates.cliInfo?.installedShort ? `CLI ${Updates.cliInfo.installedShort}` : "";
                const parts = [s, c].filter(x => x);
                return parts.length > 0 ? parts.join(" · ") : qsTr("Open Nexus > Updates");
            }
            onClicked: root.nState.currentPageIdx = PageRegistry.indexOfKey("updates")
        }

        // System
        SectionHeader {
            text: Tr.tr("System")
        }

        InfoRow {
            first: true
            label: Tr.tr("Hostname")
            value: SysInfo.hostname
        }

        InfoRow {
            label: Tr.trCtx("Device", "system model name")
            value: SysInfo.device
        }

        InfoRow {
            label: Tr.tr("Distro")
            value: SysInfo.osPrettyName || SysInfo.osName
        }

        InfoRow {
            label: Tr.tr("Kernel")
            value: SysInfo.kernel
        }

        InfoRow {
            last: true
            // TRANSLATORS: BIOS or UEFI firmware version
            label: Tr.tr("Firmware")
            value: SysInfo.firmware
        }

        // Software
        SectionHeader {
            text: Tr.tr("Software")
        }

        InfoRow {
            first: true
            label: Tr.trCtx("Shell", "the caelestia shell itself, not a unix shell")
            value: {
                const ver = CUtils.version || "…";
                const sha = Updates.shellInfo?.installedShort ?? "";
                return sha ? `${ver} (${sha})` : ver;
            }
        }

        InfoRow {
            label: Tr.trCtx("CLI", "the caelestia command line tool")
            value: {
                const ver = root.cliVersion || "…";
                const sha = Updates.cliInfo?.installedShort ?? "";
                return sha ? `${ver} (${sha})` : ver;
            }
        }

        InfoRow {
            label: "Quickshell"
            value: root.quickshellVersion || "…"
        }

        InfoRow {
            last: true
            label: "Qt"
            value: CUtils.qtVersion || "…"
        }

        // Plugins
        SectionHeader {
            text: Tr.tr("Plugins")
        }

        InfoRow {
            first: true
            last: true
            label: Tr.tr("Loaded plugins")
            value: root.pluginCount.toString()
        }
    }
}

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Caelestia
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services
import qs.modules.nexus.common

PageBase {
    id: root

    title: Tr.tr("Focus tab")
    isSubPage: true

    readonly property list<MenuItem> presetItems: [
        MenuItem { text: "25 / 5 (Pomodoro)"; property int fM: 25; property int sM: 5 },
        MenuItem { text: "50 / 10 (Deep Study)"; property int fM: 50; property int sM: 10 },
        MenuItem { text: "60 / 10 (1h MCQ Paper)"; property int fM: 60; property int sM: 10 },
        MenuItem { text: "120 / 15 (2h Past Paper)"; property int fM: 120; property int sM: 15 },
        MenuItem { text: "180 / 15 (3h Past Paper)"; property int fM: 180; property int sM: 15 }
    ]

    property list<MenuItem> focusSoundItems: []
    property list<MenuItem> breakSoundItems: []

    function addSubject(): void {
        let name = subjectInput.text.trim();
        if (name === "" || name.length > 20) return;
        let list = Array.from(GlobalConfig.focus.subjects);
        if (list.length >= 8) return;
        let exists = list.some(s => s.toLowerCase() === name.toLowerCase());
        if (!exists) {
            list.push(name);
            GlobalConfig.focus.subjects = list;
            GlobalConfig.save();
        }
        subjectInput.text = "";
    }

    function addCountdown(): void {
        const title = countdownTitleInput.text.trim();
        const date = countdownDateInput.text.trim();
        if (title === "" || date === "") return;
        if (FocusLedger.addCountdown(title, date)) {
            countdownTitleInput.text = "";
            countdownDateInput.text = "";
        } else {
            Toaster.toast(Tr.tr("Invalid countdown date"), Tr.tr("Use YYYY-MM-DD format (e.g. 2027-08-02)."), "event_busy", Toast.Warning);
        }
    }

    contentChild: ColumnLayout {
        id: mainLayout
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        Component {
            id: soundItemComp
            MenuItem {
                property string file: ""
            }
        }

        Process {
            id: soundListProc
            command: ["sh", "-c", 'ls -1 "$1/assets/sounds/notifications" | grep -E "\\.wav$" | sort', "--", Quickshell.shellDir]
            stdout: StdioCollector {
                onStreamFinished: {
                    let lines = text.trim().split("\n").filter(l => l.length > 0);
                    let fItems = [];
                    let bItems = [];
                    for (let i = 0; i < lines.length; i++) {
                        let file = lines[i];
                        let name = file.replace(/\.wav$/i, "");
                        let item1 = soundItemComp.createObject(root, { text: name, file: file });
                        let item2 = soundItemComp.createObject(root, { text: name, file: file });
                        fItems.push(item1);
                        bItems.push(item2);
                    }
                    focusSoundItems = fItems;
                    breakSoundItems = bItems;
                }
            }
        }

        Component.onCompleted: soundListProc.running = true

        // Cycle
        SectionHeader {
            first: true
            text: Tr.tr("Cycle")
        }

        SelectRow {
            first: true
            label: Tr.tr("Preset")
            fallbackText: Tr.tr("Custom")
            active: {
                for (let i = 0; i < root.presetItems.length; i++) {
                    if (GlobalConfig.focus.focusMins === root.presetItems[i].fM
                        && GlobalConfig.focus.shortBreakMins === root.presetItems[i].sM)
                        return root.presetItems[i];
                }
                return null;
            }
            menuItems: root.presetItems
            onSelected: item => {
                GlobalConfig.focus.focusMins = item.fM;
                GlobalConfig.focus.shortBreakMins = item.sM;
                GlobalConfig.save();
            }
        }

        StepperRow {
            label: Tr.tr("Focus length")
            value: GlobalConfig.focus.focusMins
            from: 5
            to: 180
            stepSize: 5
            onMoved: v => {
                GlobalConfig.focus.focusMins = Math.round(v);
                GlobalConfig.save();
            }
        }

        StepperRow {
            label: Tr.tr("Short break")
            value: GlobalConfig.focus.shortBreakMins
            from: 1
            to: 60
            stepSize: 1
            onMoved: v => {
                GlobalConfig.focus.shortBreakMins = Math.round(v);
                GlobalConfig.save();
            }
        }

        StepperRow {
            label: Tr.tr("Big break")
            value: GlobalConfig.focus.longBreakMins
            from: 5
            to: 180
            stepSize: 5
            onMoved: v => {
                GlobalConfig.focus.longBreakMins = Math.round(v);
                GlobalConfig.save();
            }
        }

        StepperRow {
            label: Tr.tr("Cycles before Big Break")
            value: GlobalConfig.focus.cyclesBeforeLongBreak
            from: 2
            to: 8
            stepSize: 1
            onMoved: v => {
                GlobalConfig.focus.cyclesBeforeLongBreak = Math.round(v);
                GlobalConfig.save();
            }
        }

        ToggleRow {
            text: Tr.tr("Auto-play next phase")
            checked: GlobalConfig.focus.autoPlay
            onToggled: {
                GlobalConfig.focus.autoPlay = checked;
                GlobalConfig.save();
            }
        }

        ToggleRow {
            last: true
            text: Tr.tr("Pause timer when screen sleeps")
            subtext: Tr.tr("Keep off when studying from physical books while display sleeps")
            checked: FocusLedger.pauseOnSleep
            onToggled: FocusLedger.setPauseOnSleep(checked)
        }

        // Goals
        SectionHeader {
            text: Tr.tr("Goals")
        }

        StepperRow {
            first: true
            label: Tr.tr("Daily goal (minutes)")
            value: GlobalConfig.focus.dailyGoalMins
            from: 15
            to: 720
            stepSize: 15
            onMoved: v => {
                GlobalConfig.focus.dailyGoalMins = Math.round(v);
                GlobalConfig.save();
            }
        }

        StepperRow {
            last: true
            label: Tr.tr("Streak threshold (minutes)")
            value: GlobalConfig.focus.streakThresholdMins
            from: 5
            to: 480
            stepSize: 5
            onMoved: v => {
                GlobalConfig.focus.streakThresholdMins = Math.round(v);
                GlobalConfig.save();
            }
        }

        // Subjects
        SectionHeader {
            text: Tr.tr("Subjects")
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small

            StyledTextField {
                id: subjectInput
                Layout.fillWidth: true
                placeholderText: Tr.tr("Add subject (max 20 chars)")
                maximumLength: 20
                onAccepted: root.addSubject()
            }

            IconTextButton {
                text: Tr.tr("Add")
                icon: "add"
                disabled: (GlobalConfig.focus.subjects.length >= 8) || (subjectInput.text.trim() === "")
                onClicked: root.addSubject()
            }
        }

        Flow {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small
            visible: GlobalConfig.focus.subjects.length > 0

            Repeater {
                model: GlobalConfig.focus.subjects
                delegate: StyledRect {
                    required property string modelData
                    required property int index

                    color: Colours.layer(Colours.palette.m3surfaceContainer, 2)
                    radius: Tokens.rounding.large
                    implicitWidth: chipLayout.implicitWidth + Tokens.padding.medium * 2
                    implicitHeight: chipLayout.implicitHeight + Tokens.padding.extraSmall * 2

                    RowLayout {
                        id: chipLayout
                        x: Tokens.padding.medium
                        y: Tokens.padding.extraSmall
                        spacing: Tokens.spacing.extraSmall

                        StyledText {
                            text: modelData
                            font: Tokens.font.label.medium
                        }

                        MaterialIcon {
                            text: "close"
                            fontStyle: Tokens.font.icon.small

                            StateLayer {
                                onClicked: {
                                    let list = Array.from(GlobalConfig.focus.subjects);
                                    list.splice(index, 1);
                                    GlobalConfig.focus.subjects = list;
                                    GlobalConfig.save();
                                }
                            }
                        }
                    }
                }
            }
        }

        // Sound & DND
        SectionHeader {
            text: Tr.tr("Sound & DND")
        }

        ToggleRow {
            first: true
            text: Tr.tr("Play chime")
            checked: GlobalConfig.focus.chime
            onToggled: {
                GlobalConfig.focus.chime = checked;
                GlobalConfig.save();
            }
        }

        ConnectedRect {
            Layout.fillWidth: true
            implicitHeight: soundRow1.implicitHeight + soundRow1.anchors.margins * 2
            clip: false
            z: focusSplit.expanded ? 2 : 1

            RowLayout {
                id: soundRow1
                anchors.fill: parent
                anchors.margins: Tokens.padding.medium
                anchors.leftMargin: Tokens.padding.largeIncreased
                anchors.rightMargin: Tokens.padding.largeIncreased
                spacing: Tokens.spacing.medium

                StyledText {
                    Layout.fillWidth: true
                    text: Tr.tr("Study end sound")
                    font: Tokens.font.body.small
                }

                IconButton {
                    icon: "play_arrow"
                    type: IconButton.Tonal
                    onClicked: Audio.playFocusEnd()
                }

                SplitButton {
                    id: focusSplit
                    type: SplitButton.Tonal
                    fallbackText: GlobalConfig.focus.focusEndSound.replace(/\.wav$/i, "")
                    active: {
                        for (let i = 0; i < root.focusSoundItems.length; i++) {
                            if (root.focusSoundItems[i].file === GlobalConfig.focus.focusEndSound)
                                return root.focusSoundItems[i];
                        }
                        return null;
                    }
                    menuItems: root.focusSoundItems
                    stateLayer.onClicked: focusSplit.expanded = !focusSplit.expanded
                    menu.onItemSelected: item => {
                        GlobalConfig.focus.focusEndSound = item.file;
                        GlobalConfig.save();
                    }
                }
            }
        }

        ConnectedRect {
            Layout.fillWidth: true
            implicitHeight: soundRow2.implicitHeight + soundRow2.anchors.margins * 2
            clip: false
            z: breakSplit.expanded ? 2 : 1

            RowLayout {
                id: soundRow2
                anchors.fill: parent
                anchors.margins: Tokens.padding.medium
                anchors.leftMargin: Tokens.padding.largeIncreased
                anchors.rightMargin: Tokens.padding.largeIncreased
                spacing: Tokens.spacing.medium

                StyledText {
                    Layout.fillWidth: true
                    text: Tr.tr("Break end sound")
                    font: Tokens.font.body.small
                }

                IconButton {
                    icon: "play_arrow"
                    type: IconButton.Tonal
                    onClicked: Audio.playBreakEnd()
                }

                SplitButton {
                    id: breakSplit
                    type: SplitButton.Tonal
                    fallbackText: GlobalConfig.focus.breakEndSound.replace(/\.wav$/i, "")
                    active: {
                        for (let i = 0; i < root.breakSoundItems.length; i++) {
                            if (root.breakSoundItems[i].file === GlobalConfig.focus.breakEndSound)
                                return root.breakSoundItems[i];
                        }
                        return null;
                    }
                    menuItems: root.breakSoundItems
                    stateLayer.onClicked: breakSplit.expanded = !breakSplit.expanded
                    menu.onItemSelected: item => {
                        GlobalConfig.focus.breakEndSound = item.file;
                        GlobalConfig.save();
                    }
                }
            }
        }

        ToggleRow {
            last: true
            text: Tr.tr("Auto Do Not Disturb")
            checked: GlobalConfig.focus.autoDnd
            onToggled: {
                GlobalConfig.focus.autoDnd = checked;
                GlobalConfig.save();
            }
        }

        // Exam Countdowns
        SectionHeader {
            text: Tr.tr("Exam Countdowns")
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small

            StyledTextField {
                id: countdownTitleInput
                Layout.fillWidth: true
                placeholderText: Tr.tr("Exam or milestone name")
                maximumLength: 32
                onAccepted: countdownDateInput.forceActiveFocus()
            }

            StyledTextField {
                id: countdownDateInput
                Layout.preferredWidth: 140
                placeholderText: "YYYY-MM-DD"
                maximumLength: 10
                onAccepted: root.addCountdown()
            }

            IconTextButton {
                text: Tr.tr("Add")
                icon: "add"
                disabled: countdownTitleInput.text.trim() === "" || !FocusLedger.parseLocalDate(countdownDateInput.text.trim())
                onClicked: root.addCountdown()
            }
        }

        Repeater {
            id: countdownRepeater
            model: {
                FocusLedger.revision;
                return FocusLedger.countdowns;
            }

            delegate: ConnectedRect {
                id: cdRow
                required property var modelData
                required property int index

                readonly property int daysLeft: {
                    void FocusLedger.todayKey;
                    return FocusLedger.daysUntil(modelData?.date ?? "");
                }

                Layout.fillWidth: true
                implicitHeight: 52
                first: index === 0
                last: index === countdownRepeater.count - 1

                RowLayout {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: Tokens.padding.largeIncreased
                    anchors.rightMargin: Tokens.padding.largeIncreased
                    spacing: Tokens.spacing.medium

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        StyledText {
                            Layout.fillWidth: true
                            text: cdRow.modelData?.title ?? ""
                            font: Tokens.font.body.small
                            elide: Text.ElideRight
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: FocusLedger.formatDateShort(cdRow.modelData?.date ?? "") + " (" + (cdRow.modelData?.date ?? "") + ")"
                            color: Colours.palette.m3outline
                            font: Tokens.font.label.small
                            elide: Text.ElideRight
                        }
                    }

                    StyledRect {
                        implicitWidth: cdBadgeTxt.implicitWidth + Tokens.padding.medium * 2
                        implicitHeight: 26
                        radius: Tokens.rounding.full
                        color: cdRow.daysLeft >= 0 ? Colours.palette.m3primaryContainer : Colours.tPalette.m3surfaceContainerHighest

                        StyledText {
                            id: cdBadgeTxt
                            anchors.centerIn: parent
                            text: cdRow.daysLeft > 0
                                ? Tr.tr("%1d left").arg(cdRow.daysLeft)
                                : (cdRow.daysLeft === 0 ? Tr.tr("Today!") : Tr.tr("%1d ago").arg(Math.abs(cdRow.daysLeft)))
                            font: Tokens.font.label.small
                            color: cdRow.daysLeft >= 0 ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurfaceVariant
                        }
                    }

                    IconButton {
                        icon: "delete"
                        type: IconButton.Text
                        onClicked: FocusLedger.removeCountdown(cdRow.modelData?.id ?? "")
                    }
                }
            }
        }

        // Screen Time
        SectionHeader {
            text: Tr.tr("Screen Time")
        }

        StepperRow {
            first: true
            label: Tr.tr("History retention (days)")
            value: ScreenTime.retentionDays
            from: 7
            to: 90
            stepSize: 7
            onMoved: v => {
                let d = Math.round(v);
                if (typeof ScreenTime.setRetentionDays === "function")
                    ScreenTime.setRetentionDays(d);
                else
                    ScreenTime.retentionDays = d;
            }
        }

        ConnectedRect {
            Layout.fillWidth: true
            implicitHeight: clearRow.implicitHeight + clearRow.anchors.margins * 2
            first: false
            last: true

            RowLayout {
                id: clearRow
                anchors.fill: parent
                anchors.margins: Tokens.padding.medium
                anchors.leftMargin: Tokens.padding.largeIncreased
                anchors.rightMargin: Tokens.padding.largeIncreased
                spacing: Tokens.spacing.medium

                StyledText {
                    Layout.fillWidth: true
                    text: Tr.tr("Reset Screen Time history")
                    font: Tokens.font.body.small
                }

                IconTextButton {
                    icon: "delete_sweep"
                    text: Tr.tr("Clear data")
                    type: ButtonBase.Tonal
                    onClicked: ScreenTime.clearHistory()
                }
            }
        }
    }
}

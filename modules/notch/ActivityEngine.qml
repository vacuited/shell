pragma ComponentBehavior: Bound

import QtQuick

Item {
    id: root

    visible: false

    // Enabled + active state inputs for each candidate source
    property bool osdActive: false
    property bool notifActive: false
    property bool notifPinned: false
    property bool toastActive: false
    property bool recordingActive: false
    property bool focusActive: false
    property bool musicActive: false
    property bool clockActive: false

    property bool bubbleEnabled: false

    // User-selected ongoing activity ("recording" | "focus" | "music" | "")
    property string preferredOngoing: ""

    readonly property var ongoingList: {
        const list = [];
        if (root.recordingActive)
            list.push("recording");
        if (root.focusActive)
            list.push("focus");
        if (root.musicActive)
            list.push("music");
        return list;
    }

    readonly property var orderedOngoing: {
        const list = root.ongoingList;
        if (list.length === 0)
            return [];
        const pref = root.preferredOngoing;
        if (pref.length === 0 || !list.includes(pref))
            return list;
        const ordered = [pref];
        for (let i = 0; i < list.length; i++) {
            if (list[i] !== pref)
                ordered.push(list[i]);
        }
        return ordered;
    }

    readonly property string primaryOngoing: orderedOngoing.length > 0 ? orderedOngoing[0] : ""

    // Resolved main notch activity: "osd" | "notification" | "toast" | "recording" | "focus" | "music" | "clock" | ""
    readonly property string main: {
        if (root.notifActive && root.notifPinned)
            return "notification";
        if (root.osdActive)
            return "osd";
        if (root.notifActive)
            return "notification";
        if (root.toastActive)
            return "toast";
        if (root.primaryOngoing.length > 0)
            return root.primaryOngoing;
        if (root.clockActive)
            return "clock";
        return "";
    }

    // Secondary ongoing activity occupying the left liquid droplet
    readonly property string bubble: {
        if (!root.bubbleEnabled)
            return "";
        const ordered = root.orderedOngoing;
        if (ordered.length < 2)
            return "";
        for (let i = 0; i < ordered.length; i++) {
            if (ordered[i] !== root.main)
                return ordered[i];
        }
        return "";
    }

    readonly property bool hasMultipleOngoing: ongoingList.length > 1

    onOngoingListChanged: {
        if (preferredOngoing.length > 0 && !ongoingList.includes(preferredOngoing))
            preferredOngoing = "";
    }

    function promote(activity: string): void {
        if (activity.length > 0 && ongoingList.includes(activity))
            preferredOngoing = activity;
    }

    function cycleOngoing(step: int): bool {
        const list = ongoingList;
        if (list.length < 2)
            return false;
        const cur = list.indexOf(primaryOngoing);
        const start = cur >= 0 ? cur : 0;
        const next = ((start + step) % list.length + list.length) % list.length;
        preferredOngoing = list[next];
        return true;
    }
}

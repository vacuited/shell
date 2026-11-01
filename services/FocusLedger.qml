pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia.Config
import Caelestia.I18n
import qs.services
import qs.utils

Singleton {
    id: root

    property bool ready: false
    property bool corrupt: false
    property int revision: 0
    property string todayKey: Qt.formatDate(new Date(), "yyyy-MM-dd")

    property var days: ({})
    property var pendingSecs: ({})
    property int pendingSessions: 0
    property bool dirty: false
    property bool backedUp: false

    readonly property int todaySecs: {
        revision;
        return (days[todayKey] && days[todayKey].focusSecs) ? days[todayKey].focusSecs : 0;
    }

    readonly property int todaySessions: {
        revision;
        return (days[todayKey] && days[todayKey].sessions) ? days[todayKey].sessions : 0;
    }

    readonly property bool todayRest: {
        revision;
        return (days[todayKey] && days[todayKey].restDay) ? true : false;
    }

    readonly property int weekSecs: {
        revision;
        let total = 0;
        let keys = weekKeys();
        for (let i = 0; i < keys.length; i++) {
            let d = days[keys[i]];
            if (d && d.focusSecs) total += d.focusSecs;
        }
        return total;
    }

    property var weekNames: []

    readonly property int streak: {
        revision;
        if (!ready) return 0;
        let thr = (GlobalConfig.focus.streakThresholdMins || 30) * 60;
        let s = 0;
        let now = new Date();
        let todayStr = Qt.formatDate(now, "yyyy-MM-dd");

        function qualifies(k) {
            let d = days[k];
            return d && (d.focusSecs || 0) >= thr;
        }

        if (qualifies(todayStr)) {
            s++;
        }

        let cur = new Date(now);
        cur.setDate(cur.getDate() - 1);
        let count = 0;
        while (count < 800) {
            let k = Qt.formatDate(cur, "yyyy-MM-dd");
            if (qualifies(k)) {
                s++;
            } else if (days[k] && days[k].restDay) {
                // rest day: skipped, neither counts nor breaks
            } else {
                break;
            }
            cur.setDate(cur.getDate() - 1);
            count++;
        }
        return s;
    }

    readonly property FileView backupFile: FileView {
        path: `${Paths.state}/focus_ledger.json.bak`
        printErrors: false
    }

    readonly property FileView ledgerFile: FileView {
        path: `${Paths.state}/focus_ledger.json`
        preload: true
        watchChanges: false
        printErrors: false

        onLoaded: root.loadData(text())
        onLoadFailed: err => {
            if (err === FileViewError.FileNotFound) {
                root.days = {};
                root.ready = true;
                root.mergePending();
                root.refreshWeekNames();
                root.revision++;
            } else {
                root.ready = false;
            }
        }
    }

    function checkTodayKey(): void {
        let k = Qt.formatDate(new Date(), "yyyy-MM-dd");
        if (k !== todayKey) {
            todayKey = k;
            refreshWeekNames();
            revision++;
        }
    }

    function addFocusSecs(subject: string, secs: int): void {
        checkTodayKey();
        let sKey = subject || "__none__";
        if (!ready) {
            pendingSecs[sKey] = (pendingSecs[sKey] || 0) + secs;
            return;
        }

        if (!days[todayKey]) {
            days[todayKey] = {
                focusSecs: 0,
                sessions: 0,
                restDay: false,
                subjects: {}
            };
        }
        if (!days[todayKey].subjects) {
            days[todayKey].subjects = {};
        }

        days[todayKey].focusSecs = (days[todayKey].focusSecs || 0) + secs;
        days[todayKey].subjects[sKey] = (days[todayKey].subjects[sKey] || 0) + secs;
        dirty = true;
        revision++;
    }

    function addSession(): void {
        checkTodayKey();
        if (!ready) {
            pendingSessions++;
            return;
        }

        if (!days[todayKey]) {
            days[todayKey] = {
                focusSecs: 0,
                sessions: 0,
                restDay: false,
                subjects: {}
            };
        }
        days[todayKey].sessions = (days[todayKey].sessions || 0) + 1;
        dirty = true;
        revision++;
        saveDebounce.restart();
    }

    function setRestDay(key: string, on: bool): void {
        if (!ready) return;
        if (!days[key]) {
            days[key] = {
                focusSecs: 0,
                sessions: 0,
                restDay: false,
                subjects: {}
            };
        }
        days[key].restDay = !!on;
        dirty = true;
        revision++;
        saveDebounce.restart();
    }

    function weekKeys(): var {
        let now = new Date();
        let keys = [];
        let offset = (now.getDay() + 6) % 7; // Monday = 0, Sunday = 6
        let monday = new Date(now);
        monday.setDate(now.getDate() - offset);

        for (let i = 0; i < 7; i++) {
            let cur = new Date(monday);
            cur.setDate(monday.getDate() + i);
            keys.push(Qt.formatDate(cur, "yyyy-MM-dd"));
        }
        return keys;
    }

    function weekSecsFor(name: string): int {
        revision;
        let sKey = name || "__none__";
        let total = 0;
        let keys = weekKeys();
        for (let i = 0; i < keys.length; i++) {
            let d = days[keys[i]];
            if (d && d.subjects && d.subjects[sKey]) {
                total += d.subjects[sKey];
            }
        }
        return total;
    }

    function refreshWeekNames(): void {
        let keys = weekKeys();
        let map = {};
        for (let i = 0; i < keys.length; i++) {
            let d = days[keys[i]];
            if (d && d.subjects) {
                for (let k in d.subjects) {
                    if (d.subjects.hasOwnProperty(k)) {
                        map[k] = (map[k] || 0) + d.subjects[k];
                    }
                }
            }
        }
        let list = Object.keys(map).sort((a, b) => (map[b] || 0) - (map[a] || 0));
        if (JSON.stringify(list) !== JSON.stringify(weekNames)) {
            weekNames = list;
        }
    }

    function dayState(key: string): string {
        revision;
        let today = Qt.formatDate(new Date(), "yyyy-MM-dd");
        if (key > today) return "future";
        let d = days[key];
        let thr = (GlobalConfig.focus.streakThresholdMins || 30) * 60;
        let secs = d ? (d.focusSecs || 0) : 0;
        if (secs >= thr) return "done";
        if (d && d.restDay) return "rest";
        if (key === today) return "today";
        return "missed";
    }

    function fmt(secs: int): string {
        if (!secs || secs <= 0) return "0m";
        let totalMins = Math.floor(secs / 60);
        let h = Math.floor(totalMins / 60);
        let m = totalMins % 60;
        if (h > 0) {
            return h + "h " + (m < 10 ? "0" + m : m) + "m";
        }
        return m + "m";
    }

    function flush(): void {
        if (!ready || corrupt || !dirty) return;
        saveImmediate();
    }

    function loadData(rawText: string): void {
        try {
            if (!rawText || rawText.trim() === "") {
                days = {};
                ready = true;
                mergePending();
                refreshWeekNames();
                revision++;
                return;
            }
            let data = JSON.parse(rawText);
            if (typeof data !== "object" || data === null) throw new Error("Invalid ledger format");
            days = data.days || {};
            ready = true;
            if (!backedUp) {
                backupFile.setText(rawText);
                backedUp = true;
            }
            mergePending();
            refreshWeekNames();
            revision++;
        } catch (e) {
            ready = false;
            corrupt = true;
            Toaster.toast(Tr.tr("Focus Ledger Error"), Tr.tr("Failed to read focus data. Ledger locked to prevent overwrite."), "error");
        }
    }

    function mergePending(): void {
        if (!ready) return;
        let changed = false;
        if (pendingSessions > 0) {
            if (!days[todayKey]) {
                days[todayKey] = { focusSecs: 0, sessions: 0, restDay: false, subjects: {} };
            }
            days[todayKey].sessions = (days[todayKey].sessions || 0) + pendingSessions;
            pendingSessions = 0;
            changed = true;
        }
        for (let s in pendingSecs) {
            if (pendingSecs.hasOwnProperty(s)) {
                let secs = pendingSecs[s];
                if (secs > 0) {
                    if (!days[todayKey]) {
                        days[todayKey] = { focusSecs: 0, sessions: 0, restDay: false, subjects: {} };
                    }
                    if (!days[todayKey].subjects) {
                        days[todayKey].subjects = {};
                    }
                    days[todayKey].focusSecs = (days[todayKey].focusSecs || 0) + secs;
                    days[todayKey].subjects[s] = (days[todayKey].subjects[s] || 0) + secs;
                    changed = true;
                }
            }
        }
        pendingSecs = {};
        if (changed) {
            dirty = true;
            revision++;
            saveDebounce.restart();
        }
    }

    function saveImmediate(): void {
        if (!ready || corrupt || !dirty) return;
        let data = {
            version: 1,
            days: days
        };
        ledgerFile.setText(JSON.stringify(data, null, 2));
        dirty = false;
    }

    Timer {
        id: saveDebounce
        interval: 400
        repeat: false
        onTriggered: root.saveImmediate()
    }

    Timer {
        interval: 30000
        repeat: true
        running: true
        onTriggered: root.checkTodayKey()
    }

    Timer {
        interval: 15000
        repeat: true
        running: true
        onTriggered: root.refreshWeekNames()
    }

    Component.onDestruction: root.flush()
}

pragma Singleton

import QtQuick
import Quickshell
import Caelestia
import Caelestia.Config

Singleton {
    id: root

    property bool available: true
    property string loadError: ""
    property bool isEnabled: false
    property bool isVisible: false
    property var nearbyDevices: []
    property var transferHistory: []

    property var currentNotification: null
    property string currentDeviceName: ""
    property string currentFileName: ""
    property string currentPinCode: ""

    property QtObject _bridge: null
    property var _service: null
    property bool _loadAttempted: false

    function _ensureBackend(notifyOnError: bool): bool {
        if (root._service)
            return true;

        if (root._loadAttempted) {
            if (notifyOnError)
                Toaster.toast(qsTr("Quick Share unavailable"), root.loadError || qsTr("Quick Share plugin could not be loaded. Rebuild vacuited-shell if system libraries updated."), "error");
            return false;
        }

        root._loadAttempted = true;
        const comp = Qt.createComponent(Qt.resolvedUrl("quickshare/QuickShareBridge.qml"), Component.PreferSynchronous);
        if (comp.status !== Component.Ready) {
            root.available = false;
            root.loadError = comp.errorString().trim();
            console.warn("[QuickShare] Failed to load Caelestia.QuickShare backend:", root.loadError);
            if (notifyOnError)
                Toaster.toast(qsTr("Quick Share unavailable"), root.loadError || qsTr("Quick Share plugin could not be loaded. Rebuild vacuited-shell if system libraries updated."), "error");
            return false;
        }

        const bridge = comp.createObject(root);
        if (!bridge || !bridge.service) {
            root.available = false;
            root.loadError = qsTr("QuickShareService singleton could not be instantiated.");
            console.warn("[QuickShare]", root.loadError);
            if (notifyOnError)
                Toaster.toast(qsTr("Quick Share unavailable"), root.loadError, "error");
            return false;
        }

        const svc = bridge.service;
        root._bridge = bridge;
        root._service = svc;
        root.available = true;
        root.loadError = "";

        root.isEnabled = svc.isEnabled;
        root.isVisible = svc.isVisible;
        root.nearbyDevices = svc.nearbyDevices;
        root.transferHistory = svc.transferHistory;

        svc.isEnabledChanged.connect(() => {
            root.isEnabled = svc.isEnabled;
        });
        svc.isVisibleChanged.connect(() => {
            root.isVisible = svc.isVisible;
        });
        svc.nearbyDevicesChanged.connect(() => {
            root.nearbyDevices = svc.nearbyDevices;
        });
        svc.transferHistoryChanged.connect(() => {
            root.transferHistory = svc.transferHistory;
        });

        svc.incomingTransferRequested.connect((deviceName, fileName, fileSize) => {
            console.log("Quick Share: Incoming transfer from " + deviceName + " - " + fileName);
            root.currentDeviceName = deviceName;
            root.currentFileName = fileName;
            let body = qsTr("%1 wants to share %2").arg(deviceName).arg(fileName);
            if (root.currentPinCode)
                body += qsTr("\nPIN: %1").arg(root.currentPinCode);
            root.currentNotification = Notifs.addCustomNotification(
                qsTr("Incoming file"),
                body,
                "",
                [
                    { text: qsTr("Decline"), invoke: () => { if (root._service) root._service.rejectIncomingTransfer(); } },
                    { text: qsTr("Accept"), invoke: () => { if (root._service) root._service.acceptIncomingTransfer(); } }
                ],
                true
            );
        });
        svc.incomingTransferPinReady.connect(pinCode => {
            root.currentPinCode = pinCode;
            if (root.currentNotification) {
                root.currentNotification.body = qsTr("%1 wants to share %2\nPIN: %3").arg(root.currentDeviceName).arg(root.currentFileName).arg(pinCode);
            }
        });
        svc.errorOccurred.connect(message => {
            Toaster.toast(qsTr("Quick Share Error"), message, "error");
        });
        svc.transferFinished.connect((deviceId, success) => {
            if (root.currentNotification) {
                root.currentNotification.close();
                root.currentNotification = null;
            }
            root.currentDeviceName = "";
            root.currentFileName = "";
            root.currentPinCode = "";
        });

        return true;
    }

    function setEnabled(enabled: bool): void {
        if (enabled) {
            if (!root._ensureBackend(true))
                return;
            root._service.isEnabled = true;
        } else if (root._service) {
            root._service.isEnabled = false;
        }
    }

    function setVisible(visible: bool): void {
        if (visible) {
            if (!root._ensureBackend(true))
                return;
            root._service.isVisible = true;
        } else if (root._service) {
            root._service.isVisible = false;
        }
    }

    function sendFile(deviceId: string, filePath: string): void {
        if (!root._ensureBackend(true))
            return;
        root._service.sendFile(deviceId, filePath);
    }

    function acceptIncomingTransfer(): void {
        if (!root._service)
            return;
        root._service.acceptIncomingTransfer();
    }

    function rejectIncomingTransfer(): void {
        if (!root._service)
            return;
        root._service.rejectIncomingTransfer();
    }

    function clearHistory(): void {
        if (!root._service)
            return;
        root._service.clearHistory();
    }

    function removeHistoryEntry(index: int): void {
        if (!root._service)
            return;
        root._service.removeHistoryEntry(index);
    }

    function startBleWakeupBroadcast(): void {
        if (!root._ensureBackend(true))
            return;
        root._service.startBleWakeupBroadcast();
    }

    function stopBleWakeupBroadcast(): void {
        if (!root._service)
            return;
        root._service.stopBleWakeupBroadcast();
    }

    Component.onCompleted: {
        if (GlobalConfig.services.quickShareAutoStart && root._ensureBackend(false)) {
            root.setEnabled(true);
            root.setVisible(true);
        }
    }
}

pragma ComponentBehavior: Bound

import QtQuick
import M3Shapes
import Caelestia.Config
import qs.components
import qs.services

Item {
    id: root

    property var canvas: null
    property bool locked: !Visibilities.desktopWidgetsUnlocked
    property real initialX: 100
    property real initialY: 100
    property bool resizable: false
    property string resizeMode: "discrete" // "discrete" | "horizontal" | "diagonal"
    property string widgetType: ""
    property string sizeMode: "1x1"
    property var supportedSizes: []
    property int outlineShape: -1
    property real widgetScale: WidgetMetrics.scale
    property int minWidth: 60
    property int minHeight: 40
    property int gridSize: 24
    property bool snapToGrid: false
    property bool smartSnap: true
    property bool showSettingsHandle: false
    property bool settingsActive: false

    readonly property bool dragging: dragArea.dragStarted
    property bool resizing: false
    property bool pulsing: false
    property bool lockPulseArmed: false
    property bool nearCenterX: false
    property bool nearCenterY: false

    readonly property real safeLeft: canvas?.safeLeft ?? 0
    readonly property real safeTop: canvas?.safeTop ?? 0
    readonly property real safeRight: canvas?.safeRight ?? (parent ? parent.width : 1920)
    readonly property real safeBottom: canvas?.safeBottom ?? (parent ? parent.height : 1080)
    readonly property real workCenterX: canvas?.workCenterX ?? Math.round((safeLeft + safeRight) / 2)
    readonly property real workCenterY: canvas?.workCenterY ?? Math.round((safeTop + safeBottom) / 2)

    property string previewSizeMode: sizeMode
    property real ghostWidth: width
    property real ghostHeight: height

    signal positionCommitted(int newX, int newY)
    signal widthResized(real newWidth)
    signal sizeResized(real newWidth, real newHeight)
    signal resizeFinished(real finalWidth)
    signal sizeModeCommitted(string newSizeMode)
    signal settingsRequested()
    signal unlockedTapped()

    function clampX(val: real, w: real): real {
        const useW = w > 0 ? w : Math.max(1, width);
        const minX = safeLeft;
        const maxX = Math.max(minX, safeRight - useW);
        return Math.max(minX, Math.min(maxX, val));
    }

    function clampY(val: real, h: real): real {
        const useH = h > 0 ? h : Math.max(1, height);
        const minY = safeTop;
        const maxY = Math.max(minY, safeBottom - useH);
        return Math.max(minY, Math.min(maxY, val));
    }

    function applyConfigPosition(): void {
        if (dragging || resizing)
            return;
        const validBounds = safeRight > safeLeft + 16 && safeBottom > safeTop + 16;
        x = validBounds && width > 0 ? Math.round(clampX(initialX, width)) : Math.round(initialX);
        y = validBounds && height > 0 ? Math.round(clampY(initialY, height)) : Math.round(initialY);
    }

    function applyDragPosition(rawX: real, rawY: real, allowSnap: bool): void {
        let nx = clampX(rawX, width);
        let ny = clampY(rawY, height);
        const tol = WidgetMetrics.snapThreshold;
        const gap = Math.round(WidgetMetrics.baseGap * root.widgetScale);

        let cxActive = false;
        let cyActive = false;
        const guides = [];

        if (allowSnap && root.smartSnap) {
            const siblings = canvas?.siblingRects ? canvas.siblingRects(root) : [];
            const origin = parent ? parent.mapToItem(canvas ?? parent, 0, 0) : Qt.point(0, 0);

            // Center X / Y workspace snap first (most helpful minimal anchor)
            let bestDx = tol + 1;
            let bestAnchorX = nx;
            let xGuide = null;

            const wCenterCand = workCenterX - origin.x - width / 2;
            const dCenterX = Math.abs(nx - wCenterCand);
            if (dCenterX <= tol) {
                bestDx = dCenterX;
                bestAnchorX = wCenterCand;
                cxActive = true;
            }

            // Left / right safe edge soft snap
            const dSafeL = Math.abs(nx - (safeLeft - origin.x));
            if (dSafeL <= tol && dSafeL < bestDx) {
                bestDx = dSafeL;
                bestAnchorX = safeLeft - origin.x;
                cxActive = false;
                xGuide = { orientation: "v", kind: "align", pos: safeLeft, start: safeTop, end: safeBottom };
            }
            const dSafeR = Math.abs(nx - (safeRight - origin.x - width));
            if (dSafeR <= tol && dSafeR < bestDx) {
                bestDx = dSafeR;
                bestAnchorX = safeRight - origin.x - width;
                cxActive = false;
                xGuide = { orientation: "v", kind: "align", pos: safeRight, start: safeTop, end: safeBottom };
            }

            let bestDy = tol + 1;
            let bestAnchorY = ny;
            let yGuide = null;

            const wCenterYCand = workCenterY - origin.y - height / 2;
            const dCenterY = Math.abs(ny - wCenterYCand);
            if (dCenterY <= tol) {
                bestDy = dCenterY;
                bestAnchorY = wCenterYCand;
                cyActive = true;
            }

            const dSafeT = Math.abs(ny - (safeTop - origin.y));
            if (dSafeT <= tol && dSafeT < bestDy) {
                bestDy = dSafeT;
                bestAnchorY = safeTop - origin.y;
                cyActive = false;
                yGuide = { orientation: "h", kind: "align", pos: safeTop, start: safeLeft, end: safeRight };
            }
            const dSafeB = Math.abs(ny - (safeBottom - origin.y - height));
            if (dSafeB <= tol && dSafeB < bestDy) {
                bestDy = dSafeB;
                bestAnchorY = safeBottom - origin.y - height;
                cyActive = false;
                yGuide = { orientation: "h", kind: "align", pos: safeBottom, start: safeLeft, end: safeRight };
            }

            // Sibling alignment (edges, centers, and uniform 12px gap)
            for (let i = 0; i < siblings.length; i++) {
                const s = siblings[i];
                const sx = s.x - origin.x;
                const sy = s.y - origin.y;
                const spanYStart = Math.min(sy, ny);
                const spanYEnd = Math.max(sy + s.height, ny + height);
                const spanXStart = Math.min(sx, nx);
                const spanXEnd = Math.max(sx + s.width, nx + width);

                const xCandidates = [
                    { tx: sx, linePos: s.x, kind: "align" },
                    { tx: sx + s.width - width, linePos: s.x + s.width, kind: "align" },
                    { tx: sx + s.width / 2 - width / 2, linePos: s.x + s.width / 2, kind: "center" },
                    { tx: sx + s.width + gap, linePos: s.y + s.height / 2, kind: "gap", gStart: s.x + s.width, gEnd: s.x + s.width + gap },
                    { tx: sx - width - gap, linePos: s.y + s.height / 2, kind: "gap", gStart: s.x - gap, gEnd: s.x }
                ];
                for (let j = 0; j < xCandidates.length; j++) {
                    const c = xCandidates[j];
                    if (c.kind === "gap" && (ny + height < sy - gap || ny > sy + s.height + gap))
                        continue;
                    const dist = Math.abs(nx - c.tx);
                    if (dist <= tol && dist < bestDx) {
                        bestDx = dist;
                        bestAnchorX = c.tx;
                        cxActive = false;
                        xGuide = c.kind === "gap"
                            ? { orientation: "v", kind: "gap", pos: (Math.max(sy, ny) + Math.min(sy + s.height, ny + height)) / 2, gapStart: c.gStart, gapEnd: c.gEnd }
                            : { orientation: "v", kind: c.kind, pos: c.linePos, start: spanYStart, end: spanYEnd };
                    }
                }

                const yCandidates = [
                    { ty: sy, linePos: s.y, kind: "align" },
                    { ty: sy + s.height - height, linePos: s.y + s.height, kind: "align" },
                    { ty: sy + s.height / 2 - height / 2, linePos: s.y + s.height / 2, kind: "center" },
                    { ty: sy + s.height + gap, linePos: s.x + s.width / 2, kind: "gap", gStart: s.y + s.height, gEnd: s.y + s.height + gap },
                    { ty: sy - height - gap, linePos: s.x + s.width / 2, kind: "gap", gStart: s.y - gap, gEnd: s.y }
                ];
                for (let j = 0; j < yCandidates.length; j++) {
                    const c = yCandidates[j];
                    if (c.kind === "gap" && (nx + width < sx - gap || nx > sx + s.width + gap))
                        continue;
                    const dist = Math.abs(ny - c.ty);
                    if (dist <= tol && dist < bestDy) {
                        bestDy = dist;
                        bestAnchorY = c.ty;
                        cyActive = false;
                        yGuide = c.kind === "gap"
                            ? { orientation: "h", kind: "gap", pos: (Math.max(sx, nx) + Math.min(sx + s.width, nx + width)) / 2, gapStart: c.gStart, gapEnd: c.gEnd }
                            : { orientation: "h", kind: c.kind, pos: c.linePos, start: spanXStart, end: spanXEnd };
                    }
                }
            }

            if (bestDx <= tol)
                nx = clampX(bestAnchorX, width);
            if (bestDy <= tol)
                ny = clampY(bestAnchorY, height);
            if (xGuide)
                guides.push(xGuide);
            if (yGuide)
                guides.push(yGuide);
        }

        x = Math.round(nx);
        y = Math.round(ny);
        nearCenterX = cxActive;
        nearCenterY = cyActive;
        if (canvas?.setCenterActive)
            canvas.setCenterActive(cxActive, cyActive);
        if (canvas?.setGuideLines)
            canvas.setGuideLines(guides);
    }

    onInitialXChanged: applyConfigPosition()
    onInitialYChanged: applyConfigPosition()
    onWidthChanged: if (!dragging && !resizing) applyConfigPosition()
    onHeightChanged: if (!dragging && !resizing) applyConfigPosition()
    onSafeLeftChanged: if (!dragging && !resizing) applyConfigPosition()
    onSafeTopChanged: if (!dragging && !resizing) applyConfigPosition()
    onSafeRightChanged: if (!dragging && !resizing) applyConfigPosition()
    onSafeBottomChanged: if (!dragging && !resizing) applyConfigPosition()

    onLockedChanged: {
        if (locked) {
            resizing = false;
            canvas?.setDragging?.(false);
            canvas?.setResizing?.(false);
            canvas?.setCenterActive?.(false, false);
            canvas?.setGuideLines?.([]);
            lockPulseArmed = false;
            pulsing = false;
        } else {
            lockPulseArmed = true;
            unlockPulseReset.restart();
        }
    }

    Component.onCompleted: {
        applyConfigPosition();
        canvas?.registerItem?.(root);
    }

    Component.onDestruction: {
        canvas?.unregisterItem?.(root);
    }

    z: (dragArea.dragStarted || resizing || settingsActive) ? 45 : (wrapperHover.hovered && !locked ? 15 : 0)
    scale: dragArea.dragStarted ? 1.015 : (pulsing ? 1.015 : 1.0)

    Behavior on scale {
        NumberAnimation {
            duration: Tokens.anim.durations.expressiveFastEffects
            easing: Tokens.anim.expressiveDefaultSpatial
        }
    }

    HoverHandler {
        id: wrapperHover

        enabled: !root.locked
    }

    // Subtle M3 frame highlight when unlocked & hovered or actively adjusted (follows MaterialShape when shaped).
    Rectangle {
        anchors.fill: parent
        z: 18
        visible: root.outlineShape < 0 && !root.locked && (wrapperHover.hovered || root.dragging || root.resizing || root.settingsActive)
        color: "transparent"
        radius: Tokens.rounding.extraLarge
        border.width: (root.dragging || root.resizing || root.settingsActive) ? 2 : 1.5
        border.color: (root.dragging || root.resizing || root.settingsActive)
            ? Colours.palette.m3primary
            : Qt.alpha(Colours.palette.m3primary, 0.55)
        opacity: visible ? 1.0 : 0.0

        Behavior on opacity {
            NumberAnimation {
                duration: Tokens.anim.durations.expressiveFastEffects
            }
        }
    }

    MaterialShape {
        anchors.fill: parent
        z: 18
        visible: root.outlineShape >= 0 && !root.locked && (wrapperHover.hovered || root.dragging || root.resizing || root.settingsActive)
        shape: root.outlineShape >= 0 ? root.outlineShape : MaterialShape.Circle
        color: "transparent"
        strokeWidth: (root.dragging || root.resizing || root.settingsActive) ? 2 : 1.5
        strokeColor: (root.dragging || root.resizing || root.settingsActive)
            ? Colours.palette.m3primary
            : Qt.alpha(Colours.palette.m3primary, 0.55)
        opacity: visible ? 1.0 : 0.0

        Behavior on opacity {
            NumberAnimation {
                duration: Tokens.anim.durations.expressiveFastEffects
            }
        }
    }

    // Live 2D snap ghost preview frame during discrete drag-resizing.
    Rectangle {
        id: ghostPreview

        readonly property bool isDiscrete: root.resizeMode === "discrete" && (root.supportedSizes?.length ?? 0) > 0
        readonly property real targetW: isDiscrete
            ? WidgetMetrics.widthFor(root.previewSizeMode, root.widgetScale)
            : root.ghostWidth
        readonly property real targetH: isDiscrete
            ? WidgetMetrics.heightFor(root.previewSizeMode, root.widgetType, root.widgetScale)
            : root.ghostHeight

        visible: root.resizing
        x: isDiscrete ? Math.max(root.safeLeft - root.x, Math.min(0, root.safeRight - root.x - targetW)) : 0
        y: isDiscrete ? Math.max(root.safeTop - root.y, Math.min(0, root.safeBottom - root.y - targetH)) : 0
        width: targetW
        height: targetH
        z: 35
        radius: Tokens.rounding.extraLarge
        color: Qt.alpha(Colours.palette.m3primary, 0.10)
        border.width: 2
        border.color: Colours.palette.m3primary

        Behavior on width {
            NumberAnimation {
                duration: Tokens.anim.durations.expressiveFastEffects
                easing: Tokens.anim.expressiveDefaultSpatial
            }
        }

        Behavior on height {
            NumberAnimation {
                duration: Tokens.anim.durations.expressiveFastEffects
                easing: Tokens.anim.expressiveDefaultSpatial
            }
        }

        Rectangle {
            anchors.centerIn: parent
            width: Math.max(54, Math.round(ghostBadgeText.implicitWidth + Tokens.padding.medium * 2))
            height: 28
            radius: 14
            color: Colours.palette.m3primaryContainer
            border.width: 1
            border.color: Colours.palette.m3primary

            StyledText {
                id: ghostBadgeText

                anchors.centerIn: parent
                text: ghostPreview.isDiscrete
                    ? WidgetMetrics.formatSizeLabel(root.previewSizeMode)
                    : (Math.round(ghostPreview.targetW) + "×" + Math.round(ghostPreview.targetH))
                font: Tokens.font.label.builders.medium.weight(Font.Bold).build()
                color: Colours.palette.m3onPrimaryContainer
            }
        }
    }

    // Drag, tap-while-unlocked, and right-click quick settings layer when unlocked.
    MouseArea {
        id: dragArea

        property real pressPointerX: 0
        property real pressPointerY: 0
        property real startX: 0
        property real startY: 0
        property real maxMoveDist: 0
        property bool dragStarted: false

        anchors.fill: parent
        z: 20
        enabled: !root.locked
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        preventStealing: true
        cursorShape: dragStarted ? Qt.ClosedHandCursor : Qt.OpenHandCursor

        onPressed: mouse => {
            if (mouse.button === Qt.RightButton) {
                mouse.accepted = true;
                root.settingsRequested();
                return;
            }
            const p = dragArea.mapToItem(root.parent, mouse.x, mouse.y);
            pressPointerX = p.x;
            pressPointerY = p.y;
            startX = root.x;
            startY = root.y;
            maxMoveDist = 0;
            dragStarted = false;
        }

        onPositionChanged: mouse => {
            if (!(mouse.buttons & Qt.LeftButton))
                return;
            const p = dragArea.mapToItem(root.parent, mouse.x, mouse.y);
            const dx = p.x - pressPointerX;
            const dy = p.y - pressPointerY;
            const dist = Math.hypot(dx, dy);
            if (dist > maxMoveDist)
                maxMoveDist = dist;
            if (!dragStarted && dist >= 4) {
                dragStarted = true;
                root.canvas?.setDragging?.(true);
            }
            if (dragStarted) {
                const allowSnap = !(mouse.modifiers & Qt.ShiftModifier);
                root.applyDragPosition(startX + dx, startY + dy, allowSnap);
            }
        }

        onReleased: mouse => {
            if (mouse.button === Qt.RightButton)
                return;
            const wasDragging = dragStarted;
            dragStarted = false;
            root.nearCenterX = false;
            root.nearCenterY = false;
            root.canvas?.setDragging?.(false);
            root.canvas?.setCenterActive?.(false, false);
            root.canvas?.setGuideLines?.([]);

            if (wasDragging)
                root.positionCommitted(Math.round(root.x), Math.round(root.y));
            else if (maxMoveDist < 5)
                root.unlockedTapped();
        }

        onCanceled: {
            dragStarted = false;
            root.nearCenterX = false;
            root.nearCenterY = false;
            root.canvas?.setDragging?.(false);
            root.canvas?.setCenterActive?.(false, false);
            root.canvas?.setGuideLines?.([]);
        }
    }

    // Inset top-right quick settings handle (reveals on hover or while popover is open).
    Rectangle {
        id: settingsHandle

        readonly property bool revealed: !root.locked && root.showSettingsHandle && (wrapperHover.hovered || settingsArea.containsMouse || root.settingsActive)

        z: 30
        width: 28
        height: 28
        radius: 14
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 6
        anchors.rightMargin: 6
        visible: !root.locked && root.showSettingsHandle
        color: (settingsArea.containsMouse || root.settingsActive) ? Colours.palette.m3primary : Colours.palette.m3secondaryContainer
        border.width: 1
        border.color: Colours.palette.m3outlineVariant
        opacity: revealed ? 1.0 : 0.0
        scale: revealed ? 1.0 : 0.7

        Behavior on opacity {
            NumberAnimation {
                duration: Tokens.anim.durations.expressiveFastEffects
            }
        }

        Behavior on scale {
            NumberAnimation {
                duration: Tokens.anim.durations.expressiveFastEffects
                easing: Tokens.anim.expressiveDefaultSpatial
            }
        }

        MaterialIcon {
            anchors.centerIn: parent
            text: "tune"
            fontStyle: Tokens.font.icon.small
            color: (settingsArea.containsMouse || root.settingsActive) ? Colours.palette.m3onPrimary : Colours.palette.m3onSecondaryContainer
        }

        MouseArea {
            id: settingsArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.settingsRequested()
        }
    }

    // Inset bottom-right 2D resize grip handle.
    Rectangle {
        id: resizeHandle

        readonly property bool revealed: !root.locked && root.resizable && (wrapperHover.hovered || resizeArea.containsMouse || root.resizing)

        z: 30
        width: 28
        height: 28
        radius: 14
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        anchors.bottomMargin: 6
        anchors.rightMargin: 6
        visible: !root.locked && root.resizable
        color: (resizeArea.containsMouse || root.resizing) ? Colours.palette.m3primary : WidgetMetrics.innerSurfaceStrong
        border.width: 1
        border.color: Colours.palette.m3outlineVariant
        opacity: revealed ? 1.0 : 0.0
        scale: revealed ? 1.0 : 0.7

        Behavior on opacity {
            NumberAnimation {
                duration: Tokens.anim.durations.expressiveFastEffects
            }
        }

        Behavior on scale {
            NumberAnimation {
                duration: Tokens.anim.durations.expressiveFastEffects
                easing: Tokens.anim.expressiveDefaultSpatial
            }
        }

        MaterialIcon {
            anchors.centerIn: parent
            text: "open_in_full"
            fontStyle: Tokens.font.icon.small
            color: (resizeArea.containsMouse || root.resizing) ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
        }

        MouseArea {
            id: resizeArea

            property real startGlobalX: 0
            property real startGlobalY: 0
            property real startWidth: 0
            property real startHeight: 0

            anchors.fill: parent
            hoverEnabled: true
            preventStealing: true
            cursorShape: root.resizeMode === "horizontal" ? Qt.SizeHorCursor : Qt.SizeFDiagCursor

            onPressed: mouse => {
                mouse.accepted = true;
                const p = resizeArea.mapToItem(root.parent, mouse.x, mouse.y);
                startGlobalX = p.x;
                startGlobalY = p.y;
                startWidth = root.width;
                startHeight = root.height;
                root.previewSizeMode = root.sizeMode;
                root.ghostWidth = root.width;
                root.ghostHeight = root.height;
                root.resizing = true;
                root.canvas?.setResizing?.(true);
            }

            onPositionChanged: mouse => {
                if (!pressed)
                    return;
                const p = resizeArea.mapToItem(root.parent, mouse.x, mouse.y);
                const dx = p.x - startGlobalX;
                const dy = p.y - startGlobalY;
                const origin = root.parent ? root.parent.mapToItem(root.canvas ?? root.parent, 0, 0) : Qt.point(0, 0);
                const maxEdgeW = Math.max(root.minWidth, root.safeRight - (root.x + origin.x));
                const maxEdgeH = Math.max(root.minHeight, root.safeBottom - (root.y + origin.y));
                const totalSafeW = Math.max(root.minWidth, root.safeRight - root.safeLeft);
                const totalSafeH = Math.max(root.minHeight, root.safeBottom - root.safeTop);

                if (root.resizeMode === "discrete" && (root.supportedSizes?.length ?? 0) > 0) {
                    const candW = Math.max(root.minWidth, Math.min(totalSafeW, startWidth + dx));
                    const candH = Math.max(root.minHeight, Math.min(totalSafeH, startHeight + dy));
                    const matched = WidgetMetrics.nearestSizeMode(candW, candH, root.supportedSizes, root.widgetType, root.widgetScale);
                    root.previewSizeMode = matched;
                    root.ghostWidth = WidgetMetrics.widthFor(matched, root.widgetScale);
                    root.ghostHeight = WidgetMetrics.heightFor(matched, root.widgetType, root.widgetScale);
                } else if (root.resizeMode === "diagonal") {
                    const aspect = startHeight > 0 ? (startWidth / startHeight) : 1.0;
                    const rawW = Math.max(root.minWidth, Math.min(maxEdgeW, startWidth + dx));
                    const rawH = Math.max(root.minHeight, Math.min(maxEdgeH, startHeight + dy));
                    const scaleW = rawW / Math.max(1, startWidth);
                    const scaleH = rawH / Math.max(1, startHeight);
                    const chosenScale = Math.abs(dx) >= Math.abs(dy) ? scaleW : scaleH;
                    let candW = Math.max(root.minWidth, Math.min(maxEdgeW, startWidth * chosenScale));
                    let candH = candW / aspect;
                    if (candH > maxEdgeH) {
                        candH = maxEdgeH;
                        candW = candH * aspect;
                    }
                    if (candH < root.minHeight) {
                        candH = root.minHeight;
                        candW = Math.min(maxEdgeW, candH * aspect);
                    }
                    candW = Math.max(root.minWidth, Math.min(maxEdgeW, candW));
                    candH = Math.max(root.minHeight, Math.min(maxEdgeH, candW / aspect));
                    root.ghostWidth = Math.round(candW);
                    root.ghostHeight = Math.round(candH);
                    root.widthResized(root.ghostWidth);
                    root.sizeResized(root.ghostWidth, root.ghostHeight);
                } else {
                    const candW = Math.max(root.minWidth, Math.min(maxEdgeW, startWidth + dx));
                    const candH = root.resizeMode === "horizontal"
                        ? startHeight
                        : Math.max(root.minHeight, Math.min(maxEdgeH, startHeight + dy));
                    root.ghostWidth = Math.round(candW);
                    root.ghostHeight = Math.round(candH);
                    root.widthResized(root.ghostWidth);
                    root.sizeResized(root.ghostWidth, root.ghostHeight);
                }
            }

            onReleased: {
                if (!root.resizing)
                    return;
                root.resizing = false;
                root.canvas?.setResizing?.(false);
                if (root.resizeMode === "discrete" && (root.supportedSizes?.length ?? 0) > 0) {
                    const target = root.previewSizeMode;
                    root.sizeModeCommitted(target);
                } else {
                    root.resizeFinished(Math.round(root.ghostWidth));
                }
            }

            onCanceled: {
                root.resizing = false;
                root.canvas?.setResizing?.(false);
            }
        }
    }

    Timer {
        id: unlockPulseReset

        interval: Tokens.anim.durations.expressiveFastEffects
        onTriggered: {
            if (root.lockPulseArmed) {
                root.pulsing = true;
                pulseHold.restart();
            }
        }
    }

    Timer {
        id: pulseHold

        interval: Tokens.anim.durations.expressiveFastEffects
        onTriggered: root.pulsing = false
    }
}

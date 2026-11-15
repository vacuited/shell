.pragma library

var baseCell = 164;
var baseGap = 12;
var unit = baseCell + baseGap;
var cardCells = 1;

function canonicalType(entry) {
    if (!entry)
        return "";
    var raw = (entry.type && entry.type !== "") ? entry.type : entry.id;
    return raw === "pomodoro" ? "timers" : (raw || "");
}

function defaultSizeMode(type) {
    switch (type) {
    case "atAGlance":
    case "media":
    case "usercard":
        return "1x2";
    case "resources":
    case "todo":
    case "notes":
        return "2x1";
    default:
        return "1x1";
    }
}

function colsFor(type, sizeMode) {
    var m = (sizeMode && sizeMode !== "") ? sizeMode : defaultSizeMode(type);
    var parts = m.split("x");
    var c = parseInt(parts[1], 10);
    if (isNaN(c) || c < 1)
        return 1;
    return Math.min(3, c);
}

function rowsFor(type, sizeMode) {
    var m = (sizeMode && sizeMode !== "") ? sizeMode : defaultSizeMode(type);
    var parts = m.split("x");
    var r = parseInt(parts[0], 10);
    if (isNaN(r) || r < 1)
        return 1;
    return Math.min(2, r);
}

function hits(occ, col, row, w, h, totalCols) {
    if (col < 0 || row < 0 || col + w > totalCols)
        return true;
    for (var i = 0; i < occ.length; i++) {
        var b = occ[i];
        if (col < b.col + b.w && col + w > b.col && row < b.row + b.h && row + h > b.row)
            return true;
    }
    return false;
}

function findSlot(occ, w, h, colLimit, totalCols, totalRows, anchorCorner) {
    var rightAnchor = anchorCorner === "top-right" || anchorCorner === "bottom-right";
    var bottomAnchor = anchorCorner === "bottom-left" || anchorCorner === "bottom-right";

    var maxCol = Math.min(totalCols, Math.max(w, colLimit));
    var startCol = rightAnchor ? Math.max(0, totalCols - maxCol) : 0;
    var endCol = Math.min(totalCols - w, startCol + maxCol - w);
    var maxRow = Math.max(1, totalRows - h + 1);

    for (var rStep = 0; rStep < maxRow; rStep++) {
        var row = bottomAnchor ? Math.max(0, totalRows - h - rStep) : rStep;
        for (var cStep = 0; cStep <= endCol - startCol; cStep++) {
            var col = rightAnchor ? (endCol - cStep) : (startCol + cStep);
            if (!hits(occ, col, row, w, h, totalCols))
                return { col: col, row: row };
        }
    }

    // Fallback scan across full workspace if constrained column limit was full.
    for (var r = 0; r < Math.max(1, totalRows - h + 1); r++) {
        for (var c = 0; c <= Math.max(0, totalCols - w); c++) {
            if (!hits(occ, c, r, w, h, totalCols))
                return { col: c, row: r };
        }
    }
    return { col: rightAnchor ? Math.max(0, totalCols - w) : 0, row: 0 };
}

function place(entries, workWidth, workHeight, columnsSetting, anchorCorner, stepPx, cellPx, gapPx, originX, originY) {
    var step = stepPx > 0 ? stepPx : unit;
    var cell = cellPx > 0 ? cellPx : baseCell;
    var gap = gapPx >= 0 ? gapPx : baseGap;
    var ox = originX || 0;
    var oy = originY || 0;

    var totalCols = Math.max(1, Math.floor((Math.max(cell, workWidth) + gap) / step));
    var totalRows = Math.max(1, Math.floor((Math.max(cell, workHeight) + gap) / step));
    var colLimit = Math.max(1, Math.min(totalCols, columnsSetting || 2));

    var occ = [];
    var slots = {};
    var i;

    // Reserve cells already occupied by custom-positioned widgets.
    for (i = 0; i < entries.length; i++) {
        var entry = entries[i];
        if (!entry || entry.enabled === false)
            continue;
        var wType = canonicalType(entry);
        var mode = (entry.sizeMode && entry.sizeMode !== "") ? entry.sizeMode : defaultSizeMode(wType);
        var w = colsFor(wType, mode);
        var h = rowsFor(wType, mode);
        if (entry.x !== undefined && entry.x >= 0 && entry.y !== undefined && entry.y >= 0) {
            var relX = entry.x - ox;
            var relY = entry.y - oy;
            var c = Math.max(0, Math.min(totalCols - w, Math.round(relX / step)));
            var r = Math.max(0, Math.min(totalRows - h, Math.round(relY / step)));
            occ.push({ col: c, row: r, w: w, h: h });
            slots[entry.id] = {
                col: c,
                row: r,
                w: w,
                h: h,
                x: Math.round(entry.x),
                y: Math.round(entry.y)
            };
        }
    }

    // Auto-flow remaining unplaced entries into nearest open slots.
    for (i = 0; i < entries.length; i++) {
        var e = entries[i];
        if (!e || e.enabled === false || slots[e.id])
            continue;
        var t = canonicalType(e);
        var sz = (e.sizeMode && e.sizeMode !== "") ? e.sizeMode : defaultSizeMode(t);
        var cw = colsFor(t, sz);
        var ch = rowsFor(t, sz);
        var pos = findSlot(occ, cw, ch, colLimit, totalCols, totalRows, anchorCorner || "top-right");
        occ.push({ col: pos.col, row: pos.row, w: cw, h: ch });
        slots[e.id] = {
            col: pos.col,
            row: pos.row,
            w: cw,
            h: ch,
            x: Math.round(ox + pos.col * step),
            y: Math.round(oy + pos.row * step)
        };
    }

    return slots;
}

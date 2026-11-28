.pragma library

// Angles are measured counterclockwise from the primary horizontal axis of the dial.
var BUILTIN_META = {
    lock: {
        title: "Lock",
        icon: "lock",
        shape: "Gem",
        dangerous: false,
        description: "Locks the current session and requires\nauthentication to resume."
    },
    logout: {
        title: "Logout",
        icon: "logout",
        shape: "Cookie6Sided",
        dangerous: false,
        description: "Ends your current session and closes\nall open applications."
    },
    shutdown: {
        title: "Poweroff",
        icon: "power_settings_new",
        shape: "SoftBurst",
        dangerous: true,
        description: "Closes open applications and safely\npowers off the system."
    },
    hibernate: {
        title: "Hibernate",
        icon: "bedtime",
        shape: "Clover4Leaf",
        dangerous: false,
        description: "Saves your current memory state to disk\nand powers down."
    },
    suspend: {
        title: "Suspend",
        icon: "dark_mode",
        shape: "Cookie7Sided",
        dangerous: false,
        description: "Suspends the system to RAM for quick\nresume with low power usage."
    },
    reboot: {
        title: "Reboot",
        icon: "restart_alt",
        shape: "Sunny",
        dangerous: false,
        description: "Cleanly restarts all services and\nreboots the system."
    }
};

var actions = [
    {
        id: "logout",
        title: BUILTIN_META.logout.title,
        icon: BUILTIN_META.logout.icon,
        shape: BUILTIN_META.logout.shape,
        angle: 75,
        dangerous: false,
        confirmable: false,
        description: BUILTIN_META.logout.description,
        command: ["logout"]
    },
    {
        id: "shutdown",
        title: BUILTIN_META.shutdown.title,
        icon: BUILTIN_META.shutdown.icon,
        shape: BUILTIN_META.shutdown.shape,
        angle: 55,
        dangerous: true,
        confirmable: true,
        description: BUILTIN_META.shutdown.description,
        command: ["poweroff"]
    },
    {
        id: "hibernate",
        title: BUILTIN_META.hibernate.title,
        icon: BUILTIN_META.hibernate.icon,
        shape: BUILTIN_META.hibernate.shape,
        angle: 32,
        dangerous: false,
        confirmable: false,
        description: BUILTIN_META.hibernate.description,
        command: ["hibernate"]
    },
    {
        id: "reboot",
        title: BUILTIN_META.reboot.title,
        icon: BUILTIN_META.reboot.icon,
        shape: BUILTIN_META.reboot.shape,
        angle: 9,
        dangerous: false,
        confirmable: true,
        description: BUILTIN_META.reboot.description,
        command: ["reboot"]
    }
];

function formatTitle(key) {
    if (!key)
        return "Action";
    var words = String(key)
        .replace(/([a-z0-9])([A-Z])/g, "$1 $2")
        .replace(/[_-]+/g, " ")
        .trim()
        .split(/\s+/);
    for (var i = 0; i < words.length; ++i) {
        var w = words[i];
        if (w.length > 0)
            words[i] = w.charAt(0).toUpperCase() + w.slice(1);
    }
    return words.join(" ") || "Action";
}

function buildActions(configButtons) {
    if (!configButtons || configButtons.length === 0)
        return actions;

    var count = configButtons.length;
    var defaultAngles = [75, 55, 32, 9];
    var customShapes = ["Cookie9Sided", "Puffy", "Pentagon", "ClamShell", "Cookie6Sided"];
    var built = [];

    for (var i = 0; i < count; ++i) {
        var btn = configButtons[i];
        if (!btn)
            continue;
        var key = String(btn.key || ("action" + i));
        var meta = BUILTIN_META[key] || null;
        var angle;
        if (count === 4) {
            angle = defaultAngles[i];
        } else if (count === 1) {
            angle = 45;
        } else {
            angle = 78 - i * (70 / (count - 1));
        }
        built.push({
            id: key,
            title: meta ? meta.title : formatTitle(key),
            icon: (btn.icon && String(btn.icon).trim() !== "") ? String(btn.icon) : (meta ? meta.icon : "terminal"),
            shape: meta ? meta.shape : customShapes[i % customShapes.length],
            angle: angle,
            dangerous: key === "shutdown",
            confirmable: key === "shutdown" || key === "reboot",
            description: meta ? meta.description : "Runs the configured session action.",
            command: btn.command ? btn.command : [key]
        });
    }

    return built.length > 0 ? built : actions;
}

function angleAt(x, y) {
    return Math.atan2(-y, x) * 180 / Math.PI;
}

function selectionAt(x, y, scale, actionsList) {
    if (!(scale > 0))
        return -1;
    var list = (actionsList && actionsList.length > 0) ? actionsList : actions;
    var radius = Math.sqrt(x * x + y * y) / scale;
    if (radius < 64)
        return -1;
    var angle = angleAt(x, y);
    if (angle < 0 || angle > 90)
        return -1;
    var nearest = -1;
    var distance = Infinity;
    for (var i = 0; i < list.length; ++i) {
        var d = Math.abs(angle - list[i].angle);
        if (d < distance) {
            nearest = i;
            distance = d;
        }
    }
    return nearest;
}

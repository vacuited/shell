#pragma once

#include <qstring.h>

#include "settings/objectnode.hpp"
#include "common.hpp"
#include "enums.hpp"

namespace caelestia::shell::config {

using Qt::StringLiterals::operator""_s;

class DesktopClockBackground : public settings::ObjectNode {
    CONFIG_NODE(DesktopClockBackground, settings::ObjectNode)

    CONFIG_PROPERTY(bool, enabled, false)
    CONFIG_PROPERTY(qreal, opacity, 0.7)
    CONFIG_PROPERTY(bool, blur, true)
};

class DesktopClockShadow : public settings::ObjectNode {
    CONFIG_NODE(DesktopClockShadow, settings::ObjectNode)

    CONFIG_PROPERTY(bool, enabled, true)
    CONFIG_PROPERTY(qreal, opacity, 0.7)
    CONFIG_PROPERTY(qreal, blur, 0.4)
};

class DesktopClock : public settings::ObjectNode {
    CONFIG_NODE(DesktopClock, settings::ObjectNode)

    CONFIG_PROPERTY(bool, enabled, false)
    CONFIG_PROPERTY(qreal, scale, 1.0)
    CONFIG_PROPERTY(QString, position, u"bottom-right"_s)
    CONFIG_PROPERTY(QString, style, u"classic"_s)
    CONFIG_PROPERTY(QString, surfaceStyle, u"glass"_s)
    CONFIG_PROPERTY(int, x, -1)
    CONFIG_PROPERTY(int, y, -1)
    CONFIG_PROPERTY(QVariantMap, options, {})
    CONFIG_PROPERTY(bool, invertColors, false)
    CONFIG_SUBOBJECT(DesktopClockBackground, background)
    CONFIG_SUBOBJECT(DesktopClockShadow, shadow)
};

class BackgroundVisualiser : public settings::ObjectNode {
    CONFIG_NODE(BackgroundVisualiser, settings::ObjectNode)

    CONFIG_PROPERTY(bool, enabled, false)
    CONFIG_PROPERTY(bool, autoHide, true)
    CONFIG_PROPERTY(bool, blur, false)
    CONFIG_PROPERTY(QString, renderer, u"gpu"_s)
    CONFIG_PROPERTY(QString, style, u"aurora"_s)
    CONFIG_PROPERTY(QString, position, u"bottom"_s)
    CONFIG_PROPERTY(QString, layout, u"split"_s)
    CONFIG_PROPERTY(bool, mirrored, false)
    CONFIG_PROPERTY(qreal, heightScale, 0.40)
    CONFIG_PROPERTY(qreal, opacity, 0.75)
    CONFIG_PROPERTY(qreal, rounding, 1)
    CONFIG_PROPERTY(qreal, spacing, 1)
    CONFIG_PROPERTY(QString, gradientMode, u"tritone"_s)
    CONFIG_PROPERTY(QString, primaryColorRole, u"primary"_s)
    CONFIG_PROPERTY(QString, secondaryColorRole, u"inversePrimary"_s)
    CONFIG_PROPERTY(QString, accentColorRole, u"tertiary"_s)
    CONFIG_PROPERTY(qreal, glow, 0.35)
    CONFIG_PROPERTY(qreal, sensitivity, 1.0)
    CONFIG_PROPERTY(int, attackMs, 45)
    CONFIG_PROPERTY(int, decayMs, 220)
    CONFIG_PROPERTY(qreal, beatReactivity, 0.50)
    CONFIG_PROPERTY(bool, monstercat, true)
    CONFIG_PROPERTY(QString, idleMode, u"ambient"_s)
    CONFIG_PROPERTY(qreal, idleTimeout, 3.0)
    CONFIG_PROPERTY(QVariantMap, options, {})
};

class DesktopLyricsBackground : public settings::ObjectNode {
    CONFIG_NODE(DesktopLyricsBackground, settings::ObjectNode)

    CONFIG_PROPERTY(bool, enabled, false)
    CONFIG_PROPERTY(qreal, opacity, 0.7)
    CONFIG_PROPERTY(bool, blur, true)
};

class DesktopLyricsShadow : public settings::ObjectNode {
    CONFIG_NODE(DesktopLyricsShadow, settings::ObjectNode)

    CONFIG_PROPERTY(bool, enabled, true)
    CONFIG_PROPERTY(qreal, opacity, 0.7)
    CONFIG_PROPERTY(qreal, blur, 0.4)
};

class DesktopLyrics : public settings::ObjectNode {
    CONFIG_NODE(DesktopLyrics, settings::ObjectNode)

    CONFIG_PROPERTY(bool, enabled, false)
    CONFIG_PROPERTY(bool, overlay, false)
    CONFIG_PROPERTY(bool, autoHideFullscreen, true)
    CONFIG_PROPERTY(bool, autoHideTiled, true)
    CONFIG_PROPERTY(qreal, scale, 1.0)
    CONFIG_PROPERTY(QString, position, u"bottom-center"_s)
    CONFIG_PROPERTY(QString, style, u"apple"_s)
    CONFIG_PROPERTY(QString, surfaceStyle, u"glass"_s)
    CONFIG_PROPERTY(int, x, -1)
    CONFIG_PROPERTY(int, y, -1)
    CONFIG_PROPERTY(int, width, 480)
    CONFIG_PROPERTY(int, alignment, 1)
    CONFIG_PROPERTY(bool, invertColors, false)
    CONFIG_PROPERTY(QVariantMap, options, {})
    CONFIG_SUBOBJECT(DesktopLyricsBackground, background)
    CONFIG_SUBOBJECT(DesktopLyricsShadow, shadow)
};

class DesktopWidgetEntry : public settings::ObjectNode {
    CONFIG_NODE(DesktopWidgetEntry, settings::ObjectNode)

    CONFIG_PROPERTY(QString, id, {})
    CONFIG_PROPERTY(QString, type, {})
    CONFIG_PROPERTY(bool, enabled, true)
    CONFIG_PROPERTY(int, col, -1)
    CONFIG_PROPERTY(int, row, -1)
    CONFIG_PROPERTY(bool, right, false)
    CONFIG_PROPERTY(int, x, -1)
    CONFIG_PROPERTY(int, y, -1)
    CONFIG_PROPERTY(QString, style, {})
    CONFIG_PROPERTY(QString, sizeMode, {})
    CONFIG_PROPERTY(QVariantMap, options, {})
};
CONFIG_LIST_TYPE(DesktopWidgetEntry, DesktopWidgetList)

class DesktopWidgets : public settings::ObjectNode {
    CONFIG_NODE(DesktopWidgets, settings::ObjectNode)

    CONFIG_PROPERTY(bool, enabled, false)
    CONFIG_PROPERTY(QString, position, u"top-right"_s)
    CONFIG_PROPERTY(int, columns, 2)
    CONFIG_LIST(DesktopWidgetList, entries,
        DEFAULT_ARG({
            LIST_ENTRY(weather, true),
            LIST_ENTRY(pomodoro, true),
            LIST_ENTRY(calendar, true),
            LIST_ENTRY(resources, false),
            LIST_ENTRY(media, false),
            LIST_ENTRY(battery, false),
        }))
    CONFIG_PROPERTY(bool, hideWithWindows, true)
    CONFIG_PROPERTY(QString, surfaceStyle, u"glass"_s)
    CONFIG_PROPERTY(qreal, opacity, 0.7)
    CONFIG_PROPERTY(bool, blur, true)
    CONFIG_PROPERTY(qreal, scale, 1.0)
};

class BackgroundConfig : public settings::ObjectNode {
    CONFIG_NODE(BackgroundConfig, settings::ObjectNode)

    CONFIG_PROPERTY(bool, enabled, true)
    CONFIG_PROPERTY(bool, wallpaperEnabled, true)
    CONFIG_PROPERTY(bool, wallpaperRecolor, false)
    CONFIG_PROPERTY(qreal, wallpaperRecolorStrength, 0.5)
    CONFIG_PROPERTY(bool, videoWallpaperPaused, false)
    CONFIG_PROPERTY(bool, videoWallpaperSoundEnabled, false)
    CONFIG_PROPERTY(bool, videoWallpaperPauseOnFullscreen, false)
    CONFIG_PROPERTY(bool, videoWallpaperPauseOnTiled, false)
    CONFIG_PROPERTY(bool, videoWallpaperPauseOnAllDisplays, false)
    CONFIG_PROPERTY(bool, videoWallpaperMuteOnMedia, false)
    CONFIG_ENUM_PROPERTY(WallpaperTransition, wallpaperTransition, WallpaperTransition::Crossfade)
    CONFIG_SUBOBJECT(DesktopClock, desktopClock)
    CONFIG_SUBOBJECT(DesktopLyrics, desktopLyrics)
    CONFIG_SUBOBJECT(DesktopWidgets, desktopWidgets)
    CONFIG_SUBOBJECT(BackgroundVisualiser, visualiser)
};

} // namespace caelestia::shell::config

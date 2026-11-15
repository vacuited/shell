#pragma once

#include "settings/objectnode.hpp"
#include "common.hpp"

namespace caelestia::shell::config {

using Qt::StringLiterals::operator""_s;

class NotchConfig : public settings::ObjectNode {
    CONFIG_NODE(NotchConfig, settings::ObjectNode)

    CONFIG_PROPERTY(bool, enabled, true)
    // Duration (ms) the transient pill stays up on track change or Pomodoro phase change
    CONFIG_PROPERTY(int, showDuration, 4000)
    CONFIG_PROPERTY(int, maxTitleWidth, 260)
    CONFIG_PROPERTY(bool, showArtist, true)
    CONFIG_PROPERTY(bool, artistFirst, true)
    // Standing notch visibility
    CONFIG_PROPERTY(bool, showOnEmptyWorkspace, true)
    CONFIG_PROPERTY(bool, showWithWindows, true)
    CONFIG_PROPERTY(bool, alwaysCompact, false)
    CONFIG_PROPERTY(bool, compactWithWindows, true)
    // Standing notch sections
    CONFIG_PROPERTY(bool, showClock, false)
    CONFIG_PROPERTY(bool, showMusic, true)
    CONFIG_PROPERTY(bool, showFocus, true)
    // Quick controls drawer ("hover", "click", "none")
    CONFIG_PROPERTY(QString, expandMode, u"hover"_s)
    CONFIG_PROPERTY(bool, showMediaControls, true)
    CONFIG_PROPERTY(bool, showFocusControls, true)
    // Dynamic Island live activities & interactions
    CONFIG_PROPERTY(bool, showNotifications, false)
    CONFIG_PROPERTY(bool, notifReplies, false)
    CONFIG_PROPERTY(bool, showOsd, false)
    CONFIG_PROPERTY(bool, showRecording, false)
    CONFIG_PROPERTY(bool, showCharging, false)
    CONFIG_PROPERTY(bool, showToasts, false)
    CONFIG_PROPERTY(bool, showBubble, false)
    CONFIG_PROPERTY(bool, scrollToCycle, false)
    CONFIG_PROPERTY(int, osdDuration, 1800)
    CONFIG_PROPERTY(int, chargingDuration, 3000)
};

} // namespace caelestia::shell::config

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
};

} // namespace caelestia::shell::config

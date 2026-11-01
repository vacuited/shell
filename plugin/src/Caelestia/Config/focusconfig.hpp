#pragma once

#include "settings/objectnode.hpp"
#include "common.hpp"

namespace caelestia::shell::config {

class FocusConfig : public settings::ObjectNode {
    CONFIG_NODE(FocusConfig, settings::ObjectNode)

    CONFIG_GLOBAL_PROPERTY(int, focusMins, 25)
    CONFIG_GLOBAL_PROPERTY(int, shortBreakMins, 5)
    CONFIG_GLOBAL_PROPERTY(int, longBreakMins, 15)
    CONFIG_GLOBAL_PROPERTY(int, cyclesBeforeLongBreak, 4)
    CONFIG_GLOBAL_PROPERTY(bool, autoPlay, true)
    CONFIG_GLOBAL_PROPERTY(bool, autoDnd, true)
    CONFIG_GLOBAL_PROPERTY(bool, chime, true)
    CONFIG_GLOBAL_PROPERTY(QString, focusEndSound, QStringLiteral("Iapetus.wav"))
    CONFIG_GLOBAL_PROPERTY(QString, breakEndSound, QStringLiteral("Tinkerbell.wav"))
    CONFIG_GLOBAL_PROPERTY(int, dailyGoalMins, 240)
    CONFIG_GLOBAL_PROPERTY(int, streakThresholdMins, 30)
    CONFIG_GLOBAL_PROPERTY(QStringList, subjects, {})
};

} // namespace caelestia::shell::config

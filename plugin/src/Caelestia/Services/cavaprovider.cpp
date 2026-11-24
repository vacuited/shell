#include "cavaprovider.hpp"

#include <qloggingcategory.h>

#include <cava/cavacore.h>

#include <algorithm>
#include <cmath>
#include <cstddef>

#include "audiocollector.hpp"
#include "audioprovider.hpp"

namespace {

Q_LOGGING_CATEGORY(lcCava, "caelestia.services.cava", QtInfoMsg)
Q_LOGGING_CATEGORY(lcCavaProcessor, "caelestia.services.cava.processor", QtInfoMsg)

} // namespace

namespace caelestia::shell::services {

CavaProcessor::CavaProcessor(QObject* parent)
    : AudioProcessor(parent)
    , m_plan(nullptr)
    , m_in(new double[ac::k_chunkSize])
    , m_out(nullptr)
    , m_bars(0) {};

CavaProcessor::~CavaProcessor() {
    cleanup();
    delete[] m_in;
}

void CavaProcessor::process() {
    if (!m_plan || m_bars == 0 || !m_out) {
        return;
    }

    const int count = static_cast<int>(AudioCollector::instance().readChunk(m_in));

    bool inputSilent = true;
    for (int i = 0; i < count; ++i) {
        if (std::abs(m_in[i]) > 1e-6) {
            inputSilent = false;
            break;
        }
    }
    if (inputSilent && m_allZero) {
        return;
    }

    // Process in data via cava
    cava_execute(m_in, count, m_out, m_plan);

    // Apply optional monstercat spatial filter
    QVector<double> values(m_bars);

    if (m_monstercat.load(std::memory_order_relaxed)) {
        // Left to right pass
        const double inv = 1.0 / 1.5;
        double carry = 0.0;
        for (int i = 0; i < m_bars; ++i) {
            carry = std::max(m_out[i], carry * inv);
            values[i] = carry;
        }

        // Right to left pass and combine
        carry = 0.0;
        for (int i = m_bars - 1; i >= 0; --i) {
            carry = std::max(m_out[i], carry * inv);
            values[i] = std::max(values[i], carry);
        }
    } else {
        for (int i = 0; i < m_bars; ++i) {
            values[i] = m_out[i];
        }
    }

    bool allZero = true;
    bool changed = (values.size() != m_values.size());
    for (int i = 0; i < m_bars; ++i) {
        if (values[i] < 0.0005) {
            values[i] = 0.0;
        } else {
            allZero = false;
        }
        if (!changed && std::abs(values[i] - m_values[i]) > 0.0005) {
            changed = true;
        }
    }
    if (allZero && !m_allZero) {
        changed = true;
    }
    m_allZero = allZero;

    // Update values
    if (changed) {
        m_values = std::move(values);
        emit valuesChanged(m_values);
    }
}

void CavaProcessor::setBars(int bars) {
    if (bars < 0 || bars > 256) {
        qCWarning(lcCavaProcessor) << "setBars: bars must be between 0 and 256. Clamping.";
        bars = std::clamp(bars, 0, 256);
    }

    if (m_bars != bars) {
        m_bars = bars;
        reload();
    }
}

void CavaProcessor::setMonstercat(bool monstercat) {
    m_monstercat.store(monstercat, std::memory_order_relaxed);
}

void CavaProcessor::reload() {
    m_allZero = false;
    m_values.clear();
    cleanup();
    initCava();
}

void CavaProcessor::cleanup() {
    if (m_plan) {
        cava_destroy(m_plan);
        m_plan = nullptr;
    }

    if (m_out) {
        delete[] m_out;
        m_out = nullptr;
    }
}

void CavaProcessor::initCava() {
    if (m_plan || m_bars == 0) {
        return;
    }

    m_plan = cava_init(m_bars, ac::k_sampleRate, 1, 1, 0.78, 50, 10000);
    m_out = new double[static_cast<size_t>(m_bars)];
}

CavaProvider::CavaProvider(QObject* parent)
    : AudioProvider(parent)
    , m_bars(0)
    , m_values(m_bars, 0.0) {
    m_processor = new CavaProcessor();
    init();

    connect(static_cast<CavaProcessor*>(m_processor), &CavaProcessor::valuesChanged, this, &CavaProvider::updateValues);
}

int CavaProvider::bars() const {
    return m_bars;
}

void CavaProvider::setBars(int bars) {
    if (bars < 0 || bars > 256) {
        qCWarning(lcCava) << "setBars: bars must be between 0 and 256. Clamping.";
        bars = std::clamp(bars, 0, 256);
    }

    if (m_bars == bars) {
        return;
    }

    m_values.resize(bars, 0.0);
    m_bars = bars;
    emit barsChanged();
    emit valuesChanged();

    QMetaObject::invokeMethod(
        static_cast<CavaProcessor*>(m_processor), &CavaProcessor::setBars, Qt::QueuedConnection, bars);
}

bool CavaProvider::monstercat() const {
    return m_monstercat;
}

void CavaProvider::setMonstercat(bool monstercat) {
    if (m_monstercat == monstercat) {
        return;
    }

    m_monstercat = monstercat;
    emit monstercatChanged();

    static_cast<CavaProcessor*>(m_processor)->setMonstercat(monstercat);
}

QVector<double> CavaProvider::values() const {
    return m_values;
}

void CavaProvider::updateValues(const QVector<double>& values) {
    if (values.size() != m_bars) {
        return;
    }
    if (values != m_values) {
        m_values = values;
        emit valuesChanged();
    }
}

} // namespace caelestia::shell::services

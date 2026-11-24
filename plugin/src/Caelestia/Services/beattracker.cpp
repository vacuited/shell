#include "beattracker.hpp"

#include <cmath>

#include "audiocollector.hpp"
#include "audioprovider.hpp"

namespace caelestia::shell::services {

BeatProcessor::BeatProcessor(QObject* parent)
    : AudioProcessor(parent)
    , m_tempo(new_aubio_tempo("default", 1024, ac::k_chunkSize, ac::k_sampleRate))
    , m_in(new_fvec(ac::k_chunkSize))
    , m_out(new_fvec(2)) {};

BeatProcessor::~BeatProcessor() {
    if (m_tempo) {
        del_aubio_tempo(m_tempo);
    }
    if (m_in) {
        del_fvec(m_in);
    }
    if (m_out) {
        del_fvec(m_out);
    }
}

void BeatProcessor::process() {
    if (!m_tempo || !m_in) {
        return;
    }

    const quint32 count = AudioCollector::instance().readChunk(m_in->data);

    bool silent = true;
    for (quint32 i = 0; i < count; ++i) {
        if (std::abs(m_in->data[i]) > 1e-6f) {
            silent = false;
            break;
        }
    }
    if (silent) {
        if (m_silentChunks >= 4) {
            return;
        }
        ++m_silentChunks;
    } else {
        m_silentChunks = 0;
    }

    aubio_tempo_do(m_tempo, m_in, m_out);
    if (!qFuzzyIsNull(m_out->data[0])) {
        emit beat(aubio_tempo_get_bpm(m_tempo));
    }
}

BeatTracker::BeatTracker(QObject* parent)
    : AudioProvider(parent)
    , m_bpm(120) {
    m_processor = new BeatProcessor();
    init();

    connect(static_cast<BeatProcessor*>(m_processor), &BeatProcessor::beat, this, &BeatTracker::updateBpm);
}

smpl_t BeatTracker::bpm() const {
    return m_bpm;
}

void BeatTracker::updateBpm(smpl_t bpm) {
    if (!qFuzzyCompare(bpm + 1.0f, m_bpm + 1.0f)) {
        m_bpm = bpm;
        emit bpmChanged();
    }
    emit beat(bpm);
}

} // namespace caelestia::shell::services

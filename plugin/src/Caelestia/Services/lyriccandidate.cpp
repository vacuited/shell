#include "lyriccandidate.hpp"

namespace caelestia::shell::services {

LyricCandidate::LyricCandidate(LyricsBackend backend, QString id, QString title, QString artist, QString album,
    qreal duration, QString syncType, bool hasTranslation, bool hasRomanization, QString providerDetail)
    : m_backend(backend)
    , m_id(std::move(id))
    , m_title(std::move(title))
    , m_artist(std::move(artist))
    , m_album(std::move(album))
    , m_duration(duration)
    , m_syncType(syncType.isEmpty() ? QStringLiteral("line") : std::move(syncType))
    , m_hasTranslation(hasTranslation)
    , m_hasRomanization(hasRomanization)
    , m_providerDetail(std::move(providerDetail)) {}

LyricsBackend LyricCandidate::backend() const {
    return m_backend;
}

QString LyricCandidate::id() const {
    return m_id;
}

QString LyricCandidate::title() const {
    return m_title;
}

QString LyricCandidate::artist() const {
    return m_artist;
}

QString LyricCandidate::album() const {
    return m_album;
}

qreal LyricCandidate::duration() const {
    return m_duration;
}

QString LyricCandidate::syncType() const {
    return m_syncType;
}

bool LyricCandidate::hasTranslation() const {
    return m_hasTranslation;
}

bool LyricCandidate::hasRomanization() const {
    return m_hasRomanization;
}

QString LyricCandidate::providerDetail() const {
    return m_providerDetail;
}

bool LyricCandidate::isValid() const {
    return !m_id.isEmpty();
}

bool LyricCandidate::operator==(const LyricCandidate& o) const noexcept {
    return m_backend == o.m_backend && m_id == o.m_id;
}

bool LyricCandidate::operator!=(const LyricCandidate& o) const noexcept {
    return !(*this == o);
}

} // namespace caelestia::shell::services

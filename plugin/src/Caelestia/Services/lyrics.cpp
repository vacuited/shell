#include "lyrics.hpp"

#include <qdir.h>
#include <qdiriterator.h>
#include <qfileinfo.h>
#include <qjsonarray.h>
#include <qjsondocument.h>
#include <qregularexpression.h>
#include <qsavefile.h>
#include <qurlquery.h>
#include <qxmlstream.h>

#include <algorithm>
#include <cmath>
#include <limits>

#include "config/rootnodes.hpp"
#include "config/serviceconfig.hpp"
#include "config/userpaths.hpp"

namespace {

Q_LOGGING_CATEGORY(lcLyrics, "caelestia.lyrics", QtInfoMsg)

} // namespace

namespace caelestia::shell::services {

using Qt::StringLiterals::operator""_s;
using Qt::StringLiterals::operator""_ba;

namespace {

constexpr int k_loadDebounceMs = 50;
constexpr int k_autoGraceMs = 900;
constexpr int k_transferTimeoutMs = 8000;
constexpr qreal k_indexFudge = 0.1;
constexpr qreal k_minGapSeconds = 3.5;

[[nodiscard]] const QHash<QByteArray, QByteArray>& netEaseHeaders() {
    static const QHash<QByteArray, QByteArray> k_h = {
        { "User-Agent"_ba, "Mozilla/5.0 (X11; Linux x86_64; rv:120.0) Gecko/20100101 Firefox/120.0"_ba },
        { "Referer"_ba, "https://music.163.com/"_ba },
    };
    return k_h;
}

[[nodiscard]] const QHash<QByteArray, QByteArray>& lrclibHeaders() {
    static const QHash<QByteArray, QByteArray> k_h = {
        { "User-Agent"_ba, "caelestia-shell (https://github.com/vacuited/shell)"_ba },
    };
    return k_h;
}

[[nodiscard]] const QHash<QByteArray, QByteArray>& browserHeaders() {
    static const QHash<QByteArray, QByteArray> k_h = {
        { "User-Agent"_ba, "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 Chrome/126.0.0.0 Safari/537.36"_ba },
    };
    return k_h;
}

[[nodiscard]] QString sanitizeFilenamePart(const QString& s) {
    QString out;
    out.reserve(s.size());
    for (const QChar c : s) {
        if (c == u'/' || c == u'\\' || c == u'\0' || c == u':') {
            out.append(u'_');
        } else {
            out.append(c);
        }
    }
    return out;
}

[[nodiscard]] bool containsCi(const QString& haystack, const QString& needle) {
    return !needle.isEmpty() && haystack.contains(needle, Qt::CaseInsensitive);
}

[[nodiscard]] bool isCreditLine(qreal firstTime, const QString& lyric) {
    if (firstTime >= 20.0) {
        return false;
    }
    static const QStringList k_creditKeywords = {
        u"作词"_s,
        u"作曲"_s,
        u"编曲"_s,
        u"制作"_s,
        u"收录"_s,
        u"演奏"_s,
        u"混音"_s,
        u"母带"_s,
        u"词版权"_s,
        u"曲版权"_s,
        u"词："_s,
        u"曲："_s,
        u"Lyricist"_s,
        u"Composer"_s,
        u"Arranger"_s,
        u"Producer"_s,
        u"Mixing"_s,
        u"Mastering"_s,
    };
    for (const QString& k : k_creditKeywords) {
        if (lyric.contains(k, Qt::CaseInsensitive)) {
            if (lyric.contains(u':') || lyric.contains(QChar(0xFF1A)) || lyric.size() < 32) {
                return true;
            }
        }
    }
    return false;
}

[[nodiscard]] bool isCjkCodePoint(uint32_t cp) {
    return (cp >= 0x3040 && cp <= 0x30FF)    // Hiragana & Katakana
           || (cp >= 0x4E00 && cp <= 0x9FFF) // CJK Unified Ideographs
           || (cp >= 0x3400 && cp <= 0x4DBF) // CJK Extension A
           || (cp >= 0xF900 && cp <= 0xFAFF) // CJK Compatibility
           || (cp >= 0xAC00 && cp <= 0xD7AF); // Hangul Syllables (often spaced, safe break fallback)
}

[[nodiscard]] bool containsCjkOrKana(const QString& s) {
    for (const QChar ch : s) {
        const uint32_t u = ch.unicode();
        if (isCjkCodePoint(u) && !(u >= 0xAC00 && u <= 0xD7AF)) {
            return true;
        }
    }
    return false;
}

[[nodiscard]] qreal parseTtmlTime(const QString& raw) {
    const QString s = raw.trimmed();
    if (s.isEmpty()) {
        return -1.0;
    }
    if (s.endsWith(u"ms"_s)) {
        bool ok = false;
        const qreal val = s.chopped(2).toDouble(&ok);
        return ok ? (val / 1000.0) : -1.0;
    }
    if (s.endsWith(u's')) {
        bool ok = false;
        const qreal val = s.chopped(1).toDouble(&ok);
        return ok ? val : -1.0;
    }
    const QStringList parts = s.split(u':');
    if (parts.size() == 1) {
        bool ok = false;
        const qreal val = parts.at(0).toDouble(&ok);
        return ok ? val : -1.0;
    }
    if (parts.size() == 2) {
        bool okM = false;
        bool okS = false;
        const qreal mins = parts.at(0).toDouble(&okM);
        const qreal secs = parts.at(1).toDouble(&okS);
        return (okM && okS) ? (mins * 60.0 + secs) : -1.0;
    }
    if (parts.size() == 3) {
        bool okH = false;
        bool okM = false;
        bool okS = false;
        const qreal hrs = parts.at(0).toDouble(&okH);
        const qreal mins = parts.at(1).toDouble(&okM);
        const qreal secs = parts.at(2).toDouble(&okS);
        return (okH && okM && okS) ? (hrs * 3600.0 + mins * 60.0 + secs) : -1.0;
    }
    return -1.0;
}

[[nodiscard]] QString joinSyllablesText(const QVector<LyricSyllable>& syls) {
    QString out;
    for (qsizetype i = 0; i < syls.size(); ++i) {
        out.append(syls.at(i).text);
        if (syls.at(i).trailingSpace && i + 1 < syls.size()) {
            out.append(u' ');
        }
    }
    return out.trimmed();
}

void stripOuterParens(QVector<LyricSyllable>& bg) {
    if (bg.isEmpty()) {
        return;
    }
    if (bg.first().text.startsWith(u'(')) {
        bg.first().text.remove(0, 1);
    }
    if (bg.last().text.endsWith(u')')) {
        bg.last().text.chop(1);
    }
    while (!bg.isEmpty() && bg.first().text.trimmed().isEmpty()) {
        bg.removeFirst();
    }
    while (!bg.isEmpty() && bg.last().text.trimmed().isEmpty()) {
        bg.removeLast();
    }
}

[[nodiscard]] QVariantList buildGroupsVariant(const QVector<LyricSyllable>& syls) {
    QVariantList groups;
    if (syls.isEmpty()) {
        return groups;
    }

    QVariantList curSyls;
    QString curText;
    qreal curStart = 0.0;
    qreal curEnd = 0.0;

    auto flushGroup = [&](bool trailingSpace) {
        if (curSyls.isEmpty()) {
            return;
        }
        QVariantMap g;
        g.insert(u"text"_s, curText);
        g.insert(u"start"_s, curStart);
        g.insert(u"end"_s, curEnd);
        g.insert(u"trailingSpace"_s, trailingSpace);
        g.insert(u"syllables"_s, curSyls);
        groups.append(g);
        curSyls.clear();
        curText.clear();
    };

    for (qsizetype i = 0; i < syls.size(); ++i) {
        const LyricSyllable& s = syls.at(i);
        if (s.text.isEmpty()) {
            if (s.trailingSpace && !curSyls.isEmpty()) {
                flushGroup(true);
            }
            continue;
        }

        const bool cjkBreak = containsCjkOrKana(s.text) && !curSyls.isEmpty();
        if (cjkBreak) {
            flushGroup(false);
        }

        if (curSyls.isEmpty()) {
            curStart = s.start;
            curEnd = s.end;
        } else {
            curStart = std::min(curStart, s.start);
            curEnd = std::max(curEnd, s.end);
        }
        curText.append(s.text);

        QVariantMap sm;
        sm.insert(u"text"_s, s.text);
        sm.insert(u"start"_s, s.start);
        sm.insert(u"end"_s, s.end);
        curSyls.append(sm);

        const bool breakAfterCjk = containsCjkOrKana(s.text) && (i + 1 < syls.size());
        if (s.trailingSpace || breakAfterCjk) {
            flushGroup(s.trailingSpace);
        }
    }
    flushGroup(false);

    return groups;
}

void mergeTimedNotes(QVector<LyricLine>& mainLines, const QVector<LyricLine>& notes, bool isTranslation) {
    if (mainLines.isEmpty() || notes.isEmpty()) {
        return;
    }
    for (const LyricLine& n : notes) {
        if (n.text.trimmed().isEmpty()) {
            continue;
        }
        qsizetype bestIdx = -1;
        qreal bestDelta = 0.38;
        for (qsizetype i = 0; i < mainLines.size(); ++i) {
            const qreal delta = std::abs(mainLines.at(i).time - n.time);
            if (delta < bestDelta) {
                bestDelta = delta;
                bestIdx = i;
            }
        }
        if (bestIdx >= 0) {
            if (isTranslation) {
                if (mainLines[bestIdx].translation.isEmpty()) {
                    mainLines[bestIdx].translation = n.text.trimmed();
                }
            } else {
                if (mainLines[bestIdx].romanization.isEmpty()) {
                    mainLines[bestIdx].romanization = n.text.trimmed();
                }
            }
        }
    }
}

[[nodiscard]] const QList<LyricsBackend>& orderedProviderList() {
    static const QList<LyricsBackend> k_list = {
        LyricsBackend::Boidu,
        LyricsBackend::LyricsPlus,
        LyricsBackend::NetEase,
        LyricsBackend::LRCLIB,
        LyricsBackend::Local,
    };
    return k_list;
}

} // namespace

Lyrics::Lyrics(QObject* parent)
    : QObject(parent)
    , m_nam(new QNetworkAccessManager(this))
    , m_loadDebounce(new QTimer(this))
    , m_autoGraceTimer(new QTimer(this)) {
    m_loadDebounce->setSingleShot(true);
    m_loadDebounce->setInterval(k_loadDebounceMs);
    QObject::connect(m_loadDebounce, &QTimer::timeout, this, &Lyrics::doLoad);

    m_autoGraceTimer->setSingleShot(true);
    m_autoGraceTimer->setInterval(k_autoGraceMs);
    QObject::connect(m_autoGraceTimer, &QTimer::timeout, this, [this] {
        evaluateSelection(m_currentRequestId, true);
    });

    const auto* cfg = config::ConfigSingleton::instance();
    const auto* svcCfg = cfg->services();
    const auto* paths = cfg->paths();

    m_preferredBackend = svcCfg->lyricsBackend();

    QObject::connect(
        svcCfg, &config::ServiceConfig::lyricsBackendChanged, this, &Lyrics::onPreferredBackendConfigChanged);
    QObject::connect(paths, &config::UserPaths::lyricsDirChanged, this, &Lyrics::onLyricsDirChanged);

    loadLyricsMap();
    resetProviderStates(false);
}

QStringList Lyrics::lyrics() const {
    return m_lyrics;
}

QVariantList Lyrics::richLines() const {
    return m_richLines;
}

bool Lyrics::isWordSynced() const {
    return m_isWordSynced;
}

bool Lyrics::hasTranslation() const {
    return m_hasTranslation;
}

bool Lyrics::hasRomanization() const {
    return m_hasRomanization;
}

LyricsBackend Lyrics::backend() const {
    return m_backend;
}

LyricsBackend Lyrics::preferredBackend() const {
    return m_preferredBackend;
}

void Lyrics::setPreferredBackend(LyricsBackend value) {
    if (m_preferredBackend == value) {
        return;
    }
    m_preferredBackend = value;
    emit preferredBackendChanged();

    config::ConfigSingleton::instance()->services()->set_lyricsBackend(value);

    scheduleLoad();
}

QList<LyricCandidate> Lyrics::lyricCandidates() const {
    return m_candidates;
}

LyricCandidate Lyrics::selectedCandidate() const {
    return m_selected;
}

void Lyrics::setSelectedCandidate(const LyricCandidate& value) {
    if (m_selected == value) {
        return;
    }
    m_selected = value;
    emit selectedCandidateChanged();

    if (!value.isValid()) {
        return;
    }

    const auto b = value.backend();
    setManualSource(true);
    m_pinnedProvider = b;
    setBackend(b);
    setLoading(true);

    const int reqId = m_currentRequestId;

    if (b == LyricsBackend::LRCLIB) {
        const QString cached = readCachedPayload(b, value.id());
        if (!cached.isEmpty()) {
            const auto lines = parseLrc(cached);
            if (!lines.isEmpty()) {
                ProviderEntry entry;
                entry.status = u"ready"_s;
                entry.lines = lines;
                entry.candidate = value;
                entry.hasWordSync = std::ranges::any_of(lines, [](const LyricLine& l) { return !l.words.isEmpty(); });
                updateProviderEntry(b, entry);
                applyProviderResult(b, entry);
                setLoading(false);
                if (!m_settingFromPrefs) {
                    persistTrackPrefs();
                }
                return;
            }
        }
        fetchLrclibById(value.id(), reqId);
    } else if (b == LyricsBackend::NetEase) {
        const QString cached = readCachedPayload(b, value.id());
        if (!cached.isEmpty()) {
            bool isWord = false;
            const auto lines = parseNetEaseJson(cached.toUtf8(), &isWord);
            if (!lines.isEmpty()) {
                ProviderEntry entry;
                entry.status = u"ready"_s;
                entry.lines = lines;
                entry.candidate = value;
                entry.hasWordSync = isWord;
                entry.detail = isWord ? u"YRC"_s : u"LRC"_s;
                entry.hasTranslation = std::ranges::any_of(lines, [](const LyricLine& l) { return !l.translation.isEmpty(); });
                entry.hasRomanization = std::ranges::any_of(lines, [](const LyricLine& l) { return !l.romanization.isEmpty(); });
                updateProviderEntry(b, entry);
                applyProviderResult(b, entry);
                setLoading(false);
                if (!m_settingFromPrefs) {
                    persistTrackPrefs();
                }
                return;
            }
        }
        fetchNetEaseLyricsById(value.id(), reqId, true);
    } else if (b == LyricsBackend::Local) {
        const auto lines = parseLocalFile(value.id());
        if (!lines.isEmpty()) {
            ProviderEntry entry;
            entry.status = u"ready"_s;
            entry.lines = lines;
            entry.candidate = value;
            entry.hasWordSync = std::ranges::any_of(lines, [](const LyricLine& l) { return !l.words.isEmpty(); });
            updateProviderEntry(b, entry);
            applyProviderResult(b, entry);
        }
        setLoading(false);
    } else if (b == LyricsBackend::Boidu || b == LyricsBackend::LyricsPlus) {
        const auto existing = m_providerResults.value(b);
        if (existing.status == u"ready"_s && !existing.lines.isEmpty()) {
            applyProviderResult(b, existing);
            setLoading(false);
        } else if (b == LyricsBackend::Boidu) {
            fetchBoidu(reqId);
        } else {
            fetchLyricsPlus(reqId);
        }
    }

    if (!m_settingFromPrefs) {
        persistTrackPrefs();
    }
}

bool Lyrics::manualSource() const {
    return m_manualSource;
}

QVariantList Lyrics::providerStates() const {
    QVariantList list;
    const auto& order = orderedProviderList();
    list.reserve(order.size());

    for (const LyricsBackend b : order) {
        const ProviderEntry entry = m_providerResults.value(b);
        QVariantMap item;
        item.insert(u"backend"_s, static_cast<int>(b));
        item.insert(u"key"_s, backendKey(b));
        item.insert(u"label"_s, backendLabel(b));
        item.insert(u"sublabel"_s, entry.detail);
        item.insert(u"status"_s, entry.status);
        item.insert(u"syncType"_s, entry.status == u"ready"_s ? (entry.hasWordSync ? u"word"_s : u"line"_s) : u"none"_s);
        item.insert(u"hasTranslation"_s, entry.hasTranslation);
        item.insert(u"hasRomanization"_s, entry.hasRomanization);
        item.insert(u"active"_s, m_hasLyrics && m_backend == b);
        list.append(item);
    }
    return list;
}

bool Lyrics::loading() const {
    return m_loading;
}

bool Lyrics::hasLyrics() const {
    return m_hasLyrics;
}

qreal Lyrics::offset() const {
    return m_offset;
}

void Lyrics::setOffset(qreal value) {
    if (qFuzzyCompare(m_offset + 1.0, value + 1.0)) {
        return;
    }
    m_offset = value;
    emit offsetChanged();

    if (!m_settingFromPrefs) {
        persistTrackPrefs();
    }
}

QString Lyrics::trackArtist() const {
    return m_artist;
}

QString Lyrics::trackTitle() const {
    return m_title;
}

int Lyrics::indexForTime(qreal time) const {
    if (m_lines.isEmpty()) {
        return -1;
    }
    const qreal target = time - m_offset + k_indexFudge;
    qsizetype lo = 0;
    qsizetype hi = m_lines.size();
    while (lo < hi) {
        const qsizetype mid = lo + (hi - lo) / 2;
        if (m_lines.at(mid).time <= target) {
            lo = mid + 1;
        } else {
            hi = mid;
        }
    }
    return static_cast<int>(lo - 1);
}

qreal Lyrics::timeForIndex(int index) const {
    if (index < 0 || index >= m_lines.size()) {
        return -1.0;
    }
    return m_lines.at(index).time + m_offset;
}

QVariantMap Lyrics::instrumentalGapAt(qreal time) const {
    QVariantMap out;
    out.insert(u"active"_s, false);
    out.insert(u"start"_s, 0.0);
    out.insert(u"end"_s, 0.0);
    out.insert(u"progress"_s, 0.0);

    if (m_lines.isEmpty()) {
        return out;
    }

    const qreal t = time - m_offset;
    const qreal firstStart = m_lines.first().time;
    if (t >= 0.0 && firstStart >= k_minGapSeconds && t < firstStart - 0.15) {
        out.insert(u"active"_s, true);
        out.insert(u"start"_s, 0.0);
        out.insert(u"end"_s, firstStart);
        out.insert(u"progress"_s, std::clamp(t / std::max(0.1, firstStart), 0.0, 1.0));
        return out;
    }

    const int idx = indexForTime(time);
    if (idx >= 0 && idx + 1 < m_lines.size()) {
        const LyricLine& cur = m_lines.at(idx);
        const LyricLine& nxt = m_lines.at(idx + 1);

        if (cur.text.trimmed().isEmpty() && cur.bgText.trimmed().isEmpty()) {
            const qreal dur = nxt.time - cur.time;
            if (dur >= k_minGapSeconds && t >= cur.time && t < nxt.time - 0.15) {
                out.insert(u"active"_s, true);
                out.insert(u"start"_s, cur.time);
                out.insert(u"end"_s, nxt.time);
                out.insert(u"progress"_s, std::clamp((t - cur.time) / dur, 0.0, 1.0));
                return out;
            }
        } else if (cur.endTime > cur.time && nxt.time > cur.endTime) {
            const qreal gapStart = cur.endTime + 0.15;
            const qreal gapEnd = nxt.time - 0.15;
            const qreal dur = gapEnd - gapStart;
            if (dur >= k_minGapSeconds && t >= gapStart && t < gapEnd) {
                out.insert(u"active"_s, true);
                out.insert(u"start"_s, gapStart);
                out.insert(u"end"_s, gapEnd);
                out.insert(u"progress"_s, std::clamp((t - gapStart) / dur, 0.0, 1.0));
                return out;
            }
        }
    }

    return out;
}

void Lyrics::selectProvider(int backendEnum) {
    const auto target = static_cast<LyricsBackend>(backendEnum);
    if (m_artist.isEmpty() && m_title.isEmpty()) {
        return;
    }

    if (target == LyricsBackend::Auto) {
        setManualSource(false);
        m_pinnedProvider = LyricsBackend::Auto;
        m_appliedGraceOrFinal = false;

        // Clear manual pin from lyrics_map.json while keeping offset
        const QString key = trackKey();
        if (m_lyricsMapLoaded && !key.isEmpty() && m_lyricsMap.contains(key)) {
            QJsonObject entry = m_lyricsMap.value(key).toObject();
            entry.remove(u"manual"_s);
            entry.remove(u"backend"_s);
            entry.remove(u"id"_s);
            if (qFuzzyCompare(entry.value(u"offset"_s).toDouble(0.0) + 1.0, 1.0)) {
                m_lyricsMap.remove(key);
            } else {
                m_lyricsMap.insert(key, entry);
            }
            QDir().mkpath(stateDir());
            QSaveFile out(lyricsMapPath());
            if (out.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
                out.write(QJsonDocument(m_lyricsMap).toJson(QJsonDocument::Compact));
                out.commit();
            }
        }

        m_autoGraceTimer->stop();
        evaluateSelection(m_currentRequestId, true);
        if (!m_hasLyrics && !anyProviderLoading()) {
            scheduleLoad();
        }
        return;
    }

    setManualSource(true);
    m_pinnedProvider = target;
    m_autoGraceTimer->stop();

    const ProviderEntry existing = m_providerResults.value(target);
    if (existing.status == u"ready"_s && !existing.lines.isEmpty()) {
        applyProviderResult(target, existing);
        setLoading(false);
        persistTrackPrefs();
        return;
    }

    if (existing.status == u"loading"_s) {
        setBackend(target);
        setLoading(true);
        persistTrackPrefs();
        return;
    }

    // Re-fetch that provider if not loaded or previously failed
    setBackend(target);
    setLoading(true);
    const int reqId = m_currentRequestId > 0 ? m_currentRequestId : newRequestId();
    ProviderEntry loadingEntry;
    loadingEntry.status = u"loading"_s;
    updateProviderEntry(target, loadingEntry);

    switch (target) {
    case LyricsBackend::Local:
        runLocalLookup();
        evaluateSelection(reqId, true);
        break;
    case LyricsBackend::Boidu:
        fetchBoidu(reqId);
        break;
    case LyricsBackend::LyricsPlus:
        fetchLyricsPlus(reqId);
        break;
    case LyricsBackend::NetEase:
        fetchNetEase(reqId);
        break;
    case LyricsBackend::LRCLIB:
        fetchLrclib(reqId);
        break;
    case LyricsBackend::Auto:
    default:
        break;
    }
    persistTrackPrefs();
}

void Lyrics::setTrack(const QString& artist, const QString& title, const QString& album, qreal duration) {
    const QString a = artist.trimmed();
    const QString t = title.trimmed();

    if (a == m_artist && t == m_title && album == m_album && qFuzzyCompare(duration + 1.0, m_duration + 1.0)) {
        return;
    }

    m_artist = a;
    m_title = t;
    m_album = album;
    m_duration = duration;
    emit trackChanged();

    scheduleLoad();
}

void Lyrics::clearTrack() {
    cancelInFlight();
    m_autoGraceTimer->stop();
    m_artist.clear();
    m_title.clear();
    m_album.clear();
    m_duration = 0.0;
    emit trackChanged();

    clearCandidates();
    clearLines();
    setManualSource(false);
    m_pinnedProvider = LyricsBackend::Auto;
    resetProviderStates(false);
    setLoading(false);
}

void Lyrics::refresh() {
    if (m_artist.isEmpty() && m_title.isEmpty()) {
        return;
    }
    // Remove disk caches for current track's online cache key so refresh fetches fresh data
    const QString pKey = providerCacheKey();
    if (!pKey.isEmpty()) {
        QFile::remove(cachePathFor(LyricsBackend::Boidu, pKey));
        QFile::remove(cachePathFor(LyricsBackend::LyricsPlus, pKey));
    }
    scheduleLoad();
}

void Lyrics::setBackend(LyricsBackend value) {
    if (m_backend == value) {
        return;
    }
    m_backend = value;
    emit backendChanged();
    emit providerStatesChanged();
}

void Lyrics::setLoading(bool value) {
    if (m_loading == value) {
        return;
    }
    m_loading = value;
    emit loadingChanged();
}

void Lyrics::setManualSource(bool value) {
    if (m_manualSource == value) {
        return;
    }
    m_manualSource = value;
    emit sourceStateChanged();
}

void Lyrics::setLines(QVector<LyricLine> lines, LyricsBackend source) {
    std::ranges::sort(lines, [](const LyricLine& a, const LyricLine& b) {
        return a.time < b.time;
    });

    // Compute reliable endTimes and duet turn alternation
    QString primaryAgent;
    for (const auto& l : lines) {
        if (!l.agent.isEmpty()) {
            primaryAgent = l.agent;
            break;
        }
    }

    for (qsizetype i = 0; i < lines.size(); ++i) {
        LyricLine& cur = lines[i];
        if (!cur.words.isEmpty()) {
            qreal maxWordEnd = cur.words.last().end;
            for (const auto& w : cur.words) {
                maxWordEnd = std::max(maxWordEnd, w.end);
            }
            if (cur.endTime <= cur.time && maxWordEnd > cur.time) {
                cur.endTime = maxWordEnd;
            }
        }
        if (cur.endTime <= cur.time) {
            if (i + 1 < lines.size()) {
                cur.endTime = lines.at(i + 1).time;
            } else if (m_duration > cur.time && m_duration < 86400.0) {
                cur.endTime = m_duration;
            } else {
                cur.endTime = cur.time + 5.0;
            }
        }
        if (!primaryAgent.isEmpty() && !cur.agent.isEmpty() && cur.agent != primaryAgent) {
            cur.oppositeTurn = true;
        }
    }

    m_lines = std::move(lines);
    QStringList list;
    list.reserve(m_lines.size());
    bool anyWord = false;
    bool anyTrans = false;
    bool anyRoma = false;
    for (const auto& l : std::as_const(m_lines)) {
        list.append(l.text);
        if (!l.words.isEmpty()) {
            anyWord = true;
        }
        if (!l.translation.isEmpty()) {
            anyTrans = true;
        }
        if (!l.romanization.isEmpty()) {
            anyRoma = true;
        }
    }
    m_lyrics = std::move(list);
    m_richLines = buildRichLines(m_lines);
    m_isWordSynced = anyWord;
    m_hasTranslation = anyTrans;
    m_hasRomanization = anyRoma;

    setBackend(source);
    emit lyricsChanged();
    emit providerStatesChanged();

    const auto hasLyricsVal = !m_lines.isEmpty();
    if (hasLyricsVal != m_hasLyrics) {
        m_hasLyrics = hasLyricsVal;
        emit hasLyricsChanged();
    }
}

void Lyrics::clearLines() {
    m_lines.clear();
    m_lyrics.clear();
    m_richLines.clear();
    m_isWordSynced = false;
    m_hasTranslation = false;
    m_hasRomanization = false;
    emit lyricsChanged();

    if (m_hasLyrics) {
        m_hasLyrics = false;
        emit hasLyricsChanged();
    }
}

void Lyrics::appendCandidates(const QList<LyricCandidate>& add) {
    if (add.isEmpty()) {
        return;
    }
    bool changed = false;
    for (const auto& c : add) {
        if (!m_candidates.contains(c)) {
            m_candidates.append(c);
            changed = true;
        }
    }
    if (changed) {
        emit lyricCandidatesChanged();
    }
}

void Lyrics::clearCandidates() {
    if (m_candidates.isEmpty()) {
        return;
    }
    m_candidates.clear();
    emit lyricCandidatesChanged();
}

void Lyrics::resetProviderStates(bool markOnlineLoading) {
    m_providerResults.clear();
    for (const LyricsBackend b : orderedProviderList()) {
        ProviderEntry e;
        if (markOnlineLoading && b != LyricsBackend::Local) {
            e.status = u"loading"_s;
        } else {
            e.status = u"idle"_s;
        }
        if (b == LyricsBackend::Boidu) {
            e.detail = u"Apple Music TTML"_s;
        } else if (b == LyricsBackend::LyricsPlus) {
            e.detail = u"Apple / Musixmatch / Spotify"_s;
        }
        m_providerResults.insert(b, e);
    }
    emit providerStatesChanged();
}

void Lyrics::updateProviderEntry(LyricsBackend backend, const ProviderEntry& entry) {
    m_providerResults.insert(backend, entry);
    emit providerStatesChanged();
}

int Lyrics::scoreProvider(LyricsBackend backend, const ProviderEntry& entry) const {
    if (entry.status != u"ready"_s || entry.lines.isEmpty()) {
        return -1;
    }
    if (entry.hasWordSync) {
        switch (backend) {
        case LyricsBackend::Local:
            return 1000;
        case LyricsBackend::Boidu:
            return 900;
        case LyricsBackend::LyricsPlus:
            return 800;
        case LyricsBackend::NetEase:
            return 700;
        case LyricsBackend::LRCLIB:
            return 600;
        case LyricsBackend::Auto:
        default:
            return 500;
        }
    }
    switch (backend) {
    case LyricsBackend::Local:
        return 450;
    case LyricsBackend::Boidu:
        return 400;
    case LyricsBackend::LyricsPlus:
        return 350;
    case LyricsBackend::LRCLIB:
        return 300;
    case LyricsBackend::NetEase:
        return 250;
    case LyricsBackend::Auto:
    default:
        return 100;
    }
}

bool Lyrics::anyWordCapableLoading() const {
    for (const LyricsBackend b : { LyricsBackend::Boidu, LyricsBackend::LyricsPlus, LyricsBackend::NetEase }) {
        if (m_providerResults.value(b).status == u"loading"_s) {
            return true;
        }
    }
    return false;
}

bool Lyrics::anyProviderLoading() const {
    for (const LyricsBackend b : orderedProviderList()) {
        if (m_providerResults.value(b).status == u"loading"_s) {
            return true;
        }
    }
    return false;
}

void Lyrics::applyProviderResult(LyricsBackend backend, const ProviderEntry& entry) {
    if (entry.lines.isEmpty()) {
        return;
    }
    setLines(entry.lines, backend);
    if (entry.candidate.isValid()) {
        appendCandidates({ entry.candidate });
        if (m_selected != entry.candidate) {
            m_selected = entry.candidate;
            emit selectedCandidateChanged();
        }
    }
}

void Lyrics::evaluateSelection(int reqId, bool graceExpired) {
    if (reqId != m_currentRequestId) {
        return;
    }

    // 1. Explicit manual source pinned for this song
    if (m_manualSource && m_pinnedProvider != LyricsBackend::Auto) {
        const ProviderEntry pinned = m_providerResults.value(m_pinnedProvider);
        if (pinned.status == u"ready"_s && !pinned.lines.isEmpty()) {
            m_autoGraceTimer->stop();
            applyProviderResult(m_pinnedProvider, pinned);
            setLoading(false);
            return;
        }
        if (pinned.status != u"loading"_s) {
            setLoading(false);
        }
        return;
    }

    // 2. Non-Auto global preferred backend
    if (m_preferredBackend != LyricsBackend::Auto) {
        const ProviderEntry pref = m_providerResults.value(m_preferredBackend);
        if (pref.status == u"ready"_s && !pref.lines.isEmpty()) {
            m_autoGraceTimer->stop();
            applyProviderResult(m_preferredBackend, pref);
            setLoading(false);
            return;
        }
        if (pref.status != u"loading"_s) {
            setLoading(false);
        }
        return;
    }

    // 3. Auto cascade prioritizing word-by-word
    LyricsBackend bestBackend = LyricsBackend::Auto;
    int bestScore = -1;
    for (const LyricsBackend b : orderedProviderList()) {
        const int s = scoreProvider(b, m_providerResults.value(b));
        if (s > bestScore) {
            bestScore = s;
            bestBackend = b;
        }
    }

    const bool stillLoading = anyProviderLoading();
    if (bestScore < 0) {
        if (!stillLoading) {
            m_autoGraceTimer->stop();
            setLoading(false);
        }
        return;
    }

    const ProviderEntry bestEntry = m_providerResults.value(bestBackend);
    const bool currentIsBetterOrEqual = m_hasLyrics && m_backend != LyricsBackend::Auto
                                        && scoreProvider(m_backend, m_providerResults.value(m_backend)) >= bestScore;

    if (bestEntry.hasWordSync) {
        m_autoGraceTimer->stop();
        if (!currentIsBetterOrEqual) {
            applyProviderResult(bestBackend, bestEntry);
        }
        m_appliedGraceOrFinal = true;
        setLoading(false);
        return;
    }

    // Best so far is line-synced
    if (!graceExpired && !m_appliedGraceOrFinal && anyWordCapableLoading()) {
        if (!m_autoGraceTimer->isActive()) {
            m_autoGraceTimer->start();
        }
        return;
    }

    m_autoGraceTimer->stop();
    if (!currentIsBetterOrEqual) {
        applyProviderResult(bestBackend, bestEntry);
    }
    m_appliedGraceOrFinal = true;
    setLoading(false);
}

void Lyrics::scheduleLoad() {
    m_loadDebounce->start();
}

int Lyrics::newRequestId() {
    return ++m_currentRequestId;
}

void Lyrics::cancelInFlight() {
    for (auto it = m_pendingReplies.begin(); it != m_pendingReplies.end(); ++it) {
        const auto& replies = it.value();
        for (const auto& ptr : replies) {
            if (auto* const reply = ptr.data()) {
                reply->abort();
                reply->deleteLater();
            }
        }
    }
    m_pendingReplies.clear();
}

void Lyrics::trackReply(int reqId, QNetworkReply* reply) {
    if (!reply) {
        return;
    }
    m_pendingReplies[reqId].append(QPointer<QNetworkReply>(reply));
}

void Lyrics::doLoad() {
    if (m_artist.isEmpty() && m_title.isEmpty()) {
        clearLines();
        clearCandidates();
        setManualSource(false);
        m_pinnedProvider = LyricsBackend::Auto;
        resetProviderStates(false);
        setLoading(false);
        return;
    }

    cancelInFlight();
    m_autoGraceTimer->stop();
    const int reqId = newRequestId();

    m_appliedGraceOrFinal = false;
    setLoading(true);
    clearLines();
    clearCandidates();
    resetProviderStates(m_preferredBackend != LyricsBackend::Local);

    // Restore per-track prefs (offset always; pinned backend ONLY if manual == true)
    m_settingFromPrefs = true;
    const QJsonObject saved = m_lyricsMap.value(trackKey()).toObject();
    setOffset(saved.value(u"offset"_s).toDouble(0.0));

    const bool isManual = saved.value(u"manual"_s).toBool(false);
    LyricCandidate restored;
    const QString savedBackendKey = saved.value(u"backend"_s).toString();
    const QString savedId = saved.value(u"id"_s).toString();
    const LyricsBackend savedBackend = backendFromKey(savedBackendKey);
    if (isManual && savedBackend != LyricsBackend::Auto) {
        m_pinnedProvider = savedBackend;
        setManualSource(true);
        if (!savedId.isEmpty()) {
            restored = LyricCandidate(savedBackend, savedId, m_title, m_artist, m_album, m_duration);
        }
    } else {
        m_pinnedProvider = LyricsBackend::Auto;
        setManualSource(false);
    }
    m_settingFromPrefs = false;

    // 1. Check Local synchronously
    runLocalLookup();

    // If user prefers Local exclusively and didn't manually pin another source for this track
    if (!m_manualSource && m_preferredBackend == LyricsBackend::Local) {
        evaluateSelection(reqId, true);
        return;
    }

    // 2. Launch online providers concurrently so both auto-cascade and source switcher stay populated
    if (restored.isValid() && (restored.backend() == LyricsBackend::LRCLIB || restored.backend() == LyricsBackend::NetEase)) {
        m_settingFromPrefs = true;
        setSelectedCandidate(restored);
        m_settingFromPrefs = false;
    }

    fetchBoidu(reqId);
    fetchLyricsPlus(reqId);
    if (!(restored.isValid() && restored.backend() == LyricsBackend::NetEase)) {
        fetchNetEase(reqId);
    }
    if (!(restored.isValid() && restored.backend() == LyricsBackend::LRCLIB)) {
        fetchLrclib(reqId);
    }

    // Also search candidates for picker metadata
    searchLrclibCandidates(reqId);
    searchNetEaseCandidates(reqId);

    // Evaluate immediately in case Local already satisfied Auto/Word or disk cache hit synchronously
    evaluateSelection(reqId, false);
}

void Lyrics::runLocalLookup() {
    const QString dir = lyricsDir();
    if (dir.isEmpty()) {
        ProviderEntry e;
        e.status = u"not_found"_s;
        updateProviderEntry(LyricsBackend::Local, e);
        return;
    }

    const QString file = findLocalLyricsFile(dir, m_artist, m_title);
    if (file.isEmpty()) {
        ProviderEntry e;
        e.status = u"not_found"_s;
        updateProviderEntry(LyricsBackend::Local, e);
        return;
    }

    const auto lines = parseLocalFile(file);
    if (lines.isEmpty()) {
        ProviderEntry e;
        e.status = u"not_found"_s;
        updateProviderEntry(LyricsBackend::Local, e);
        return;
    }

    const bool hasWord = std::ranges::any_of(lines, [](const LyricLine& l) { return !l.words.isEmpty(); });
    const bool hasTrans = std::ranges::any_of(lines, [](const LyricLine& l) { return !l.translation.isEmpty(); });
    const bool hasRoma = std::ranges::any_of(lines, [](const LyricLine& l) { return !l.romanization.isEmpty(); });
    const QString ext = QFileInfo(file).suffix().toUpper();

    ProviderEntry entry;
    entry.status = u"ready"_s;
    entry.lines = lines;
    entry.hasWordSync = hasWord;
    entry.hasTranslation = hasTrans;
    entry.hasRomanization = hasRoma;
    entry.detail = ext.isEmpty() ? u"Local file"_s : ext;
    entry.candidate = LyricCandidate(LyricsBackend::Local, file, m_title, m_artist, m_album, m_duration,
        hasWord ? u"word"_s : u"line"_s, hasTrans, hasRoma, entry.detail);
    updateProviderEntry(LyricsBackend::Local, entry);
    appendCandidates({ entry.candidate });
}

void Lyrics::fetchBoidu(int reqId, const QString& artistOverride, bool isRetry) {
    if (reqId != m_currentRequestId) {
        return;
    }

    const QString cTitle = cleanTitleQuery(m_title);
    const QString cArtist = artistOverride.isEmpty() ? cleanArtistQuery(m_artist) : artistOverride;
    const QString cacheId = providerCacheKey();

    if (!isRetry && !cacheId.isEmpty()) {
        const QString cached = readCachedPayload(LyricsBackend::Boidu, cacheId);
        if (!cached.isEmpty()) {
            const auto lines = parseTtml(cached);
            if (!lines.isEmpty()) {
                const bool hasWord = std::ranges::any_of(lines, [](const LyricLine& l) { return !l.words.isEmpty(); });
                const bool hasTrans =
                    std::ranges::any_of(lines, [](const LyricLine& l) { return !l.translation.isEmpty(); });
                const bool hasRoma =
                    std::ranges::any_of(lines, [](const LyricLine& l) { return !l.romanization.isEmpty(); });
                ProviderEntry entry;
                entry.status = u"ready"_s;
                entry.lines = lines;
                entry.hasWordSync = hasWord;
                entry.hasTranslation = hasTrans;
                entry.hasRomanization = hasRoma;
                entry.detail = u"Apple Music TTML"_s;
                entry.candidate = LyricCandidate(LyricsBackend::Boidu, cacheId, m_title, m_artist, m_album, m_duration,
                    hasWord ? u"word"_s : u"line"_s, hasTrans, hasRoma, entry.detail);
                updateProviderEntry(LyricsBackend::Boidu, entry);
                evaluateSelection(reqId, false);
                return;
            }
        }
    }

    QUrl url(u"https://lyrics-api.boidu.dev/getLyrics"_s);
    QUrlQuery q;
    q.addQueryItem(u"s"_s, cTitle);
    q.addQueryItem(u"a"_s, cArtist);
    if (!m_album.isEmpty()) {
        q.addQueryItem(u"al"_s, m_album);
    }
    constexpr qreal k_maxDurationSecs = std::numeric_limits<int>::max();
    if (m_duration > 0.0 && qIsFinite(m_duration) && m_duration < k_maxDurationSecs) {
        q.addQueryItem(u"d"_s, QString::number(qRound(m_duration)));
    }
    url.setQuery(q);

    auto* reply = getJson(url, browserHeaders(), true);
    trackReply(reqId, reply);

    QObject::connect(reply, &QNetworkReply::finished, this, [this, reply, reqId, cArtist, isRetry, cacheId] {
        reply->deleteLater();
        if (reqId != m_currentRequestId) {
            return;
        }

        auto handleMissOrError = [this, reqId, cArtist, isRetry](const QString& statusStr) {
            const QString primary = primaryArtistQuery(cArtist);
            if (!isRetry && !primary.isEmpty() && primary.compare(cArtist, Qt::CaseInsensitive) != 0) {
                fetchBoidu(reqId, primary, true);
                return;
            }
            ProviderEntry e;
            e.status = statusStr;
            e.detail = u"Apple Music TTML"_s;
            updateProviderEntry(LyricsBackend::Boidu, e);
            evaluateSelection(reqId, false);
        };

        if (reply->error() != QNetworkReply::NoError) {
            qCDebug(lcLyrics) << "boidu error:" << reply->errorString();
            const int httpStatus = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
            handleMissOrError(httpStatus == 404 ? u"not_found"_s : u"error"_s);
            return;
        }

        const QJsonDocument doc = QJsonDocument::fromJson(reply->readAll());
        const QString ttml = doc.object().value(u"ttml"_s).toString();
        if (ttml.isEmpty()) {
            handleMissOrError(u"not_found"_s);
            return;
        }

        const auto lines = parseTtml(ttml);
        if (lines.isEmpty()) {
            handleMissOrError(u"not_found"_s);
            return;
        }

        if (!cacheId.isEmpty()) {
            writeCachedPayload(LyricsBackend::Boidu, cacheId, ttml);
        }

        const bool hasWord = std::ranges::any_of(lines, [](const LyricLine& l) { return !l.words.isEmpty(); });
        const bool hasTrans = std::ranges::any_of(lines, [](const LyricLine& l) { return !l.translation.isEmpty(); });
        const bool hasRoma = std::ranges::any_of(lines, [](const LyricLine& l) { return !l.romanization.isEmpty(); });

        ProviderEntry entry;
        entry.status = u"ready"_s;
        entry.lines = lines;
        entry.hasWordSync = hasWord;
        entry.hasTranslation = hasTrans;
        entry.hasRomanization = hasRoma;
        entry.detail = u"Apple Music TTML"_s;
        entry.candidate = LyricCandidate(LyricsBackend::Boidu, cacheId, m_title, m_artist, m_album, m_duration,
            hasWord ? u"word"_s : u"line"_s, hasTrans, hasRoma, entry.detail);
        updateProviderEntry(LyricsBackend::Boidu, entry);
        evaluateSelection(reqId, false);
    });
}

void Lyrics::fetchLyricsPlus(int reqId, int mirrorIdx, const QString& artistOverride, bool isRetry) {
    if (reqId != m_currentRequestId) {
        return;
    }

    static const QStringList k_mirrors = {
        u"https://lyricsplus.prjktla.my.id/v2/lyrics/get"_s,
        u"https://lyricsplus.binimum.org/v2/lyrics/get"_s,
    };

    const QString cTitle = cleanTitleQuery(m_title);
    const QString cArtist = artistOverride.isEmpty() ? cleanArtistQuery(m_artist) : artistOverride;
    const QString cacheId = providerCacheKey();

    if (mirrorIdx == 0 && !isRetry && !cacheId.isEmpty()) {
        const QString cached = readCachedPayload(LyricsBackend::LyricsPlus, cacheId);
        if (!cached.isEmpty()) {
            QString detail;
            const auto lines = parseLyricsPlusJson(cached.toUtf8(), &detail);
            if (!lines.isEmpty()) {
                const bool hasWord = std::ranges::any_of(lines, [](const LyricLine& l) { return !l.words.isEmpty(); });
                const bool hasTrans =
                    std::ranges::any_of(lines, [](const LyricLine& l) { return !l.translation.isEmpty(); });
                const bool hasRoma =
                    std::ranges::any_of(lines, [](const LyricLine& l) { return !l.romanization.isEmpty(); });
                ProviderEntry entry;
                entry.status = u"ready"_s;
                entry.lines = lines;
                entry.hasWordSync = hasWord;
                entry.hasTranslation = hasTrans;
                entry.hasRomanization = hasRoma;
                entry.detail = detail.isEmpty() ? u"LyricsPlus"_s : detail;
                entry.candidate = LyricCandidate(LyricsBackend::LyricsPlus, cacheId, m_title, m_artist, m_album,
                    m_duration, hasWord ? u"word"_s : u"line"_s, hasTrans, hasRoma, entry.detail);
                updateProviderEntry(LyricsBackend::LyricsPlus, entry);
                evaluateSelection(reqId, false);
                return;
            }
        }
    }

    if (mirrorIdx < 0 || mirrorIdx >= k_mirrors.size()) {
        ProviderEntry e;
        e.status = u"not_found"_s;
        e.detail = u"Apple / Musixmatch / Spotify"_s;
        updateProviderEntry(LyricsBackend::LyricsPlus, e);
        evaluateSelection(reqId, false);
        return;
    }

    QUrl url(k_mirrors.at(mirrorIdx));
    QUrlQuery q;
    q.addQueryItem(u"title"_s, cTitle);
    q.addQueryItem(u"artist"_s, cArtist);
    if (!m_album.isEmpty()) {
        q.addQueryItem(u"album"_s, m_album);
    }
    constexpr qreal k_maxDurationSecs = std::numeric_limits<int>::max();
    if (m_duration > 0.0 && qIsFinite(m_duration) && m_duration < k_maxDurationSecs) {
        q.addQueryItem(u"duration"_s, QString::number(qRound(m_duration)));
    }
    q.addQueryItem(u"source"_s, u"apple,lyricsplus,musixmatch,spotify"_s);
    url.setQuery(q);

    auto* reply = getJson(url, browserHeaders(), true);
    trackReply(reqId, reply);

    QObject::connect(reply, &QNetworkReply::finished, this, [this, reply, reqId, mirrorIdx, cArtist, isRetry, cacheId] {
        reply->deleteLater();
        if (reqId != m_currentRequestId) {
            return;
        }

        const int httpStatus = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        if (reply->error() != QNetworkReply::NoError) {
            qCDebug(lcLyrics) << "lyricsplus error on mirror" << mirrorIdx << ":" << reply->errorString();
            if (httpStatus == 404) {
                const QString primary = primaryArtistQuery(cArtist);
                if (!isRetry && !primary.isEmpty() && primary.compare(cArtist, Qt::CaseInsensitive) != 0) {
                    fetchLyricsPlus(reqId, mirrorIdx, primary, true);
                    return;
                }
                ProviderEntry e;
                e.status = u"not_found"_s;
                e.detail = u"Apple / Musixmatch / Spotify"_s;
                updateProviderEntry(LyricsBackend::LyricsPlus, e);
                evaluateSelection(reqId, false);
                return;
            }
            if (mirrorIdx + 1 < k_mirrors.size()) {
                fetchLyricsPlus(reqId, mirrorIdx + 1, cArtist, isRetry);
                return;
            }
            ProviderEntry e;
            e.status = u"error"_s;
            e.detail = u"Apple / Musixmatch / Spotify"_s;
            updateProviderEntry(LyricsBackend::LyricsPlus, e);
            evaluateSelection(reqId, false);
            return;
        }

        const QByteArray raw = reply->readAll();
        QString detail;
        const auto lines = parseLyricsPlusJson(raw, &detail);
        if (lines.isEmpty()) {
            const QString primary = primaryArtistQuery(cArtist);
            if (!isRetry && !primary.isEmpty() && primary.compare(cArtist, Qt::CaseInsensitive) != 0) {
                fetchLyricsPlus(reqId, mirrorIdx, primary, true);
                return;
            }
            ProviderEntry e;
            e.status = u"not_found"_s;
            e.detail = u"Apple / Musixmatch / Spotify"_s;
            updateProviderEntry(LyricsBackend::LyricsPlus, e);
            evaluateSelection(reqId, false);
            return;
        }

        if (!cacheId.isEmpty()) {
            writeCachedPayload(LyricsBackend::LyricsPlus, cacheId, QString::fromUtf8(raw));
        }

        const bool hasWord = std::ranges::any_of(lines, [](const LyricLine& l) { return !l.words.isEmpty(); });
        const bool hasTrans = std::ranges::any_of(lines, [](const LyricLine& l) { return !l.translation.isEmpty(); });
        const bool hasRoma = std::ranges::any_of(lines, [](const LyricLine& l) { return !l.romanization.isEmpty(); });

        ProviderEntry entry;
        entry.status = u"ready"_s;
        entry.lines = lines;
        entry.hasWordSync = hasWord;
        entry.hasTranslation = hasTrans;
        entry.hasRomanization = hasRoma;
        entry.detail = detail.isEmpty() ? u"LyricsPlus"_s : detail;
        entry.candidate = LyricCandidate(LyricsBackend::LyricsPlus, cacheId, m_title, m_artist, m_album, m_duration,
            hasWord ? u"word"_s : u"line"_s, hasTrans, hasRoma, entry.detail);
        updateProviderEntry(LyricsBackend::LyricsPlus, entry);
        evaluateSelection(reqId, false);
    });
}

void Lyrics::fetchLrclib(int reqId) {
    if (reqId != m_currentRequestId) {
        return;
    }

    QUrl url(u"https://lrclib.net/api/get"_s);
    QUrlQuery q;
    q.addQueryItem(u"track_name"_s, cleanTitleQuery(m_title));
    q.addQueryItem(u"artist_name"_s, cleanArtistQuery(m_artist));
    if (!m_album.isEmpty()) {
        q.addQueryItem(u"album_name"_s, m_album);
    }

    constexpr qreal k_maxDurationSecs = std::numeric_limits<int>::max();
    if (m_duration > 0.0 && qIsFinite(m_duration) && m_duration < k_maxDurationSecs) {
        q.addQueryItem(u"duration"_s, QString::number(qRound(m_duration)));
    }
    url.setQuery(q);

    auto* reply = getJson(url, lrclibHeaders(), true);
    trackReply(reqId, reply);

    QObject::connect(reply, &QNetworkReply::finished, this, [this, reply, reqId] {
        reply->deleteLater();
        if (reqId != m_currentRequestId) {
            return;
        }
        if (reply->error() != QNetworkReply::NoError) {
            qCDebug(lcLyrics) << "lrclib /get error:" << reply->errorString();
            const int httpStatus = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
            ProviderEntry e;
            e.status = httpStatus == 404 ? u"not_found"_s : u"error"_s;
            updateProviderEntry(LyricsBackend::LRCLIB, e);
            evaluateSelection(reqId, false);
            return;
        }
        const QJsonDocument doc = QJsonDocument::fromJson(reply->readAll());
        const QJsonObject obj = doc.object();
        const QString synced = obj.value(u"syncedLyrics"_s).toString();
        const qint64 id = static_cast<qint64>(obj.value(u"id"_s).toDouble());

        if (synced.isEmpty()) {
            ProviderEntry e;
            e.status = u"not_found"_s;
            updateProviderEntry(LyricsBackend::LRCLIB, e);
            evaluateSelection(reqId, false);
            return;
        }

        const auto lines = parseLrc(synced);
        if (lines.isEmpty()) {
            ProviderEntry e;
            e.status = u"not_found"_s;
            updateProviderEntry(LyricsBackend::LRCLIB, e);
            evaluateSelection(reqId, false);
            return;
        }

        writeCachedPayload(LyricsBackend::LRCLIB, QString::number(id), synced);
        const bool hasWord = std::ranges::any_of(lines, [](const LyricLine& l) { return !l.words.isEmpty(); });
        const LyricCandidate cand(LyricsBackend::LRCLIB, QString::number(id), obj.value(u"trackName"_s).toString(),
            obj.value(u"artistName"_s).toString(), obj.value(u"albumName"_s).toString(),
            obj.value(u"duration"_s).toDouble(), hasWord ? u"word"_s : u"line"_s, false, false,
            hasWord ? u"ELRC"_s : u"LRC"_s);

        ProviderEntry entry;
        entry.status = u"ready"_s;
        entry.lines = lines;
        entry.candidate = cand;
        entry.hasWordSync = hasWord;
        entry.detail = hasWord ? u"Enhanced LRC"_s : u"Community LRC"_s;
        updateProviderEntry(LyricsBackend::LRCLIB, entry);
        appendCandidates({ cand });
        evaluateSelection(reqId, false);
    });
}

void Lyrics::fetchNetEase(int reqId) {
    if (reqId != m_currentRequestId) {
        return;
    }

    const QString cTitle = cleanTitleQuery(m_title);
    const QString cArtist = cleanArtistQuery(m_artist);
    const QString pArtist = primaryArtistQuery(cArtist);

    QUrl url(u"https://music.163.com/api/search/get"_s);
    QUrlQuery q;
    q.addQueryItem(u"s"_s, u"%1 %2"_s.arg(cTitle, pArtist.isEmpty() ? cArtist : pArtist));
    q.addQueryItem(u"type"_s, u"1"_s);
    q.addQueryItem(u"limit"_s, u"5"_s);
    url.setQuery(q);

    auto* reply = getJson(url, netEaseHeaders(), true);
    trackReply(reqId, reply);

    QObject::connect(reply, &QNetworkReply::finished, this, [this, reply, reqId, cArtist, pArtist] {
        reply->deleteLater();
        if (reqId != m_currentRequestId) {
            return;
        }
        if (reply->error() != QNetworkReply::NoError) {
            qCDebug(lcLyrics) << "netease /search error:" << reply->errorString();
            ProviderEntry e;
            e.status = u"error"_s;
            updateProviderEntry(LyricsBackend::NetEase, e);
            evaluateSelection(reqId, false);
            return;
        }

        const QJsonDocument doc = QJsonDocument::fromJson(reply->readAll());
        const QJsonArray songs = doc.object().value(u"result"_s).toObject().value(u"songs"_s).toArray();

        qint64 bestId = -1;
        for (const auto& v : songs) {
            const QJsonObject s = v.toObject();
            const QJsonArray artists = s.value(u"artists"_s).toArray();
            bool artistMatch = false;
            for (const auto& aVal : artists) {
                const QString sArtist = aVal.toObject().value(u"name"_s).toString();
                if (containsCi(cArtist, sArtist) || containsCi(sArtist, cArtist)
                    || containsCi(pArtist, sArtist) || containsCi(sArtist, pArtist)) {
                    artistMatch = true;
                    break;
                }
            }
            if (!artistMatch) {
                continue;
            }
            if (m_duration > 0.0 && m_duration < 86400.0) {
                const qreal sDur = s.value(u"duration"_s).toDouble() / 1000.0;
                if (sDur > 0.0 && std::abs(sDur - m_duration) > 10.0) {
                    continue;
                }
            }
            bestId = static_cast<qint64>(s.value(u"id"_s).toDouble());
            break;
        }

        if (bestId < 0) {
            ProviderEntry e;
            e.status = u"not_found"_s;
            updateProviderEntry(LyricsBackend::NetEase, e);
            evaluateSelection(reqId, false);
            return;
        }

        fetchNetEaseLyricsById(QString::number(bestId), reqId, false);
    });
}

void Lyrics::searchLrclibCandidates(int reqId) {
    QUrl url(u"https://lrclib.net/api/search"_s);
    QUrlQuery q;
    q.addQueryItem(u"track_name"_s, cleanTitleQuery(m_title));
    q.addQueryItem(u"artist_name"_s, cleanArtistQuery(m_artist));
    url.setQuery(q);

    auto* reply = getJson(url, lrclibHeaders(), true);
    trackReply(reqId, reply);

    QObject::connect(reply, &QNetworkReply::finished, this, [this, reply, reqId] {
        reply->deleteLater();
        if (reqId != m_currentRequestId || reply->error() != QNetworkReply::NoError) {
            return;
        }
        const QJsonDocument doc = QJsonDocument::fromJson(reply->readAll());
        const QJsonArray arr = doc.array();

        QList<LyricCandidate> add;
        add.reserve(arr.size());
        for (const auto& v : arr) {
            const QJsonObject o = v.toObject();
            if (o.value(u"syncedLyrics"_s).isNull()) {
                continue;
            }
            add.append(
                LyricCandidate(LyricsBackend::LRCLIB, QString::number(static_cast<qint64>(o.value(u"id"_s).toDouble())),
                    o.value(u"trackName"_s).toString(), o.value(u"artistName"_s).toString(),
                    o.value(u"albumName"_s).toString(), o.value(u"duration"_s).toDouble(), u"line"_s));
        }
        appendCandidates(add);
    });
}

void Lyrics::searchNetEaseCandidates(int reqId) {
    QUrl url(u"https://music.163.com/api/search/get"_s);
    QUrlQuery q;
    q.addQueryItem(u"s"_s, u"%1 %2"_s.arg(cleanTitleQuery(m_title), cleanArtistQuery(m_artist)));
    q.addQueryItem(u"type"_s, u"1"_s);
    q.addQueryItem(u"limit"_s, u"5"_s);
    url.setQuery(q);

    auto* reply = getJson(url, netEaseHeaders(), true);
    trackReply(reqId, reply);

    QObject::connect(reply, &QNetworkReply::finished, this, [this, reply, reqId] {
        reply->deleteLater();
        if (reqId != m_currentRequestId || reply->error() != QNetworkReply::NoError) {
            return;
        }
        const QJsonDocument doc = QJsonDocument::fromJson(reply->readAll());
        const QJsonArray songs = doc.object().value(u"result"_s).toObject().value(u"songs"_s).toArray();

        QList<LyricCandidate> add;
        add.reserve(songs.size());
        for (const auto& v : songs) {
            const QJsonObject s = v.toObject();
            QStringList artistNames;
            const QJsonArray artists = s.value(u"artists"_s).toArray();
            artistNames.reserve(artists.size());
            for (const auto& a : artists) {
                artistNames.append(a.toObject().value(u"name"_s).toString());
            }
            add.append(LyricCandidate(LyricsBackend::NetEase,
                QString::number(static_cast<qint64>(s.value(u"id"_s).toDouble())), s.value(u"name"_s).toString(),
                artistNames.join(u", "_s)));
        }
        appendCandidates(add);
    });
}

void Lyrics::fetchLrclibById(const QString& id, int reqId) {
    const QUrl url(u"https://lrclib.net/api/get/"_s + id);
    auto* reply = getJson(url, lrclibHeaders(), true);
    trackReply(reqId, reply);

    QObject::connect(reply, &QNetworkReply::finished, this, [this, reply, reqId, id] {
        reply->deleteLater();
        if (reqId != m_currentRequestId) {
            return;
        }
        if (reply->error() != QNetworkReply::NoError) {
            qCWarning(lcLyrics) << "lrclib /get/{id} error:" << reply->errorString();
            setLoading(false);
            return;
        }
        const QJsonDocument doc = QJsonDocument::fromJson(reply->readAll());
        const QString synced = doc.object().value(u"syncedLyrics"_s).toString();
        if (synced.isEmpty()) {
            setLoading(false);
            return;
        }
        writeCachedPayload(LyricsBackend::LRCLIB, id, synced);
        const auto lines = parseLrc(synced);
        const bool hasWord = std::ranges::any_of(lines, [](const LyricLine& l) { return !l.words.isEmpty(); });
        ProviderEntry entry;
        entry.status = lines.isEmpty() ? u"not_found"_s : u"ready"_s;
        entry.lines = lines;
        entry.hasWordSync = hasWord;
        entry.detail = hasWord ? u"Enhanced LRC"_s : u"Community LRC"_s;
        entry.candidate = m_selected;
        updateProviderEntry(LyricsBackend::LRCLIB, entry);
        if (!lines.isEmpty()) {
            applyProviderResult(LyricsBackend::LRCLIB, entry);
        }
        setLoading(false);
    });
}

void Lyrics::fetchNetEaseLyricsById(const QString& id, int reqId, bool selectAfterLoad) {
    QUrl url(u"https://music.163.com/api/song/lyric/v1"_s);
    QUrlQuery q;
    q.addQueryItem(u"id"_s, id);
    q.addQueryItem(u"cp"_s, u"false"_s);
    q.addQueryItem(u"tv"_s, u"0"_s);
    q.addQueryItem(u"lv"_s, u"0"_s);
    q.addQueryItem(u"rv"_s, u"0"_s);
    q.addQueryItem(u"kv"_s, u"0"_s);
    q.addQueryItem(u"yv"_s, u"0"_s);
    q.addQueryItem(u"ytv"_s, u"0"_s);
    q.addQueryItem(u"yrv"_s, u"0"_s);
    url.setQuery(q);

    auto* reply = getJson(url, netEaseHeaders(), true);
    trackReply(reqId, reply);

    QObject::connect(reply, &QNetworkReply::finished, this, [this, reply, reqId, id, selectAfterLoad] {
        reply->deleteLater();
        if (reqId != m_currentRequestId) {
            return;
        }
        if (reply->error() != QNetworkReply::NoError) {
            qCWarning(lcLyrics) << "netease /lyric/v1 error:" << reply->errorString();
            ProviderEntry e;
            e.status = u"error"_s;
            updateProviderEntry(LyricsBackend::NetEase, e);
            evaluateSelection(reqId, false);
            return;
        }

        const QByteArray raw = reply->readAll();
        bool isWord = false;
        const auto lines = parseNetEaseJson(raw, &isWord);
        if (lines.isEmpty()) {
            ProviderEntry e;
            e.status = u"not_found"_s;
            updateProviderEntry(LyricsBackend::NetEase, e);
            evaluateSelection(reqId, false);
            return;
        }

        writeCachedPayload(LyricsBackend::NetEase, id, QString::fromUtf8(raw));
        const bool hasTrans = std::ranges::any_of(lines, [](const LyricLine& l) { return !l.translation.isEmpty(); });
        const bool hasRoma = std::ranges::any_of(lines, [](const LyricLine& l) { return !l.romanization.isEmpty(); });
        const QString detail = isWord ? u"YRC"_s : u"LRC"_s;
        const LyricCandidate cand(LyricsBackend::NetEase, id, m_title, m_artist, m_album, m_duration,
            isWord ? u"word"_s : u"line"_s, hasTrans, hasRoma, detail);

        ProviderEntry entry;
        entry.status = u"ready"_s;
        entry.lines = lines;
        entry.hasWordSync = isWord;
        entry.hasTranslation = hasTrans;
        entry.hasRomanization = hasRoma;
        entry.detail = detail;
        entry.candidate = cand;
        updateProviderEntry(LyricsBackend::NetEase, entry);
        appendCandidates({ cand });

        if (selectAfterLoad) {
            applyProviderResult(LyricsBackend::NetEase, entry);
            setLoading(false);
        } else {
            evaluateSelection(reqId, false);
        }
    });
}

QNetworkReply* Lyrics::getJson(const QUrl& url, const QHash<QByteArray, QByteArray>& headers, bool noCookies) {
    QNetworkRequest req(url);
    req.setAttribute(QNetworkRequest::CacheLoadControlAttribute, QNetworkRequest::AlwaysNetwork);
    if (noCookies) {
        req.setAttribute(QNetworkRequest::CookieLoadControlAttribute, QNetworkRequest::Manual);
        req.setAttribute(QNetworkRequest::CookieSaveControlAttribute, QNetworkRequest::Manual);
    }
    req.setTransferTimeout(k_transferTimeoutMs);
    req.setRawHeader("Cache-Control"_ba, "no-cache, no-store"_ba);
    req.setRawHeader("Pragma"_ba, "no-cache"_ba);
    req.setRawHeader("Connection"_ba, "close"_ba);
    req.setRawHeader("Accept"_ba, "application/json"_ba);
    for (auto it = headers.constBegin(); it != headers.constEnd(); ++it) {
        req.setRawHeader(it.key(), it.value());
    }
    return m_nam->get(req);
}

void Lyrics::onPreferredBackendConfigChanged() {
    const LyricsBackend desired = config::ConfigSingleton::instance()->services()->lyricsBackend();
    if (desired == m_preferredBackend) {
        return;
    }
    m_preferredBackend = desired;
    emit preferredBackendChanged();
    scheduleLoad();
}

void Lyrics::onLyricsDirChanged() {
    scheduleLoad();
}

void Lyrics::loadLyricsMap() {
    m_lyricsMap = {};
    m_lyricsMapLoaded = false;

    QFile f(lyricsMapPath());
    if (!f.open(QIODevice::ReadOnly)) {
        m_lyricsMapLoaded = true;
        return;
    }
    const QByteArray bytes = f.readAll();
    f.close();

    QJsonParseError err{};
    const QJsonDocument doc = QJsonDocument::fromJson(bytes, &err);
    if (err.error != QJsonParseError::NoError) {
        qCWarning(lcLyrics) << "lyrics_map.json parse error:" << err.errorString();
        m_lyricsMapLoaded = true;
        return;
    }
    m_lyricsMap = doc.object();
    m_lyricsMapLoaded = true;
}

void Lyrics::persistTrackPrefs() {
    if (!m_lyricsMapLoaded || trackKey().isEmpty()) {
        return;
    }
    const QString key = trackKey();
    QJsonObject entry = m_lyricsMap.value(key).toObject();
    entry.insert(u"offset"_s, m_offset);
    if (m_manualSource && m_pinnedProvider != LyricsBackend::Auto) {
        entry.insert(u"manual"_s, true);
        entry.insert(u"backend"_s, backendKey(m_pinnedProvider));
        if (m_selected.isValid() && m_selected.backend() == m_pinnedProvider) {
            entry.insert(u"id"_s, m_selected.id());
        } else {
            entry.remove(u"id"_s);
        }
    } else {
        entry.remove(u"manual"_s);
        entry.remove(u"backend"_s);
        entry.remove(u"id"_s);
    }
    m_lyricsMap.insert(key, entry);

    QDir().mkpath(stateDir());

    QSaveFile out(lyricsMapPath());
    if (!out.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        qCWarning(lcLyrics) << "cannot open" << lyricsMapPath() << "for write:" << out.errorString();
        return;
    }
    const QByteArray bytes = QJsonDocument(m_lyricsMap).toJson(QJsonDocument::Compact);
    if (out.write(bytes) != bytes.size()) {
        qCWarning(lcLyrics) << "short write to" << lyricsMapPath();
        out.cancelWriting();
        return;
    }
    if (!out.commit()) {
        qCWarning(lcLyrics) << "commit failed for" << lyricsMapPath() << ":" << out.errorString();
    }
}

QString Lyrics::lyricsDir() {
    QString dir = config::ConfigSingleton::instance()->paths()->lyricsDir();
    if (dir.isEmpty()) {
        return {};
    }
    if (dir == u"~"_s) {
        dir = QDir::homePath();
    } else if (dir.startsWith(u"~/"_s)) {
        dir.replace(0, 1, QDir::homePath());
    }
    while (dir.endsWith(u'/') && dir.size() > 1) {
        dir.chop(1);
    }
    return dir;
}

QString Lyrics::lyricsMapPath() {
    return stateDir() + u"/lyrics_map.json"_s;
}

QString Lyrics::trackKey() const {
    if (m_artist.isEmpty() && m_title.isEmpty()) {
        return {};
    }
    return u"%1 - %2"_s.arg(m_artist.trimmed(), m_title.trimmed());
}

QString Lyrics::providerCacheKey() const {
    const QString a = cleanArtistQuery(m_artist);
    const QString t = cleanTitleQuery(m_title);
    if (a.isEmpty() && t.isEmpty()) {
        return {};
    }
    const qint64 durSec = (m_duration > 0.0 && qIsFinite(m_duration) && m_duration < 86400.0) ? qRound64(m_duration) : 0;
    return sanitizeFilenamePart(u"%1 - %2_%3"_s.arg(a, t, QString::number(durSec)));
}

QString Lyrics::backendKey(LyricsBackend value) {
    switch (value) {
    case LyricsBackend::Local:
        return u"Local"_s;
    case LyricsBackend::Boidu:
        return u"Boidu"_s;
    case LyricsBackend::LyricsPlus:
        return u"LyricsPlus"_s;
    case LyricsBackend::LRCLIB:
        return u"LRCLIB"_s;
    case LyricsBackend::NetEase:
        return u"NetEase"_s;
    case LyricsBackend::Auto:
    default:
        return u"Auto"_s;
    }
}

QString Lyrics::backendLabel(LyricsBackend value) {
    switch (value) {
    case LyricsBackend::Local:
        return u"Local"_s;
    case LyricsBackend::Boidu:
        return u"Boidu"_s;
    case LyricsBackend::LyricsPlus:
        return u"LyricsPlus"_s;
    case LyricsBackend::NetEase:
        return u"NetEase Music"_s;
    case LyricsBackend::LRCLIB:
        return u"LRCLIB"_s;
    case LyricsBackend::Auto:
    default:
        return u"Automatic"_s;
    }
}

LyricsBackend Lyrics::backendFromKey(const QString& key) {
    if (key.compare(u"Local"_s, Qt::CaseInsensitive) == 0) {
        return LyricsBackend::Local;
    }
    if (key.compare(u"Boidu"_s, Qt::CaseInsensitive) == 0) {
        return LyricsBackend::Boidu;
    }
    if (key.compare(u"LyricsPlus"_s, Qt::CaseInsensitive) == 0) {
        return LyricsBackend::LyricsPlus;
    }
    if (key.compare(u"LRCLIB"_s, Qt::CaseInsensitive) == 0) {
        return LyricsBackend::LRCLIB;
    }
    if (key.compare(u"NetEase"_s, Qt::CaseInsensitive) == 0) {
        return LyricsBackend::NetEase;
    }
    return LyricsBackend::Auto;
}

const QString& Lyrics::stateDir() {
    static const QString k_dir = [] {
        QString state = qEnvironmentVariable("XDG_STATE_HOME");
        if (state.isEmpty()) {
            state = QDir::homePath() + u"/.local/state"_s;
        }
        return state + u"/caelestia/lyrics"_s;
    }();
    return k_dir;
}

const QString& Lyrics::cacheDir() {
    static const QString k_dir = [] {
        QString cache = qEnvironmentVariable("XDG_CACHE_HOME");
        if (cache.isEmpty()) {
            cache = QDir::homePath() + u"/.cache"_s;
        }
        return cache + u"/caelestia/lyrics"_s;
    }();
    return k_dir;
}

QString Lyrics::cachePathFor(LyricsBackend backend, const QString& id) {
    if (id.isEmpty() || backend == LyricsBackend::Auto || backend == LyricsBackend::Local) {
        return {};
    }
    QString ext = u"lrc"_s;
    if (backend == LyricsBackend::Boidu) {
        ext = u"ttml"_s;
    } else if (backend == LyricsBackend::LyricsPlus || backend == LyricsBackend::NetEase) {
        ext = u"json"_s;
    }
    return u"%1/%2/%3.%4"_s.arg(cacheDir(), backendKey(backend), sanitizeFilenamePart(id), ext);
}

QString Lyrics::readCachedPayload(LyricsBackend backend, const QString& id) {
    const QString path = cachePathFor(backend, id);
    if (path.isEmpty()) {
        return {};
    }
    QFile f(path);
    if (!f.open(QIODevice::ReadOnly)) {
        return {};
    }
    return QString::fromUtf8(f.readAll());
}

void Lyrics::writeCachedPayload(LyricsBackend backend, const QString& id, const QString& text) {
    if (text.isEmpty()) {
        return;
    }
    const QString path = cachePathFor(backend, id);
    if (path.isEmpty()) {
        return;
    }
    QDir().mkpath(QFileInfo(path).absolutePath());

    QSaveFile out(path);
    if (!out.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        qCWarning(lcLyrics) << "cannot open" << path << "for write:" << out.errorString();
        return;
    }
    const QByteArray bytes = text.toUtf8();
    if (out.write(bytes) != bytes.size()) {
        qCWarning(lcLyrics) << "short write to" << path;
        out.cancelWriting();
        return;
    }
    if (!out.commit()) {
        qCWarning(lcLyrics) << "commit failed for" << path << ":" << out.errorString();
    }
}

QString Lyrics::cleanArtistQuery(const QString& artist) {
    QString out = artist.trimmed();
    static const QRegularExpression k_topic(u"\\s*-\\s*Topic$"_s, QRegularExpression::CaseInsensitiveOption);
    out.remove(k_topic);
    return out.trimmed();
}

QString Lyrics::primaryArtistQuery(const QString& artist) {
    const QString cleaned = cleanArtistQuery(artist);
    static const QRegularExpression k_sep(
        u"\\s*(?:,|&|feat\\.?|ft\\.?|\\sx\\s|\\sfeaturing\\s)\\s*"_s, QRegularExpression::CaseInsensitiveOption);
    const auto m = k_sep.match(cleaned);
    if (m.hasMatch() && m.capturedStart() > 0) {
        return cleaned.left(m.capturedStart()).trimmed();
    }
    return cleaned;
}

QString Lyrics::cleanTitleQuery(const QString& title) {
    QString out = title.trimmed();
    static const QRegularExpression k_noise(
        u"\\s*[\\(\\[]"
        u"(?:official\\s*(?:music\\s*)?(?:video|audio|visualizer|lyric\\s*video)|lyric\\s*video|lyrics?|audio|hd|4k|explicit)"
        u"[\\)\\]]"_s,
        QRegularExpression::CaseInsensitiveOption);
    out.remove(k_noise);
    return out.trimmed();
}

QString Lyrics::findLocalLyricsFile(const QString& dir, const QString& artist, const QString& title) {
    if (dir.isEmpty() || (artist.isEmpty() && title.isEmpty())) {
        return {};
    }

    static const QStringList k_exts = { u"ttml"_s, u"elrc"_s, u"lrc"_s };
    const QString sa = sanitizeFilenamePart(artist);
    const QString st = sanitizeFilenamePart(title);

    for (const QString& ext : k_exts) {
        const QString flat = u"%1/%2 - %3.%4"_s.arg(dir, sa, st, ext);
        if (QFile::exists(flat)) {
            return flat;
        }
    }

    QString fallbackMatch;
    QDirIterator it(dir, QStringList{ u"*.ttml"_s, u"*.elrc"_s, u"*.lrc"_s }, QDir::Files | QDir::NoDotAndDotDot,
        QDirIterator::Subdirectories | QDirIterator::FollowSymlinks);

    while (it.hasNext()) {
        const QString path = it.next();
        const QString name = it.fileName();
        if ((artist.isEmpty() || containsCi(name, artist)) && (title.isEmpty() || containsCi(name, title))) {
            if (path.endsWith(u".ttml"_s, Qt::CaseInsensitive) || path.endsWith(u".elrc"_s, Qt::CaseInsensitive)) {
                return path;
            }
            if (fallbackMatch.isEmpty()) {
                fallbackMatch = path;
            }
        }
    }
    return fallbackMatch;
}

QVector<LyricLine> Lyrics::parseLocalFile(const QString& path) {
    QFile f(path);
    if (!f.open(QIODevice::ReadOnly)) {
        return {};
    }
    const QString text = QString::fromUtf8(f.readAll());
    if (path.endsWith(u".ttml"_s, Qt::CaseInsensitive) || text.trimmed().startsWith(u"<tt"_s)) {
        return parseTtml(text);
    }
    return parseLrc(text);
}

QVector<LyricLine> Lyrics::parseLrc(const QString& text) {
    QVector<LyricLine> result;
    if (text.isEmpty()) {
        return result;
    }

    static const QRegularExpression k_timeRegex(u"\\[(\\d+):(\\d+(?:\\.\\d+)?)\\]"_s);
    static const QRegularExpression k_elrcWordRegex(u"<(\\d+):(\\d+(?:\\.\\d+)?)>([^<]*)"_s);

    const QStringList lines = text.split(u'\n');
    for (const QString& rawLine : lines) {
        const QString trimmedRaw = rawLine.trimmed();
        if (trimmedRaw.isEmpty() || trimmedRaw.startsWith(u'{')) {
            continue;
        }

        QList<QRegularExpressionMatch> matches;
        auto it = k_timeRegex.globalMatch(rawLine);
        while (it.hasNext()) {
            matches.append(it.next());
        }
        if (matches.isEmpty()) {
            continue;
        }

        QString body = rawLine;
        body.replace(k_timeRegex, QString());
        body = body.trimmed();

        const qreal firstTime = matches.first().captured(1).toInt() * 60.0 + matches.first().captured(2).toDouble();

        QVector<LyricSyllable> parsedWords;
        QString plainBody = body;
        if (body.contains(u'<')) {
            auto wit = k_elrcWordRegex.globalMatch(body);
            QVector<LyricSyllable> tmpWords;
            QString rebuilt;
            while (wit.hasNext()) {
                const auto wm = wit.next();
                const qreal wt = wm.captured(1).toInt() * 60.0 + wm.captured(2).toDouble();
                const QString wraw = wm.captured(3);
                const bool trail = wraw.endsWith(u' ') || wraw.endsWith(u'\t');
                const QString wclean = wraw.trimmed();
                if (!wclean.isEmpty()) {
                    tmpWords.append(LyricSyllable{ .start = wt, .end = wt + 0.5, .text = wclean, .trailingSpace = trail });
                    if (!rebuilt.isEmpty()) {
                        rebuilt.append(u' ');
                    }
                    rebuilt.append(wclean);
                } else if (trail && !tmpWords.isEmpty()) {
                    tmpWords.last().trailingSpace = true;
                }
            }
            if (!tmpWords.isEmpty()) {
                for (qsizetype wi = 0; wi + 1 < tmpWords.size(); ++wi) {
                    tmpWords[wi].end = std::max(tmpWords.at(wi).start + 0.05, tmpWords.at(wi + 1).start);
                }
                parsedWords = std::move(tmpWords);
                plainBody = joinSyllablesText(parsedWords);
            }
        }

        if (isCreditLine(firstTime, plainBody)) {
            continue;
        }

        for (const auto& m : matches) {
            const qreal t = m.captured(1).toInt() * 60.0 + m.captured(2).toDouble();
            LyricLine line;
            line.time = t;
            line.text = plainBody;
            if (matches.size() == 1 || qFuzzyCompare(t + 1.0, firstTime + 1.0)) {
                line.words = parsedWords;
            }
            result.append(std::move(line));
        }
    }

    std::ranges::sort(result, [](const LyricLine& a, const LyricLine& b) {
        return a.time < b.time;
    });

    return result;
}

QVector<LyricLine> Lyrics::parseYrc(const QString& text) {
    QVector<LyricLine> result;
    if (text.isEmpty()) {
        return result;
    }

    static const QRegularExpression k_lineRe(u"^\\[(\\d+),(\\d+)(?:,\\d+)?\\](.*)$"_s);
    static const QRegularExpression k_wordRe(u"\\((\\d+),(\\d+),\\d+\\)([^\\(]*)"_s);

    const QStringList lines = text.split(u'\n');
    for (const QString& rawLine : lines) {
        const QString trimmed = rawLine.trimmed();
        if (trimmed.isEmpty() || trimmed.startsWith(u'{')) {
            continue;
        }
        const auto lm = k_lineRe.match(trimmed);
        if (!lm.hasMatch()) {
            continue;
        }

        const qreal lineStart = lm.captured(1).toDouble() / 1000.0;
        const qreal lineDur = lm.captured(2).toDouble() / 1000.0;
        const QString rest = lm.captured(3);

        QVector<LyricSyllable> words;
        auto wit = k_wordRe.globalMatch(rest);
        while (wit.hasNext()) {
            const auto wm = wit.next();
            const qreal wStart = wm.captured(1).toDouble() / 1000.0;
            const qreal wDur = wm.captured(2).toDouble() / 1000.0;
            const QString wRaw = wm.captured(3);
            const bool trail = wRaw.endsWith(u' ') || wRaw.endsWith(u'\t');
            const QString wClean = wRaw.trimmed();
            if (wClean.isEmpty()) {
                if (trail && !words.isEmpty()) {
                    words.last().trailingSpace = true;
                }
                continue;
            }
            words.append(LyricSyllable{
                .start = wStart,
                .end = wStart + std::max(0.05, wDur),
                .text = wClean,
                .trailingSpace = trail,
            });
        }

        const QString lineText = words.isEmpty() ? rest.trimmed() : joinSyllablesText(words);
        if (isCreditLine(lineStart, lineText)) {
            continue;
        }

        LyricLine line;
        line.time = lineStart;
        line.endTime = lineStart + std::max(0.1, lineDur);
        line.text = lineText;
        line.words = std::move(words);
        result.append(std::move(line));
    }

    std::ranges::sort(result, [](const LyricLine& a, const LyricLine& b) {
        return a.time < b.time;
    });
    return result;
}

QVector<LyricLine> Lyrics::parseTtml(const QString& xml) {
    QVector<LyricLine> result;
    if (xml.isEmpty()) {
        return result;
    }

    QXmlStreamReader xr(xml);
    QHash<QString, QString> translationsByKey;
    QHash<QString, QString> translitsByKey;

    bool inTranslations = false;
    bool inTransliterations = false;
    bool inP = false;
    int bgDepth = 0;
    int transDepth = 0;
    int romanDepth = 0;

    struct SpanFrame {
        bool isTimed = false;
        bool isBg = false;
        bool isTrans = false;
        bool isRoman = false;
        qreal start = 0.0;
        qreal end = 0.0;
        QString text;
    };
    QList<SpanFrame> spanStack;

    LyricLine curLine;
    QString curLineKey;
    QString curLinePlainText;
    QString curInlineTrans;
    QString curInlineRoman;
    QString curMetaForKey;
    QString curMetaText;
    bool capturingMetaText = false;

    while (!xr.atEnd()) {
        const auto token = xr.readNext();
        if (token == QXmlStreamReader::StartElement) {
            const QStringView name = xr.name();
            const auto attrs = xr.attributes();

            if (name == u"translations"_s) {
                inTranslations = true;
            } else if (name == u"transliterations"_s) {
                inTransliterations = true;
            } else if ((inTranslations || inTransliterations) && name == u"text"_s) {
                curMetaForKey = attrs.value(u"for"_s).toString();
                curMetaText.clear();
                capturingMetaText = !curMetaForKey.isEmpty();
            } else if (name == u"p"_s) {
                inP = true;
                bgDepth = 0;
                transDepth = 0;
                romanDepth = 0;
                spanStack.clear();
                curLine = LyricLine{};
                curLinePlainText.clear();
                curInlineTrans.clear();
                curInlineRoman.clear();

                const qreal pBegin = parseTtmlTime(attrs.value(u"begin"_s).toString());
                const qreal pEnd = parseTtmlTime(attrs.value(u"end"_s).toString());
                curLine.time = pBegin >= 0.0 ? pBegin : 0.0;
                curLine.endTime = pEnd >= 0.0 ? pEnd : curLine.time;
                curLine.agent = attrs.value(u"ttm:agent"_s).toString();
                if (curLine.agent.isEmpty()) {
                    curLine.agent = attrs.value(u"agent"_s).toString();
                }
                curLineKey = attrs.value(u"itunes:key"_s).toString();
                if (curLineKey.isEmpty()) {
                    curLineKey = attrs.value(u"key"_s).toString();
                }
            } else if (inP && name == u"span"_s) {
                const QString role = attrs.value(u"ttm:role"_s).toString().isEmpty()
                                         ? attrs.value(u"role"_s).toString()
                                         : attrs.value(u"ttm:role"_s).toString();
                const qreal sBegin = parseTtmlTime(attrs.value(u"begin"_s).toString());
                const qreal sEnd = parseTtmlTime(attrs.value(u"end"_s).toString());

                SpanFrame frame;
                frame.isBg = (role == u"x-bg"_s);
                frame.isTrans = (role == u"x-translation"_s);
                frame.isRoman = (role == u"x-roman"_s);
                frame.isTimed = (sBegin >= 0.0) && !frame.isTrans && !frame.isRoman;
                frame.start = sBegin;
                frame.end = sEnd >= sBegin ? sEnd : (sBegin + 0.4);

                if (frame.isBg) {
                    ++bgDepth;
                }
                if (frame.isTrans) {
                    ++transDepth;
                }
                if (frame.isRoman) {
                    ++romanDepth;
                }
                spanStack.append(frame);
            }
        } else if (token == QXmlStreamReader::Characters) {
            const QString txt = xr.text().toString();
            if (capturingMetaText) {
                curMetaText.append(txt);
            } else if (inP) {
                if (!spanStack.isEmpty()) {
                    if (transDepth > 0) {
                        curInlineTrans.append(txt);
                    } else if (romanDepth > 0) {
                        curInlineRoman.append(txt);
                    } else if (spanStack.last().isTimed) {
                        spanStack.last().text.append(txt);
                    } else {
                        // Direct characters inside wrapper span (e.g. space between timed spans inside x-bg)
                        if (txt.trimmed().isEmpty() && !txt.isEmpty()) {
                            auto& target = (bgDepth > 0) ? curLine.bgWords : curLine.words;
                            if (!target.isEmpty()) {
                                target.last().trailingSpace = true;
                            }
                        }
                    }
                } else {
                    if (txt.trimmed().isEmpty() && !txt.isEmpty()) {
                        if (!curLine.words.isEmpty()) {
                            curLine.words.last().trailingSpace = true;
                        }
                    } else if (!txt.trimmed().isEmpty()) {
                        curLinePlainText.append(txt);
                    }
                }
            }
        } else if (token == QXmlStreamReader::EndElement) {
            const QStringView name = xr.name();
            if (name == u"translations"_s) {
                inTranslations = false;
            } else if (name == u"transliterations"_s) {
                inTransliterations = false;
            } else if ((inTranslations || inTransliterations) && name == u"text"_s) {
                if (capturingMetaText && !curMetaForKey.isEmpty() && !curMetaText.trimmed().isEmpty()) {
                    if (inTranslations) {
                        translationsByKey.insert(curMetaForKey, curMetaText.trimmed());
                    } else {
                        translitsByKey.insert(curMetaForKey, curMetaText.trimmed());
                    }
                }
                capturingMetaText = false;
                curMetaForKey.clear();
                curMetaText.clear();
            } else if (inP && name == u"span"_s && !spanStack.isEmpty()) {
                const SpanFrame popped = spanStack.takeLast();
                if (popped.isTimed) {
                    const bool trail = popped.text.endsWith(u' ') || popped.text.endsWith(u'\t');
                    const QString clean = popped.text.trimmed();
                    if (!clean.isEmpty()) {
                        LyricSyllable syl{
                            .start = popped.start,
                            .end = std::max(popped.start + 0.04, popped.end),
                            .text = clean,
                            .trailingSpace = trail,
                        };
                        if (bgDepth > 0) {
                            curLine.bgWords.append(syl);
                        } else {
                            curLine.words.append(syl);
                        }
                    } else if (trail) {
                        auto& target = (bgDepth > 0) ? curLine.bgWords : curLine.words;
                        if (!target.isEmpty()) {
                            target.last().trailingSpace = true;
                        }
                    }
                }
                if (popped.isBg && bgDepth > 0) {
                    --bgDepth;
                }
                if (popped.isTrans && transDepth > 0) {
                    --transDepth;
                }
                if (popped.isRoman && romanDepth > 0) {
                    --romanDepth;
                }
            } else if (inP && name == u"p"_s) {
                inP = false;
                stripOuterParens(curLine.bgWords);
                curLine.bgText = joinSyllablesText(curLine.bgWords);
                curLine.text = curLine.words.isEmpty() ? curLinePlainText.trimmed() : joinSyllablesText(curLine.words);
                curLine.translation = !curInlineTrans.trimmed().isEmpty()
                                          ? curInlineTrans.trimmed()
                                          : translationsByKey.value(curLineKey);
                curLine.romanization = !curInlineRoman.trimmed().isEmpty()
                                           ? curInlineRoman.trimmed()
                                           : translitsByKey.value(curLineKey);

                if (!curLine.text.isEmpty() || !curLine.bgText.isEmpty()) {
                    result.append(std::move(curLine));
                }
            }
        }
    }

    // Second pass in case <iTunesMetadata> translations appeared after or before body (already before, safe fallback)
    for (LyricLine& l : result) {
        if (l.endTime <= l.time && !l.words.isEmpty()) {
            l.endTime = l.words.last().end;
        }
    }

    std::ranges::sort(result, [](const LyricLine& a, const LyricLine& b) {
        return a.time < b.time;
    });
    return result;
}

QVector<LyricLine> Lyrics::parseLyricsPlusJson(const QByteArray& raw, QString* outSourceDetail) {
    QVector<LyricLine> result;
    const QJsonDocument doc = QJsonDocument::fromJson(raw);
    if (!doc.isObject()) {
        return result;
    }
    const QJsonObject rootObj = doc.object();
    if (outSourceDetail) {
        *outSourceDetail = rootObj.value(u"metadata"_s).toObject().value(u"source"_s).toString();
    }

    const QJsonArray arr = rootObj.value(u"lyrics"_s).toArray();
    result.reserve(arr.size());

    for (const auto& v : arr) {
        const QJsonObject o = v.toObject();
        const qreal t = o.value(u"time"_s).toDouble() / 1000.0;
        const qreal dur = o.value(u"duration"_s).toDouble() / 1000.0;
        const QJsonObject elem = o.value(u"element"_s).toObject();
        const bool lineIsBg = elem.value(u"isBackground"_s).toBool(false);

        LyricLine line;
        line.time = t;
        line.endTime = t + std::max(0.1, dur);
        line.agent = elem.value(u"singer"_s).toString();
        line.translation = o.value(u"translation"_s).toString().trimmed();
        line.romanization = o.value(u"transliteration"_s).toString().trimmed();

        const QJsonArray sylArr = o.value(u"syllabus"_s).toArray();
        for (const auto& sv : sylArr) {
            const QJsonObject so = sv.toObject();
            const qreal st = so.value(u"time"_s).toDouble() / 1000.0;
            const qreal sd = so.value(u"duration"_s).toDouble() / 1000.0;
            const QString sRaw = so.value(u"text"_s).toString();
            const bool trail = sRaw.endsWith(u' ') || sRaw.endsWith(u'\t');
            const QString clean = sRaw.trimmed();
            const bool isBg = lineIsBg || so.value(u"isBackground"_s).toBool(false);

            auto& target = isBg ? line.bgWords : line.words;
            if (clean.isEmpty()) {
                if (trail && !target.isEmpty()) {
                    target.last().trailingSpace = true;
                }
                continue;
            }
            target.append(LyricSyllable{
                .start = st,
                .end = st + std::max(0.04, sd),
                .text = clean,
                .trailingSpace = trail,
            });
        }

        stripOuterParens(line.bgWords);
        line.bgText = joinSyllablesText(line.bgWords);
        line.text = line.words.isEmpty() ? o.value(u"text"_s).toString().trimmed() : joinSyllablesText(line.words);

        if (!line.text.isEmpty() || !line.bgText.isEmpty()) {
            result.append(std::move(line));
        }
    }

    std::ranges::sort(result, [](const LyricLine& a, const LyricLine& b) {
        return a.time < b.time;
    });
    return result;
}

QVector<LyricLine> Lyrics::parseNetEaseJson(const QByteArray& raw, bool* outIsWord) {
    const QJsonDocument doc = QJsonDocument::fromJson(raw);
    const QJsonObject obj = doc.object();

    QVector<LyricLine> mainLines;
    bool isWord = false;

    const QString yrcText = obj.value(u"yrc"_s).toObject().value(u"lyric"_s).toString();
    if (!yrcText.isEmpty()) {
        mainLines = parseYrc(yrcText);
        if (!mainLines.isEmpty()) {
            isWord = std::ranges::any_of(mainLines, [](const LyricLine& l) { return !l.words.isEmpty(); });
        }
    }

    if (mainLines.isEmpty()) {
        const QString lrcText = obj.value(u"lrc"_s).toObject().value(u"lyric"_s).toString();
        if (!lrcText.isEmpty()) {
            mainLines = parseLrc(lrcText);
        }
    }

    if (!mainLines.isEmpty()) {
        const QString transText = obj.value(u"ytlrc"_s).toObject().value(u"lyric"_s).toString().isEmpty()
                                      ? obj.value(u"tlyric"_s).toObject().value(u"lyric"_s).toString()
                                      : obj.value(u"ytlrc"_s).toObject().value(u"lyric"_s).toString();
        const QString romaText = obj.value(u"yromalrc"_s).toObject().value(u"lyric"_s).toString().isEmpty()
                                     ? obj.value(u"romalrc"_s).toObject().value(u"lyric"_s).toString()
                                     : obj.value(u"yromalrc"_s).toObject().value(u"lyric"_s).toString();
        if (!transText.isEmpty()) {
            mergeTimedNotes(mainLines, parseLrc(transText), true);
        }
        if (!romaText.isEmpty()) {
            mergeTimedNotes(mainLines, parseLrc(romaText), false);
        }
    }

    if (outIsWord) {
        *outIsWord = isWord;
    }
    return mainLines;
}

QVariantList Lyrics::buildRichLines(const QVector<LyricLine>& lines) {
    QVariantList out;
    out.reserve(lines.size());
    for (const LyricLine& l : lines) {
        QVariantMap m;
        m.insert(u"time"_s, l.time);
        m.insert(u"endTime"_s, l.endTime);
        m.insert(u"text"_s, l.text);
        m.insert(u"isWordSynced"_s, !l.words.isEmpty());
        m.insert(u"groups"_s, buildGroupsVariant(l.words));
        m.insert(u"bgGroups"_s, buildGroupsVariant(l.bgWords));
        m.insert(u"bgText"_s, l.bgText);
        m.insert(u"translation"_s, l.translation);
        m.insert(u"romanization"_s, l.romanization);
        m.insert(u"agent"_s, l.agent);
        m.insert(u"oppositeTurn"_s, l.oppositeTurn);
        out.append(m);
    }
    return out;
}

} // namespace caelestia::shell::services

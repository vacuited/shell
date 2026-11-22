#pragma once

#include <qhash.h>
#include <qjsonobject.h>
#include <qnetworkaccessmanager.h>
#include <qnetworkreply.h>
#include <qpointer.h>
#include <qtimer.h>
#include <qvariant.h>

#include "lyriccandidate.hpp"

namespace caelestia::shell::services {

struct LyricSyllable {
    qreal start = 0.0;
    qreal end = 0.0;
    QString text;
    bool trailingSpace = false;
};

struct LyricLine {
    qreal time = 0.0;
    qreal endTime = 0.0;
    QString text;
    QVector<LyricSyllable> words;
    QVector<LyricSyllable> bgWords;
    QString bgText;
    QString translation;
    QString romanization;
    QString agent;
    bool oppositeTurn = false;
};

class Lyrics : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(QStringList lyrics READ lyrics NOTIFY lyricsChanged)
    Q_PROPERTY(QVariantList richLines READ richLines NOTIFY lyricsChanged)
    Q_PROPERTY(bool isWordSynced READ isWordSynced NOTIFY lyricsChanged)
    Q_PROPERTY(bool hasTranslation READ hasTranslation NOTIFY lyricsChanged)
    Q_PROPERTY(bool hasRomanization READ hasRomanization NOTIFY lyricsChanged)
    Q_PROPERTY(caelestia::shell::config::LyricsBackend::Enum backend READ backend NOTIFY backendChanged)
    Q_PROPERTY(caelestia::shell::config::LyricsBackend::Enum preferredBackend READ preferredBackend WRITE
            setPreferredBackend NOTIFY preferredBackendChanged)
    Q_PROPERTY(QList<caelestia::shell::services::LyricCandidate> lyricCandidates READ lyricCandidates NOTIFY
            lyricCandidatesChanged)
    Q_PROPERTY(caelestia::shell::services::LyricCandidate selectedCandidate READ selectedCandidate WRITE
            setSelectedCandidate NOTIFY selectedCandidateChanged)
    Q_PROPERTY(bool manualSource READ manualSource NOTIFY sourceStateChanged)
    Q_PROPERTY(QVariantList providerStates READ providerStates NOTIFY providerStatesChanged)
    Q_PROPERTY(bool loading READ loading NOTIFY loadingChanged)
    Q_PROPERTY(bool hasLyrics READ hasLyrics NOTIFY hasLyricsChanged)
    Q_PROPERTY(qreal offset READ offset WRITE setOffset NOTIFY offsetChanged)
    Q_PROPERTY(QString trackArtist READ trackArtist NOTIFY trackChanged)
    Q_PROPERTY(QString trackTitle READ trackTitle NOTIFY trackChanged)

public:
    explicit Lyrics(QObject* parent = nullptr);

    [[nodiscard]] QStringList lyrics() const;
    [[nodiscard]] QVariantList richLines() const;
    [[nodiscard]] bool isWordSynced() const;
    [[nodiscard]] bool hasTranslation() const;
    [[nodiscard]] bool hasRomanization() const;
    [[nodiscard]] LyricsBackend backend() const;
    [[nodiscard]] LyricsBackend preferredBackend() const;
    void setPreferredBackend(LyricsBackend value);
    [[nodiscard]] QList<LyricCandidate> lyricCandidates() const;
    [[nodiscard]] LyricCandidate selectedCandidate() const;
    void setSelectedCandidate(const LyricCandidate& value);
    [[nodiscard]] bool manualSource() const;
    [[nodiscard]] QVariantList providerStates() const;
    [[nodiscard]] bool loading() const;
    [[nodiscard]] bool hasLyrics() const;
    [[nodiscard]] qreal offset() const;
    void setOffset(qreal value);
    [[nodiscard]] QString trackArtist() const;
    [[nodiscard]] QString trackTitle() const;

    [[nodiscard]] Q_INVOKABLE int indexForTime(qreal time) const;
    [[nodiscard]] Q_INVOKABLE qreal timeForIndex(int index) const;
    [[nodiscard]] Q_INVOKABLE QVariantMap instrumentalGapAt(qreal time) const;

    Q_INVOKABLE void selectProvider(int backendEnum);
    Q_INVOKABLE void setTrack(
        const QString& artist, const QString& title, const QString& album = {}, qreal duration = 0.0);
    Q_INVOKABLE void clearTrack();
    Q_INVOKABLE void refresh();

signals:
    void lyricsChanged();
    void backendChanged();
    void preferredBackendChanged();
    void lyricCandidatesChanged();
    void selectedCandidateChanged();
    void sourceStateChanged();
    void providerStatesChanged();
    void loadingChanged();
    void hasLyricsChanged();
    void offsetChanged();
    void trackChanged();

private:
    struct ProviderEntry {
        QString status = QStringLiteral("idle"); // idle | loading | ready | not_found | error
        QVector<LyricLine> lines;
        LyricCandidate candidate;
        QString detail;
        bool hasWordSync = false;
        bool hasTranslation = false;
        bool hasRomanization = false;
    };

    void setBackend(LyricsBackend value);
    void setLoading(bool value);
    void setManualSource(bool value);
    void setLines(QVector<LyricLine> lines, LyricsBackend source);
    void clearLines();
    void appendCandidates(const QList<LyricCandidate>& add);
    void clearCandidates();

    void resetProviderStates(bool markOnlineLoading);
    void updateProviderEntry(LyricsBackend backend, const ProviderEntry& entry);
    void evaluateSelection(int reqId, bool graceExpired = false);
    void applyProviderResult(LyricsBackend backend, const ProviderEntry& entry);
    [[nodiscard]] int scoreProvider(LyricsBackend backend, const ProviderEntry& entry) const;
    [[nodiscard]] bool anyWordCapableLoading() const;
    [[nodiscard]] bool anyProviderLoading() const;

    void scheduleLoad();
    void doLoad();
    void cancelInFlight();
    int newRequestId();

    void runLocalLookup();
    void fetchBoidu(int reqId, const QString& artistOverride = {}, bool isRetry = false);
    void fetchLyricsPlus(int reqId, int mirrorIdx = 0, const QString& artistOverride = {}, bool isRetry = false);
    void fetchLrclib(int reqId);
    void fetchNetEase(int reqId);

    void searchLrclibCandidates(int reqId);
    void searchNetEaseCandidates(int reqId);

    void fetchLrclibById(const QString& id, int reqId);
    void fetchNetEaseLyricsById(const QString& id, int reqId, bool selectAfterLoad = false);

    QNetworkReply* getJson(
        const QUrl& url, const QHash<QByteArray, QByteArray>& headers = {}, bool noCookies = false);
    void trackReply(int reqId, QNetworkReply* reply);

    void onPreferredBackendConfigChanged();
    void onLyricsDirChanged();

    void loadLyricsMap();
    void persistTrackPrefs();

    [[nodiscard]] static QString lyricsDir();
    [[nodiscard]] static QString lyricsMapPath();
    [[nodiscard]] QString trackKey() const;
    [[nodiscard]] QString providerCacheKey() const;
    [[nodiscard]] static QString backendKey(LyricsBackend value);
    [[nodiscard]] static QString backendLabel(LyricsBackend value);
    [[nodiscard]] static LyricsBackend backendFromKey(const QString& key);

    [[nodiscard]] static const QString& stateDir();
    [[nodiscard]] static const QString& cacheDir();
    [[nodiscard]] static QString cachePathFor(LyricsBackend backend, const QString& id);
    [[nodiscard]] static QString readCachedPayload(LyricsBackend backend, const QString& id);
    static void writeCachedPayload(LyricsBackend backend, const QString& id, const QString& text);

    [[nodiscard]] static QString cleanArtistQuery(const QString& artist);
    [[nodiscard]] static QString primaryArtistQuery(const QString& artist);
    [[nodiscard]] static QString cleanTitleQuery(const QString& title);

    [[nodiscard]] static QVector<LyricLine> parseLrc(const QString& text);
    [[nodiscard]] static QVector<LyricLine> parseYrc(const QString& text);
    [[nodiscard]] static QVector<LyricLine> parseTtml(const QString& xml);
    [[nodiscard]] static QVector<LyricLine> parseLyricsPlusJson(
        const QByteArray& raw, QString* outSourceDetail = nullptr);
    [[nodiscard]] static QVector<LyricLine> parseNetEaseJson(const QByteArray& raw, bool* outIsWord = nullptr);
    [[nodiscard]] static QVector<LyricLine> parseLocalFile(const QString& path);
    [[nodiscard]] static QString findLocalLyricsFile(const QString& dir, const QString& artist, const QString& title);

    [[nodiscard]] static QVariantList buildRichLines(const QVector<LyricLine>& lines);

    QNetworkAccessManager* m_nam;
    QTimer* m_loadDebounce;
    QTimer* m_autoGraceTimer;

    QVector<LyricLine> m_lines;
    QStringList m_lyrics;
    QVariantList m_richLines;
    bool m_isWordSynced = false;
    bool m_hasTranslation = false;
    bool m_hasRomanization = false;

    LyricsBackend m_backend = LyricsBackend::Auto;
    LyricsBackend m_preferredBackend = LyricsBackend::Auto;
    QList<LyricCandidate> m_candidates;
    LyricCandidate m_selected;
    bool m_manualSource = false;
    bool m_loading = false;
    bool m_hasLyrics = false;
    qreal m_offset = 0.0;

    QString m_artist;
    QString m_title;
    QString m_album;
    qreal m_duration = 0.0;

    int m_currentRequestId = 0;
    QHash<int, QList<QPointer<QNetworkReply>>> m_pendingReplies;
    QHash<LyricsBackend, ProviderEntry> m_providerResults;
    LyricsBackend m_pinnedProvider = LyricsBackend::Auto;
    bool m_appliedGraceOrFinal = false;

    QJsonObject m_lyricsMap;
    bool m_lyricsMapLoaded = false;
    bool m_settingFromPrefs = false;
};

} // namespace caelestia::shell::services

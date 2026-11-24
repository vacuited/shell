#include "visualiserview.hpp"

#include <qquickwindow.h>
#include <qsggeometry.h>

#include <algorithm>
#include <cmath>
#include <cstring>

namespace caelestia::shell::components {

using Qt::StringLiterals::operator""_s;

namespace {

constexpr qreal k_liveThreshold = 0.015;
constexpr qreal k_fadeInvisible = 0.001;

bool fuzzyFloatArrayEqual(const float* a, const float* b, int count) {
    for (int i = 0; i < count; ++i) {
        if (!qFuzzyCompare(a[i] + 1.0f, b[i] + 1.0f))
            return false;
    }
    return true;
}

void writeColor(float out[4], const QColor& c) {
    out[0] = static_cast<float>(c.redF());
    out[1] = static_cast<float>(c.greenF());
    out[2] = static_cast<float>(c.blueF());
    out[3] = static_cast<float>(c.alphaF());
}

QString shaderPathForStyle(VisualiserView::Style style) {
    switch (style) {
    case VisualiserView::Style::Aurora:
        return u":/shaders/visualiser_aurora.frag.qsb"_s;
    case VisualiserView::Style::Bars:
        return u":/shaders/visualiser_bars.frag.qsb"_s;
    case VisualiserView::Style::Wave:
        return u":/shaders/visualiser_wave.frag.qsb"_s;
    case VisualiserView::Style::Dots:
        return u":/shaders/visualiser_dots.frag.qsb"_s;
    case VisualiserView::Style::Glow:
        return u":/shaders/visualiser_glow.frag.qsb"_s;
    }
    return u":/shaders/visualiser_aurora.frag.qsb"_s;
}

} // namespace

VisualiserView::VisualiserView(QQuickItem* parent)
    : QQuickItem(parent)
    , m_style(u"aurora"_s)
    , m_position(u"bottom"_s)
    , m_layout(u"split"_s)
    , m_gradientMode(u"tritone"_s)
    , m_idleMode(u"ambient"_s) {
    setFlag(ItemHasContents);
    m_dataImage = QImage(1, 1, QImage::Format_RGBA8888_Premultiplied);
    m_dataImage.fill(Qt::transparent);
}

void VisualiserView::wakeUp() {
    if (m_settled) {
        m_settled = false;
        emit settledChanged();
    }
    update();
}

void VisualiserView::setIdle(bool idle) {
    if (m_idle == idle)
        return;
    m_idle = idle;
    emit idleChanged();
}

void VisualiserView::setFadedOut(bool fadedOut) {
    if (m_fadedOut == fadedOut)
        return;
    m_fadedOut = fadedOut;
    emit fadedOutChanged();
}

void VisualiserView::triggerBeat(qreal bpm) {
    Q_UNUSED(bpm);
    if (m_fadedOut || m_idle)
        return;
    const qreal strength = std::clamp(m_beatReactivity, 0.0, 1.0);
    if (strength <= 0.001)
        return;

    m_beatEnergy = std::max(m_beatEnergy, strength);
    m_silenceSec = 0.0;
    wakeUp();
}

void VisualiserView::advance(qreal dt) {
    if (m_settled)
        return;

    const qreal clampedDt = std::clamp(dt, 0.0005, 0.1);
    const qreal dtMs = clampedDt * 1000.0;
    m_timeSec += clampedDt;

    const qsizetype count = m_targetValues.size();
    if (m_displayValues.size() != count) {
        m_displayValues.resize(count, 0.0);
        m_peakValues.resize(count, 0.0);
        m_peakHoldTimers.resize(count, 0.0);
        m_peakVelocities.resize(count, 0.0);
        m_sparkValues.resize(count, 0.0);
    }

    qreal maxInput = 0.0;
    for (qsizetype i = 0; i < count; ++i)
        maxInput = std::max(maxInput, m_targetValues[i]);

    const bool liveActive = maxInput > k_liveThreshold;
    const bool usePreviewSynth = m_previewMode && !liveActive;

    // Detect sub-bass transient kicks when live audio is active
    qreal bassSum = 0.0;
    const qsizetype bassBins = std::min<qsizetype>(count, 4);
    if (bassBins > 0) {
        for (qsizetype i = 0; i < bassBins; ++i)
            bassSum += m_targetValues[i];
        bassSum /= static_cast<qreal>(bassBins);
    }
    const qreal bassDelta = bassSum - m_prevBass;
    m_prevBass = bassSum;
    if (liveActive && bassDelta > 0.08 && m_beatReactivity > 0.001) {
        m_beatEnergy = std::max(m_beatEnergy, std::clamp(bassDelta * 3.2, 0.0, 1.0) * m_beatReactivity);
    }
    m_beatEnergy *= std::exp(-dtMs / 140.0);
    if (m_beatEnergy < 0.001)
        m_beatEnergy = 0.0;

    // Silence / idle tracking
    if (liveActive || usePreviewSynth) {
        m_silenceSec = 0.0;
        m_idleFactor = std::max(0.0, m_idleFactor - clampedDt / 0.25);
    } else {
        m_silenceSec += clampedDt;
        if (m_silenceSec >= m_idleTimeout) {
            m_idleFactor = std::min(1.0, m_idleFactor + clampedDt / 1.2);
        }
    }
    const bool idleNow = !liveActive && !usePreviewSynth && (m_silenceSec >= m_idleTimeout);
    setIdle(idleNow);

    // Idle fade opacity
    const bool isFadeMode = (m_idleMode == u"fade"_s);
    const qreal targetFade = (isFadeMode && idleNow) ? 0.0 : 1.0;
    const qreal fadeTau = targetFade < m_fadeOpacity ? 450.0 : 180.0;
    m_fadeOpacity += (targetFade - m_fadeOpacity) * (1.0 - std::exp(-dtMs / fadeTau));
    if (std::abs(targetFade - m_fadeOpacity) < 0.002)
        m_fadeOpacity = targetFade;

    const bool fadedNow = isFadeMode && idleNow && (m_fadeOpacity <= k_fadeInvisible);
    if (fadedNow) {
        m_fadeOpacity = 0.0;
        m_beatEnergy = 0.0;
        m_prevBass = 0.0;
        std::fill(m_displayValues.begin(), m_displayValues.end(), 0.0);
        std::fill(m_peakValues.begin(), m_peakValues.end(), 0.0);
        std::fill(m_peakHoldTimers.begin(), m_peakHoldTimers.end(), 0.0);
        std::fill(m_peakVelocities.begin(), m_peakVelocities.end(), 0.0);
        std::fill(m_sparkValues.begin(), m_sparkValues.end(), 0.0);

        const bool justFaded = !m_fadedOut;
        setFadedOut(true);
        if (justFaded)
            update();
        if (!m_settled) {
            m_settled = true;
            emit settledChanged();
        }
        return;
    }
    setFadedOut(false);

    const qreal attackTau = std::max(5.0, static_cast<qreal>(m_attackMs) / 3.0);
    const qreal decayTau = std::max(10.0, static_cast<qreal>(m_decayMs) / 3.0);
    const qreal attackAlpha = 1.0 - std::exp(-dtMs / attackTau);
    const qreal decayAlpha = 1.0 - std::exp(-dtMs / decayTau);
    const qreal sens = std::max(0.0, m_sensitivity);

    qreal maxDisplay = 0.0;
    qreal maxPeak = 0.0;
    qreal maxSpark = 0.0;

    for (qsizetype i = 0; i < count; ++i) {
        qreal raw = m_targetValues[i];
        if (usePreviewSynth) {
            const qreal u = count > 1 ? static_cast<qreal>(i) / static_cast<qreal>(count - 1) : 0.0;
            const qreal waveA = 0.5 + 0.5 * std::sin(u * 9.0 - m_timeSec * 2.4);
            const qreal waveB = 0.5 + 0.5 * std::cos(u * 17.0 + m_timeSec * 3.7);
            const qreal env = 0.35 + 0.65 * std::exp(-u * 1.4);
            raw = std::clamp((0.28 * waveA + 0.24 * waveB + 0.14) * env, 0.0, 1.0);
        }

        const qreal gained = (raw > 0.0 && sens > 0.0) ? std::clamp(std::pow(raw * sens, 0.92), 0.0, 1.0) : 0.0;
        const qreal diff = gained - m_displayValues[i];
        const qreal alpha = diff > 0.0 ? attackAlpha : decayAlpha;

        if (std::abs(diff) > 0.0005) {
            m_displayValues[i] += diff * alpha;
        } else {
            m_displayValues[i] = gained;
        }

        const qreal val = m_displayValues[i];
        maxDisplay = std::max(maxDisplay, val);

        // Peak-hold + gravity drop
        if (val >= m_peakValues[i]) {
            m_peakValues[i] = val;
            m_peakHoldTimers[i] = 0.20;
            m_peakVelocities[i] = 0.0;
        } else if (m_peakHoldTimers[i] > 0.0) {
            m_peakHoldTimers[i] -= clampedDt;
        } else {
            m_peakVelocities[i] += 1.6 * clampedDt;
            m_peakValues[i] = std::max(val, m_peakValues[i] - m_peakVelocities[i] * clampedDt);
        }
        maxPeak = std::max(maxPeak, m_peakValues[i]);

        // Transient onset spark
        const qreal sparkTarget = diff > 0.0 ? std::clamp(diff * 2.5, 0.0, 1.0) : 0.0;
        m_sparkValues[i] += (sparkTarget - m_sparkValues[i]) * (1.0 - std::exp(-dtMs / 90.0));
        if (m_sparkValues[i] < 0.0005 && sparkTarget <= 0.0)
            m_sparkValues[i] = 0.0;
        maxSpark = std::max(maxSpark, m_sparkValues[i]);
    }

    rebuildDataImage();
    update();

    const bool ambientActive = (m_idleMode == u"ambient"_s);
    const bool fadeComplete = isFadeMode
        ? (m_silenceSec >= m_idleTimeout && m_fadeOpacity < 0.002)
        : (std::abs(m_fadeOpacity - targetFade) < 0.002);
    const bool canSettle = !ambientActive && !usePreviewSynth && !liveActive && maxDisplay < 0.001 &&
                           maxPeak < 0.001 && maxSpark < 0.001 && m_beatEnergy < 0.001 && fadeComplete;
    if (canSettle && !m_settled) {
        m_settled = true;
        emit settledChanged();
    }
}

void VisualiserView::rebuildDataImage() {
    const int n = std::max(1, static_cast<int>(m_displayValues.size()));
    if (m_dataImage.width() != n || m_dataImage.height() != 1 || m_dataImage.format() != QImage::Format_RGBA8888_Premultiplied) {
        m_dataImage = QImage(n, 1, QImage::Format_RGBA8888_Premultiplied);
    }

    auto* const pixels = m_dataImage.bits();
    if (m_displayValues.isEmpty()) {
        std::memset(pixels, 0, 4);
    } else {
        for (int i = 0; i < n; ++i) {
            const double val = std::clamp(m_displayValues[i], 0.0, 1.0);
            const double peak = std::clamp(m_peakValues[i], 0.0, 1.0);
            const double spark = std::clamp(m_sparkValues[i], 0.0, 1.0);

            const int q = static_cast<int>(std::lround(val * 65025.0));
            const int offset = i * 4;
            pixels[offset + 0] = static_cast<uchar>((q >> 8) & 0xFF);
            pixels[offset + 1] = static_cast<uchar>(q & 0xFF);
            pixels[offset + 2] = static_cast<uchar>(std::lround(peak * 255.0));
            pixels[offset + 3] = static_cast<uchar>(std::lround(spark * 255.0));
        }
    }

    m_dataDirty = true;
}

VisualiserView::Style VisualiserView::resolveStyle() const {
    if (m_style == u"bars"_s)
        return Style::Bars;
    if (m_style == u"wave"_s)
        return Style::Wave;
    if (m_style == u"dots"_s)
        return Style::Dots;
    if (m_style == u"glow"_s)
        return Style::Glow;
    return Style::Aurora;
}

int VisualiserView::resolveEdgeIndex() const {
    if (m_position == u"top"_s)
        return 1;
    if (m_position == u"left"_s)
        return 2;
    if (m_position == u"right"_s)
        return 3;
    if (m_position == u"center"_s)
        return 4;
    return 0; // bottom
}

int VisualiserView::resolveGradientIndex() const {
    if (m_gradientMode == u"vertical"_s)
        return 1;
    if (m_gradientMode == u"horizontal"_s)
        return 2;
    if (m_gradientMode == u"amplitude"_s)
        return 3;
    return 0; // tritone
}

void VisualiserView::resolveStyleOptionFloats(Style styleEnum, float out[4]) const {
    out[0] = 0.0f;
    out[1] = 0.0f;
    out[2] = 0.0f;
    out[3] = 0.0f;

    switch (styleEnum) {
    case Style::Aurora:
        out[0] = std::clamp(static_cast<float>(m_styleOptions.value(u"auroraLayers"_s, 3.0).toDouble()), 2.0f, 4.0f);
        out[1] = std::clamp(static_cast<float>(m_styleOptions.value(u"auroraSpeed"_s, 0.85).toDouble()), 0.2f, 2.5f);
        out[2] = std::clamp(static_cast<float>(m_styleOptions.value(u"auroraShimmer"_s, 0.65).toDouble()), 0.0f, 1.0f);
        break;
    case Style::Bars:
        out[0] = m_styleOptions.value(u"peakCaps"_s, true).toBool() ? 1.0f : 0.0f;
        break;
    case Style::Wave:
        out[0] = std::clamp(static_cast<float>(m_styleOptions.value(u"waveLayers"_s, 2.0).toDouble()), 1.0f, 3.0f);
        out[1] = std::clamp(static_cast<float>(m_styleOptions.value(u"waveFill"_s, 0.45).toDouble()), 0.1f, 0.95f);
        out[2] = std::clamp(static_cast<float>(m_styleOptions.value(u"waveCrest"_s, 2.5).toDouble()), 0.5f, 6.0f);
        break;
    case Style::Dots:
        out[0] = std::clamp(static_cast<float>(m_styleOptions.value(u"dotSize"_s, 1.0).toDouble()), 0.4f, 2.5f);
        out[1] = m_styleOptions.value(u"dotTrails"_s, true).toBool() ? 1.0f : 0.0f;
        break;
    case Style::Glow:
        out[0] = std::clamp(static_cast<float>(m_styleOptions.value(u"glowSpread"_s, 0.8).toDouble()), 0.25f, 1.5f);
        out[1] = m_styleOptions.value(u"glowAllEdges"_s, false).toBool() ? 1.0f : 0.0f;
        break;
    }
}

QSGNode* VisualiserView::updatePaintNode(QSGNode* oldNode, UpdatePaintNodeData* data) {
    Q_UNUSED(data);

    if (width() <= 0 || height() <= 0 || !window() || m_fadeOpacity <= k_fadeInvisible) {
        delete oldNode;
        return nullptr;
    }

    const Style currentStyle = resolveStyle();
    auto* node = static_cast<VisualiserNode*>(oldNode);
    if (node && node->style() != currentStyle) {
        delete node;
        node = nullptr;
    }

    if (!node) {
        node = new VisualiserNode(currentStyle);
        m_dataDirty = true;
    }

    QSGGeometry::updateTexturedRectGeometry(node->geometry(), boundingRect(), QRectF(0, 0, 1, 1));
    node->markDirty(QSGNode::DirtyGeometry);

    auto* const material = static_cast<VisualiserMaterial*>(node->material());
    if (m_dataDirty || !material->m_dataTex) {
        if (m_dataImage.isNull()) {
            m_dataImage = QImage(1, 1, QImage::Format_RGBA8888_Premultiplied);
            m_dataImage.fill(Qt::transparent);
        }
        material->m_dataTex.reset(window()->createTextureFromImage(m_dataImage, QQuickWindow::TextureHasAlphaChannel));
        if (material->m_dataTex) {
            material->m_dataTex->setFiltering(QSGTexture::Nearest);
            material->m_dataTex->setHorizontalWrapMode(QSGTexture::ClampToEdge);
            material->m_dataTex->setVerticalWrapMode(QSGTexture::ClampToEdge);
        }
        m_dataDirty = false;
    }

    const float dpr = static_cast<float>(window()->effectiveDevicePixelRatio());
    const float barCount = static_cast<float>(std::max<qsizetype>(1, m_displayValues.size()));

    material->m_fadeOpacity = static_cast<float>(std::clamp(m_fadeOpacity, 0.0, 1.0));
    material->m_dims[0] = static_cast<float>(width());
    material->m_dims[1] = static_cast<float>(height());
    material->m_dims[2] = dpr;
    material->m_dims[3] = static_cast<float>(std::fmod(m_timeSec, 3600.0));

    material->m_params0[0] = barCount;
    material->m_params0[1] = static_cast<float>(std::max(0.0, m_rounding));
    material->m_params0[2] = static_cast<float>(std::max(0.0, m_spacing));
    material->m_params0[3] = static_cast<float>(std::clamp(m_heightScale, 0.1, 0.8));

    material->m_params1[0] = static_cast<float>(resolveEdgeIndex());
    material->m_params1[1] = (m_layout == u"full"_s) ? 1.0f : 0.0f;
    material->m_params1[2] = m_mirrored ? 1.0f : 0.0f;
    material->m_params1[3] = 0.2f;

    material->m_params2[0] = static_cast<float>(resolveGradientIndex());
    material->m_params2[1] = static_cast<float>(std::clamp(m_glow, 0.0, 1.0));
    material->m_params2[2] = static_cast<float>(std::clamp(m_beatEnergy, 0.0, 1.0));
    material->m_params2[3] = (m_idleMode == u"ambient"_s) ? static_cast<float>(std::clamp(m_idleFactor, 0.0, 1.0)) : 0.0f;

    resolveStyleOptionFloats(currentStyle, material->m_styleOpts);
    writeColor(material->m_primaryColor, m_primaryColor);
    writeColor(material->m_secondaryColor, m_secondaryColor);
    writeColor(material->m_accentColor, m_accentColor);

    node->markDirty(QSGNode::DirtyMaterial);
    return node;
}

void VisualiserView::geometryChange(const QRectF& newGeometry, const QRectF& oldGeometry) {
    QQuickItem::geometryChange(newGeometry, oldGeometry);
    if (newGeometry.size() != oldGeometry.size())
        update();
}

void VisualiserView::releaseResources() {
    m_dataDirty = true;
}

QVector<double> VisualiserView::values() const { return m_targetValues; }

void VisualiserView::setValues(const QVector<double>& values) {
    m_targetValues = values;
    if (m_displayValues.size() != values.size()) {
        m_displayValues.resize(values.size(), 0.0);
        m_peakValues.resize(values.size(), 0.0);
        m_peakHoldTimers.resize(values.size(), 0.0);
        m_peakVelocities.resize(values.size(), 0.0);
        m_sparkValues.resize(values.size(), 0.0);
        if (!m_fadedOut)
            rebuildDataImage();
    }
    emit valuesChanged();

    if (m_settled) {
        qreal maxInput = 0.0;
        for (qsizetype i = 0; i < m_targetValues.size(); ++i)
            maxInput = std::max(maxInput, m_targetValues[i]);
        const qreal wakeThreshold = m_fadedOut ? k_liveThreshold : 0.001;
        if (maxInput <= wakeThreshold)
            return;
    }
    wakeUp();
}

QString VisualiserView::style() const { return m_style; }

void VisualiserView::setStyle(const QString& style) {
    if (m_style == style)
        return;
    m_style = style;
    emit styleChanged();
    wakeUp();
}

QString VisualiserView::position() const { return m_position; }

void VisualiserView::setPosition(const QString& position) {
    if (m_position == position)
        return;
    m_position = position;
    emit positionChanged();
    update();
}

QString VisualiserView::layout() const { return m_layout; }

void VisualiserView::setLayout(const QString& layout) {
    if (m_layout == layout)
        return;
    m_layout = layout;
    emit layoutChanged();
    update();
}

bool VisualiserView::mirrored() const { return m_mirrored; }

void VisualiserView::setMirrored(bool mirrored) {
    if (m_mirrored == mirrored)
        return;
    m_mirrored = mirrored;
    emit mirroredChanged();
    update();
}

qreal VisualiserView::heightScale() const { return m_heightScale; }

void VisualiserView::setHeightScale(qreal heightScale) {
    if (qFuzzyCompare(m_heightScale + 1.0, heightScale + 1.0))
        return;
    m_heightScale = heightScale;
    emit heightScaleChanged();
    update();
}

qreal VisualiserView::rounding() const { return m_rounding; }

void VisualiserView::setRounding(qreal rounding) {
    if (qFuzzyCompare(m_rounding + 1.0, rounding + 1.0))
        return;
    m_rounding = rounding;
    emit roundingChanged();
    update();
}

qreal VisualiserView::spacing() const { return m_spacing; }

void VisualiserView::setSpacing(qreal spacing) {
    if (qFuzzyCompare(m_spacing + 1.0, spacing + 1.0))
        return;
    m_spacing = spacing;
    emit spacingChanged();
    update();
}

QString VisualiserView::gradientMode() const { return m_gradientMode; }

void VisualiserView::setGradientMode(const QString& gradientMode) {
    if (m_gradientMode == gradientMode)
        return;
    m_gradientMode = gradientMode;
    emit gradientModeChanged();
    update();
}

QColor VisualiserView::primaryColor() const { return m_primaryColor; }

void VisualiserView::setPrimaryColor(const QColor& color) {
    if (m_primaryColor == color)
        return;
    m_primaryColor = color;
    emit primaryColorChanged();
    update();
}

QColor VisualiserView::secondaryColor() const { return m_secondaryColor; }

void VisualiserView::setSecondaryColor(const QColor& color) {
    if (m_secondaryColor == color)
        return;
    m_secondaryColor = color;
    emit secondaryColorChanged();
    update();
}

QColor VisualiserView::accentColor() const { return m_accentColor; }

void VisualiserView::setAccentColor(const QColor& color) {
    if (m_accentColor == color)
        return;
    m_accentColor = color;
    emit accentColorChanged();
    update();
}

qreal VisualiserView::glow() const { return m_glow; }

void VisualiserView::setGlow(qreal glow) {
    if (qFuzzyCompare(m_glow + 1.0, glow + 1.0))
        return;
    m_glow = glow;
    emit glowChanged();
    update();
}

qreal VisualiserView::sensitivity() const { return m_sensitivity; }

void VisualiserView::setSensitivity(qreal sensitivity) {
    if (qFuzzyCompare(m_sensitivity + 1.0, sensitivity + 1.0))
        return;
    m_sensitivity = sensitivity;
    emit sensitivityChanged();
    wakeUp();
}

int VisualiserView::attackMs() const { return m_attackMs; }

void VisualiserView::setAttackMs(int attackMs) {
    if (m_attackMs == attackMs)
        return;
    m_attackMs = attackMs;
    emit attackMsChanged();
}

int VisualiserView::decayMs() const { return m_decayMs; }

void VisualiserView::setDecayMs(int decayMs) {
    if (m_decayMs == decayMs)
        return;
    m_decayMs = decayMs;
    emit decayMsChanged();
}

qreal VisualiserView::beatReactivity() const { return m_beatReactivity; }

void VisualiserView::setBeatReactivity(qreal beatReactivity) {
    if (qFuzzyCompare(m_beatReactivity + 1.0, beatReactivity + 1.0))
        return;
    m_beatReactivity = beatReactivity;
    emit beatReactivityChanged();
}

QString VisualiserView::idleMode() const { return m_idleMode; }

void VisualiserView::setIdleMode(const QString& idleMode) {
    if (m_idleMode == idleMode)
        return;
    m_idleMode = idleMode;
    emit idleModeChanged();
    wakeUp();
}

qreal VisualiserView::idleTimeout() const { return m_idleTimeout; }

void VisualiserView::setIdleTimeout(qreal idleTimeout) {
    if (qFuzzyCompare(m_idleTimeout + 1.0, idleTimeout + 1.0))
        return;
    m_idleTimeout = idleTimeout;
    emit idleTimeoutChanged();
    wakeUp();
}

QVariantMap VisualiserView::styleOptions() const { return m_styleOptions; }

void VisualiserView::setStyleOptions(const QVariantMap& styleOptions) {
    if (m_styleOptions == styleOptions)
        return;
    m_styleOptions = styleOptions;
    emit styleOptionsChanged();
    update();
}

bool VisualiserView::previewMode() const { return m_previewMode; }

void VisualiserView::setPreviewMode(bool previewMode) {
    if (m_previewMode == previewMode)
        return;
    m_previewMode = previewMode;
    emit previewModeChanged();
    wakeUp();
}

bool VisualiserView::settled() const { return m_settled; }
bool VisualiserView::idle() const { return m_idle; }
bool VisualiserView::fadedOut() const { return m_fadedOut; }

// --- Material & Shader ---

VisualiserMaterial::VisualiserMaterial(VisualiserView::Style style)
    : m_style(style) {}

QSGMaterialType* VisualiserMaterial::type() const {
    static QSGMaterialType s_aurora;
    static QSGMaterialType s_bars;
    static QSGMaterialType s_wave;
    static QSGMaterialType s_dots;
    static QSGMaterialType s_glow;

    switch (m_style) {
    case VisualiserView::Style::Aurora:
        return &s_aurora;
    case VisualiserView::Style::Bars:
        return &s_bars;
    case VisualiserView::Style::Wave:
        return &s_wave;
    case VisualiserView::Style::Dots:
        return &s_dots;
    case VisualiserView::Style::Glow:
        return &s_glow;
    }
    return &s_aurora;
}

QSGMaterialShader* VisualiserMaterial::createShader(QSGRendererInterface::RenderMode mode) const {
    Q_UNUSED(mode);
    return new VisualiserMaterialShader(m_style);
}

int VisualiserMaterial::compare(const QSGMaterial* other) const {
    const auto* const o = static_cast<const VisualiserMaterial*>(other);
    if (m_style != o->m_style)
        return m_style < o->m_style ? -1 : 1;
    if (m_dataTex.data() != o->m_dataTex.data())
        return m_dataTex.data() < o->m_dataTex.data() ? -1 : 1;
    if (!qFuzzyCompare(m_fadeOpacity + 1.0f, o->m_fadeOpacity + 1.0f) ||
        !fuzzyFloatArrayEqual(m_dims, o->m_dims, 4) ||
        !fuzzyFloatArrayEqual(m_params0, o->m_params0, 4) ||
        !fuzzyFloatArrayEqual(m_params1, o->m_params1, 4) ||
        !fuzzyFloatArrayEqual(m_params2, o->m_params2, 4) ||
        !fuzzyFloatArrayEqual(m_styleOpts, o->m_styleOpts, 4) ||
        !fuzzyFloatArrayEqual(m_primaryColor, o->m_primaryColor, 4) ||
        !fuzzyFloatArrayEqual(m_secondaryColor, o->m_secondaryColor, 4) ||
        !fuzzyFloatArrayEqual(m_accentColor, o->m_accentColor, 4)) {
        return this < other ? -1 : 1;
    }
    return 0;
}

VisualiserMaterialShader::VisualiserMaterialShader(VisualiserView::Style style) {
    setShaderFileName(VertexStage, u":/shaders/visualiser.vert.qsb"_s);
    setShaderFileName(FragmentStage, shaderPathForStyle(style));
}

bool VisualiserMaterialShader::updateUniformData(
    RenderState& state, QSGMaterial* newMaterial, QSGMaterial* oldMaterial) {
    Q_UNUSED(oldMaterial);
    const auto* const mat = static_cast<const VisualiserMaterial*>(newMaterial);
    QByteArray* const buf = state.uniformData();
    Q_ASSERT(buf->size() >= 208);

    if (state.isMatrixDirty()) {
        const QMatrix4x4 m = state.combinedMatrix();
        std::memcpy(buf->data(), m.constData(), 64);
    }

    const float opacity = state.opacity() * mat->m_fadeOpacity;
    std::memcpy(buf->data() + 64, &opacity, 4);

    std::memcpy(buf->data() + 80, mat->m_dims, 16);
    std::memcpy(buf->data() + 96, mat->m_params0, 16);
    std::memcpy(buf->data() + 112, mat->m_params1, 16);
    std::memcpy(buf->data() + 128, mat->m_params2, 16);
    std::memcpy(buf->data() + 144, mat->m_styleOpts, 16);
    std::memcpy(buf->data() + 160, mat->m_primaryColor, 16);
    std::memcpy(buf->data() + 176, mat->m_secondaryColor, 16);
    std::memcpy(buf->data() + 192, mat->m_accentColor, 16);
    return true;
}

void VisualiserMaterialShader::updateSampledImage(
    RenderState& state, int binding, QSGTexture** texture, QSGMaterial* newMaterial, QSGMaterial* oldMaterial) {
    Q_UNUSED(oldMaterial);
    if (binding != 1)
        return;

    const auto* const mat = static_cast<const VisualiserMaterial*>(newMaterial);
    if (!mat->m_dataTex) {
        *texture = nullptr;
        return;
    }

    mat->m_dataTex->commitTextureOperations(state.rhi(), state.resourceUpdateBatch());
    *texture = mat->m_dataTex.data();
}

VisualiserNode::VisualiserNode(VisualiserView::Style style)
    : m_style(style) {
    auto* const geometry = new QSGGeometry(QSGGeometry::defaultAttributes_TexturedPoint2D(), 4);
    geometry->setDrawingMode(QSGGeometry::DrawTriangleStrip);
    setGeometry(geometry);
    setFlag(OwnsGeometry);

    auto* const material = new VisualiserMaterial(style);
    material->setFlag(QSGMaterial::Blending);
    setMaterial(material);
    setFlag(OwnsMaterial);
}

} // namespace caelestia::shell::components

#pragma once

#include <qcolor.h>
#include <qelapsedtimer.h>
#include <qimage.h>
#include <qqmlintegration.h>
#include <qquickitem.h>
#include <qscopedpointer.h>
#include <qsgmaterial.h>
#include <qsgmaterialshader.h>
#include <qsgnode.h>
#include <qsgtexture.h>
#include <qstring.h>
#include <qvariant.h>
#include <qvector.h>

namespace caelestia::shell::components {

class VisualiserView : public QQuickItem {
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(QVector<double> values READ values WRITE setValues NOTIFY valuesChanged)
    Q_PROPERTY(QString style READ style WRITE setStyle NOTIFY styleChanged)
    Q_PROPERTY(QString position READ position WRITE setPosition NOTIFY positionChanged)
    Q_PROPERTY(QString layout READ layout WRITE setLayout NOTIFY layoutChanged)
    Q_PROPERTY(bool mirrored READ mirrored WRITE setMirrored NOTIFY mirroredChanged)
    Q_PROPERTY(qreal heightScale READ heightScale WRITE setHeightScale NOTIFY heightScaleChanged)
    Q_PROPERTY(qreal rounding READ rounding WRITE setRounding NOTIFY roundingChanged)
    Q_PROPERTY(qreal spacing READ spacing WRITE setSpacing NOTIFY spacingChanged)
    Q_PROPERTY(QString gradientMode READ gradientMode WRITE setGradientMode NOTIFY gradientModeChanged)
    Q_PROPERTY(QColor primaryColor READ primaryColor WRITE setPrimaryColor NOTIFY primaryColorChanged)
    Q_PROPERTY(QColor secondaryColor READ secondaryColor WRITE setSecondaryColor NOTIFY secondaryColorChanged)
    Q_PROPERTY(QColor accentColor READ accentColor WRITE setAccentColor NOTIFY accentColorChanged)
    Q_PROPERTY(qreal glow READ glow WRITE setGlow NOTIFY glowChanged)
    Q_PROPERTY(qreal sensitivity READ sensitivity WRITE setSensitivity NOTIFY sensitivityChanged)
    Q_PROPERTY(int attackMs READ attackMs WRITE setAttackMs NOTIFY attackMsChanged)
    Q_PROPERTY(int decayMs READ decayMs WRITE setDecayMs NOTIFY decayMsChanged)
    Q_PROPERTY(qreal beatReactivity READ beatReactivity WRITE setBeatReactivity NOTIFY beatReactivityChanged)
    Q_PROPERTY(QString idleMode READ idleMode WRITE setIdleMode NOTIFY idleModeChanged)
    Q_PROPERTY(qreal idleTimeout READ idleTimeout WRITE setIdleTimeout NOTIFY idleTimeoutChanged)
    Q_PROPERTY(QVariantMap styleOptions READ styleOptions WRITE setStyleOptions NOTIFY styleOptionsChanged)
    Q_PROPERTY(bool previewMode READ previewMode WRITE setPreviewMode NOTIFY previewModeChanged)
    Q_PROPERTY(bool settled READ settled NOTIFY settledChanged)
    Q_PROPERTY(bool idle READ idle NOTIFY idleChanged)
    Q_PROPERTY(bool fadedOut READ fadedOut NOTIFY fadedOutChanged)

public:
    enum class Style : quint8 {
        Aurora = 0,
        Bars = 1,
        Wave = 2,
        Dots = 3,
        Glow = 4,
    };

    explicit VisualiserView(QQuickItem* parent = nullptr);

    Q_INVOKABLE void advance(qreal dt);
    Q_INVOKABLE void triggerBeat(qreal bpm);

    [[nodiscard]] QVector<double> values() const;
    void setValues(const QVector<double>& values);

    [[nodiscard]] QString style() const;
    void setStyle(const QString& style);

    [[nodiscard]] QString position() const;
    void setPosition(const QString& position);

    [[nodiscard]] QString layout() const;
    void setLayout(const QString& layout);

    [[nodiscard]] bool mirrored() const;
    void setMirrored(bool mirrored);

    [[nodiscard]] qreal heightScale() const;
    void setHeightScale(qreal heightScale);

    [[nodiscard]] qreal rounding() const;
    void setRounding(qreal rounding);

    [[nodiscard]] qreal spacing() const;
    void setSpacing(qreal spacing);

    [[nodiscard]] QString gradientMode() const;
    void setGradientMode(const QString& gradientMode);

    [[nodiscard]] QColor primaryColor() const;
    void setPrimaryColor(const QColor& color);

    [[nodiscard]] QColor secondaryColor() const;
    void setSecondaryColor(const QColor& color);

    [[nodiscard]] QColor accentColor() const;
    void setAccentColor(const QColor& color);

    [[nodiscard]] qreal glow() const;
    void setGlow(qreal glow);

    [[nodiscard]] qreal sensitivity() const;
    void setSensitivity(qreal sensitivity);

    [[nodiscard]] int attackMs() const;
    void setAttackMs(int attackMs);

    [[nodiscard]] int decayMs() const;
    void setDecayMs(int decayMs);

    [[nodiscard]] qreal beatReactivity() const;
    void setBeatReactivity(qreal beatReactivity);

    [[nodiscard]] QString idleMode() const;
    void setIdleMode(const QString& idleMode);

    [[nodiscard]] qreal idleTimeout() const;
    void setIdleTimeout(qreal idleTimeout);

    [[nodiscard]] QVariantMap styleOptions() const;
    void setStyleOptions(const QVariantMap& styleOptions);

    [[nodiscard]] bool previewMode() const;
    void setPreviewMode(bool previewMode);

    [[nodiscard]] bool settled() const;
    [[nodiscard]] bool idle() const;
    [[nodiscard]] bool fadedOut() const;

signals:
    void valuesChanged();
    void styleChanged();
    void positionChanged();
    void layoutChanged();
    void mirroredChanged();
    void heightScaleChanged();
    void roundingChanged();
    void spacingChanged();
    void gradientModeChanged();
    void primaryColorChanged();
    void secondaryColorChanged();
    void accentColorChanged();
    void glowChanged();
    void sensitivityChanged();
    void attackMsChanged();
    void decayMsChanged();
    void beatReactivityChanged();
    void idleModeChanged();
    void idleTimeoutChanged();
    void styleOptionsChanged();
    void previewModeChanged();
    void settledChanged();
    void idleChanged();
    void fadedOutChanged();

protected:
    QSGNode* updatePaintNode(QSGNode* oldNode, UpdatePaintNodeData* data) override;
    void geometryChange(const QRectF& newGeometry, const QRectF& oldGeometry) override;
    void releaseResources() override;

private:
    [[nodiscard]] Style resolveStyle() const;
    [[nodiscard]] int resolveEdgeIndex() const;
    [[nodiscard]] int resolveGradientIndex() const;
    void resolveStyleOptionFloats(Style styleEnum, float out[4]) const;
    void rebuildDataImage();
    void wakeUp();
    void setIdle(bool idle);
    void setFadedOut(bool fadedOut);

    QVector<double> m_targetValues;
    QVector<double> m_displayValues;
    QVector<double> m_peakValues;
    QVector<double> m_peakHoldTimers;
    QVector<double> m_peakVelocities;
    QVector<double> m_sparkValues;

    QString m_style;
    QString m_position;
    QString m_layout;
    bool m_mirrored = false;
    qreal m_heightScale = 0.40;
    qreal m_rounding = 1.0;
    qreal m_spacing = 1.0;
    QString m_gradientMode;
    QColor m_primaryColor;
    QColor m_secondaryColor;
    QColor m_accentColor;
    qreal m_glow = 0.35;
    qreal m_sensitivity = 1.0;
    int m_attackMs = 45;
    int m_decayMs = 220;
    qreal m_beatReactivity = 0.50;
    QString m_idleMode;
    qreal m_idleTimeout = 3.0;
    QVariantMap m_styleOptions;
    bool m_previewMode = false;

    bool m_settled = false;
    bool m_idle = false;
    bool m_fadedOut = false;
    qreal m_timeSec = 0.0;
    qreal m_silenceSec = 0.0;
    qreal m_idleFactor = 1.0;
    qreal m_fadeOpacity = 1.0;
    qreal m_beatEnergy = 0.0;
    qreal m_prevBass = 0.0;

    QImage m_dataImage;
    bool m_dataDirty = true;
};

class VisualiserMaterial : public QSGMaterial {
public:
    explicit VisualiserMaterial(VisualiserView::Style style);

    [[nodiscard]] QSGMaterialType* type() const override;
    [[nodiscard]] QSGMaterialShader* createShader(QSGRendererInterface::RenderMode mode) const override;
    int compare(const QSGMaterial* other) const override;

    VisualiserView::Style m_style;
    QScopedPointer<QSGTexture> m_dataTex;
    float m_fadeOpacity = 1.0f;
    float m_dims[4] = {};
    float m_params0[4] = {};
    float m_params1[4] = {};
    float m_params2[4] = {};
    float m_styleOpts[4] = {};
    float m_primaryColor[4] = {};
    float m_secondaryColor[4] = {};
    float m_accentColor[4] = {};
};

class VisualiserMaterialShader : public QSGMaterialShader {
public:
    explicit VisualiserMaterialShader(VisualiserView::Style style);

    bool updateUniformData(RenderState& state, QSGMaterial* newMaterial, QSGMaterial* oldMaterial) override;
    void updateSampledImage(RenderState& state, int binding, QSGTexture** texture, QSGMaterial* newMaterial,
        QSGMaterial* oldMaterial) override;
};

class VisualiserNode : public QSGGeometryNode {
public:
    explicit VisualiserNode(VisualiserView::Style style);

    [[nodiscard]] VisualiserView::Style style() const { return m_style; }

private:
    VisualiserView::Style m_style;
};

} // namespace caelestia::shell::components

#pragma once

#include <qqmlintegration.h>

#include <atomic>

#include <cava/cavacore.h>

#include "audioprovider.hpp"

namespace caelestia::shell::services {

class CavaProcessor : public AudioProcessor {
    Q_OBJECT

public:
    explicit CavaProcessor(QObject* parent = nullptr);
    ~CavaProcessor() override;

    void setBars(int bars);
    void setMonstercat(bool monstercat);

signals:
    void valuesChanged(QVector<double> values);

protected:
    void process() override;

private:
    struct cava_plan* m_plan;
    double* m_in;
    double* m_out;

    int m_bars;
    std::atomic<bool> m_monstercat{ true };
    bool m_allZero = false;
    QVector<double> m_values;

    void reload();
    void initCava();
    void cleanup();
};

class CavaProvider : public AudioProvider {
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(int bars READ bars WRITE setBars NOTIFY barsChanged)
    Q_PROPERTY(bool monstercat READ monstercat WRITE setMonstercat NOTIFY monstercatChanged)

    Q_PROPERTY(QVector<double> values READ values NOTIFY valuesChanged)

public:
    explicit CavaProvider(QObject* parent = nullptr);

    [[nodiscard]] int bars() const;
    void setBars(int bars);

    [[nodiscard]] bool monstercat() const;
    void setMonstercat(bool monstercat);

    [[nodiscard]] QVector<double> values() const;

signals:
    void barsChanged();
    void monstercatChanged();
    void valuesChanged();

private:
    int m_bars;
    bool m_monstercat = true;
    QVector<double> m_values;

    void updateValues(const QVector<double>& values);
};

} // namespace caelestia::shell::services

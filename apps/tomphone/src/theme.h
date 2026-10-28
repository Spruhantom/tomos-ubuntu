#pragma once
#include <QObject>
#include <QFileSystemWatcher>
#include <QTimer>
class Theme : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString accent READ accent NOTIFY changed)
    Q_PROPERTY(QString background READ background NOTIFY changed)
    Q_PROPERTY(QString surface READ surface NOTIFY changed)
    Q_PROPERTY(QString raisedSurface READ raisedSurface NOTIFY changed)
    Q_PROPERTY(QString foreground READ foreground NOTIFY changed)
    Q_PROPERTY(QString mutedForeground READ mutedForeground NOTIFY changed)
    Q_PROPERTY(QString border READ border NOTIFY changed)
    Q_PROPERTY(QString selection READ selection NOTIFY changed)
    Q_PROPERTY(bool dark READ dark NOTIFY changed)
    Q_PROPERTY(int radius READ radius NOTIFY changed)
public:
    explicit Theme(QObject *parent = nullptr);
    QString accent() const { return m_accent; }
    QString background() const { return m_background; }
    QString surface() const { return m_surface; }
    QString raisedSurface() const { return m_raisedSurface; }
    QString foreground() const { return m_foreground; }
    QString mutedForeground() const { return m_mutedForeground; }
    QString border() const { return m_border; }
    QString selection() const { return m_selection; }
    bool dark() const { return m_dark; }
    int radius() const { return m_radius; }
signals: void changed();
private slots: void reload();
private:
    QString m_path;
    QString m_accent = "#FFD60A", m_background = "#101114", m_surface = "#191a1f";
    QString m_raisedSurface = "#25262b", m_foreground = "#f6f3ff", m_mutedForeground = "#aaa4c7";
    QString m_border = "#514a7e", m_selection = "#2b2452";
    bool m_dark = true; int m_radius = 0;
    QFileSystemWatcher m_watcher; QTimer m_debounce;
};

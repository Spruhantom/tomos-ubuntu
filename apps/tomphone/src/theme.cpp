#include "theme.h"
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QRegularExpression>
#include <QProcess>
static QString paletteValue(const QString &contents, const QString &key, const QString &fallback) {
    const QString pattern = "^\\s*" + QRegularExpression::escape(key) + "\\s*=\\s*[\\\"']([^\\\"']+)[\\\"']";
    const auto match = QRegularExpression(pattern, QRegularExpression::MultilineOption).match(contents);
    return match.hasMatch() ? match.captured(1) : fallback;
}
Theme::Theme(QObject *parent) : QObject(parent), m_path(QDir::homePath() + "/.local/state/omarchy/current") {
    m_debounce.setSingleShot(true);
    connect(&m_watcher, &QFileSystemWatcher::directoryChanged, this, [this] { m_debounce.start(80); });
    connect(&m_watcher, &QFileSystemWatcher::fileChanged, this, [this] { m_debounce.start(80); });
    connect(&m_debounce, &QTimer::timeout, this, &Theme::reload);
    reload();
    QTimer *rounding = new QTimer(this); rounding->setInterval(1200);
    connect(rounding, &QTimer::timeout, this, [this] {
        QProcess p; p.start("hyprctl", {"-j", "getoption", "decoration:rounding"});
        if (!p.waitForFinished(400)) return;
        auto m = QRegularExpression("\\\"int\\\"\\s*:\\s*(\\d+)").match(QString::fromUtf8(p.readAllStandardOutput()));
        if (m.hasMatch() && m.captured(1).toInt() != m_radius) { m_radius = m.captured(1).toInt(); emit changed(); }
    });
    rounding->start();
}
void Theme::reload() {
    const auto paths = m_watcher.files() + m_watcher.directories(); if (!paths.isEmpty()) m_watcher.removePaths(paths);
    QString ancestor = m_path;
    while (!QFileInfo::exists(ancestor) && ancestor != "/") ancestor = QFileInfo(ancestor).absolutePath();
    for (const auto &p : {ancestor, QFileInfo(ancestor).absolutePath(), QFileInfo(m_path).absolutePath(),
                          m_path, m_path + "/theme", m_path + "/theme/colors.toml"})
        if (QFileInfo::exists(p)) m_watcher.addPath(p);
    QFile f(m_path + "/theme/colors.toml"); QString contents;
    if (f.open(QIODevice::ReadOnly)) contents = QString::fromUtf8(f.readAll());
    const QString mode = paletteValue(contents, "mode", "dark");
    const QString accent = paletteValue(contents, "accent", "#FFD60A");
    const QString background = paletteValue(contents, "background", "#101114");
    const QString surface = paletteValue(contents, "dark_background", "#191a1f");
    const QString raisedSurface = paletteValue(contents, "lighter_background", "#25262b");
    const QString foreground = paletteValue(contents, "foreground", "#f6f3ff");
    const QString mutedForeground = paletteValue(contents, "dark_foreground", "#aaa4c7");
    const QString border = paletteValue(contents, "muted", "#514a7e");
    const QString selection = paletteValue(contents, "selection", "#2b2452");
    const bool dark = mode != "light";
    if (accent != m_accent || background != m_background || surface != m_surface ||
        raisedSurface != m_raisedSurface || foreground != m_foreground ||
        mutedForeground != m_mutedForeground || border != m_border ||
        selection != m_selection || dark != m_dark) {
        m_accent = accent; m_background = background; m_surface = surface;
        m_raisedSurface = raisedSurface; m_foreground = foreground;
        m_mutedForeground = mutedForeground; m_border = border;
        m_selection = selection; m_dark = dark; emit changed();
    }
}

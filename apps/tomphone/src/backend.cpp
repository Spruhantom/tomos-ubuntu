#include "backend.h"
#include <QDir>
#include <QFile>
#include <QHostAddress>
#include <QJsonDocument>
#include <QJsonObject>
#include <QRegularExpression>
#include <QSaveFile>
#include <QStandardPaths>
Backend::Backend(QObject *parent) : QObject(parent), m_configDir(QDir::homePath() + "/.config/tomphone/baresip") {
    connect(&m_socket, &QTcpSocket::readyRead, this, &Backend::readControl);
    connect(&m_socket, &QTcpSocket::connected, this, [this] { setStatus("Ready", "SIP engine connected"); });
    connect(&m_socket, &QTcpSocket::disconnected, this, [this] { if (running()) setStatus("Starting", "Connecting to SIP engine…"); });
    connect(&m_process, &QProcess::errorOccurred, this, [this](QProcess::ProcessError) { setStatus("Engine unavailable", "Install Baresip and its PulseAudio module to make calls."); });
    connect(&m_process, qOverload<int,QProcess::ExitStatus>(&QProcess::finished), this, [this](int, QProcess::ExitStatus) { m_socket.abort(); setStatus("Stopped", "The SIP engine has stopped."); });
    m_connectTimer.setInterval(300);
    connect(&m_connectTimer, &QTimer::timeout, this, [this] {
        if (!running() || m_socket.state() == QAbstractSocket::ConnectedState) { m_connectTimer.stop(); return; }
        m_socket.connectToHost(QHostAddress::LocalHost, m_port);
    });
    loadAccount(); if (m_configured) start();
}
void Backend::setStatus(const QString &s, const QString &d) { m_status = s; m_details = d; emit changed(); }
void Backend::loadAccount() {
    QFile f(QDir::homePath() + "/.config/tomphone/account.json"); if (!f.open(QIODevice::ReadOnly)) return;
    const auto o = QJsonDocument::fromJson(f.readAll()).object();
    m_server = o.value("server").toString(); m_username = o.value("username").toString(); m_password = o.value("password").toString();
    m_configured = !m_server.isEmpty() && !m_username.isEmpty(); if (m_configured) setStatus("Saved account", m_username + " @ " + m_server);
}
void Backend::writeConfiguration() {
    QDir().mkpath(m_configDir);
    QFile cfg(m_configDir + "/config");
    if (cfg.open(QIODevice::WriteOnly | QIODevice::Truncate)) cfg.write("module_path /usr/lib/baresip/modules\nmodule g711.so\nmodule auconv.so\nmodule auresamp.so\nmodule pulse.so\nmodule_app menu.so\nmodule_app ctrl_tcp.so\nctrl_tcp_listen 127.0.0.1:" + QByteArray::number(m_port) + "\naudio_player pulse,default\naudio_source pulse,default\naudio_alert pulse,default\n");
    QFile accounts(m_configDir + "/accounts");
    if (accounts.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        accounts.write("sip:" + m_username.toUtf8() + "@" + m_server.toUtf8() + ";auth_user=" + m_username.toUtf8() + ";auth_pass=" + m_password.toUtf8() + ";regint=300\n");
        accounts.setPermissions(QFileDevice::ReadOwner | QFileDevice::WriteOwner);
    }
    QFile::setPermissions(m_configDir, QFileDevice::ReadOwner | QFileDevice::WriteOwner | QFileDevice::ExeOwner);
}
void Backend::saveAccount(const QString &server, const QString &username, const QString &password) {
    QString host = server.trimmed(); host.remove(QRegularExpression("^sips?:", QRegularExpression::CaseInsensitiveOption)); host.remove(QRegularExpression("^/+"));
    if (host.isEmpty() || username.trimmed().isEmpty()) { setStatus("Account details needed", "Enter your SIP server and username."); return; }
    m_server = host; m_username = username.trimmed(); m_password = password; m_configured = true;
    QDir().mkpath(QDir::homePath() + "/.config/tomphone");
    QSaveFile f(QDir::homePath() + "/.config/tomphone/account.json");
    if (f.open(QIODevice::WriteOnly)) {
        f.write(QJsonDocument(QJsonObject{{"server", m_server}, {"username", m_username}, {"password", m_password}}).toJson(QJsonDocument::Compact));
        if (f.commit()) QFile::setPermissions(f.fileName(), QFileDevice::ReadOwner | QFileDevice::WriteOwner);
    }
    writeConfiguration(); emit changed(); start();
}
void Backend::start() {
    if (!m_configured) { setStatus("Set up your account", "Enter your SIP account details to begin."); return; }
    if (running()) return;
    const QString executable = QStandardPaths::findExecutable("baresip");
    if (executable.isEmpty()) { setStatus("Baresip not installed", "Install the Baresip package to enable calls."); return; }
    writeConfiguration(); m_process.setProgram(executable); m_process.setArguments({"-f", m_configDir});
    m_process.setProcessChannelMode(QProcess::MergedChannels); m_process.start(); setStatus("Starting", "Starting SIP registration…"); m_connectTimer.start();
}
void Backend::command(const QString &name, const QString &params) {
    if (m_socket.state() != QAbstractSocket::ConnectedState) { setStatus("Engine disconnected", "Restart the SIP engine and try again."); return; }
    QJsonObject o{{"command", name}}; if (!params.isEmpty()) o.insert("params", params);
    const QByteArray body = QJsonDocument(o).toJson(QJsonDocument::Compact);
    m_socket.write(QByteArray::number(body.size()) + ":" + body + ",");
}
void Backend::readControl() {
    m_buffer += m_socket.readAll();
    while (true) {
        const int colon = m_buffer.indexOf(':'); if (colon < 1) return;
        bool ok = false; const int size = m_buffer.left(colon).toInt(&ok); if (!ok || size < 0 || size > 65536) { m_buffer.clear(); return; }
        if (m_buffer.size() < colon + size + 2) return;
        const auto o = QJsonDocument::fromJson(m_buffer.mid(colon + 1, size)).object(); m_buffer.remove(0, colon + size + 2);
        const QJsonValue event = o.value("event");
        if (!(event.toBool() || event.toString() == "true")) continue;
        const QString type = o.value("type").toString();
        if (type == "CALL_INCOMING") { m_inCall = true; setStatus("Incoming call", o.value("peeruri").toString()); }
        else if (type == "CALL_ESTABLISHED") { m_inCall = true; setStatus("In call", o.value("peeruri").toString()); }
        else if (type == "CALL_CLOSED") { m_inCall = false; setStatus("Ready", "Call ended"); }
        else if (type == "REGISTER_OK") setStatus("Registered", m_username + " @ " + m_server);
        else if (type == "REGISTER_FAIL") setStatus("Registration failed", o.value("param").toString());
        else { m_details = o.value("param").toString(); emit changed(); }
    }
}
void Backend::call() { if (!m_number.trimmed().isEmpty()) command("dial", m_number.trimmed().contains(":") ? m_number.trimmed() : "sip:" + m_number.trimmed() + "@" + m_server); }
void Backend::answer() { command("accept"); }
void Backend::hangup() { command("hangup"); }
void Backend::toggleMute() { m_muted = !m_muted; command(m_muted ? "mute" : "unmute"); setStatus(m_status, m_muted ? "Microphone muted" : "Microphone active"); }
void Backend::forgetAccount() {
    if (running()) m_process.terminate();
    QFile::remove(QDir::homePath() + "/.config/tomphone/account.json");
    m_configured = false; m_inCall = false; m_password.clear(); setStatus("Not configured", "Enter your SIP account details to begin.");
}

#pragma once
#include <QObject>
#include <QProcess>
#include <QTcpSocket>
#include <QTimer>
class Backend : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString status READ status NOTIFY changed)
    Q_PROPERTY(QString details READ details NOTIFY changed)
    Q_PROPERTY(bool configured READ configured NOTIFY changed)
    Q_PROPERTY(bool running READ running NOTIFY changed)
    Q_PROPERTY(bool inCall READ inCall NOTIFY changed)
    Q_PROPERTY(QString number READ number WRITE setNumber NOTIFY changed)
public:
    explicit Backend(QObject *parent = nullptr);
    QString status() const { return m_status; }
    QString details() const { return m_details; }
    bool configured() const { return m_configured; }
    bool running() const { return m_process.state() != QProcess::NotRunning; }
    bool inCall() const { return m_inCall; }
    QString number() const { return m_number; }
    void setNumber(const QString &n) { m_number = n; emit changed(); }
    Q_INVOKABLE void saveAccount(const QString &server, const QString &username, const QString &password);
    Q_INVOKABLE void start(); Q_INVOKABLE void call(); Q_INVOKABLE void answer();
    Q_INVOKABLE void hangup(); Q_INVOKABLE void toggleMute(); Q_INVOKABLE void forgetAccount();
signals: void changed();
private slots: void readControl();
private:
    void setStatus(const QString &, const QString & = {}); void command(const QString &, const QString & = {});
    void loadAccount(); void writeConfiguration();
    QString m_status = "Not configured", m_details, m_server, m_username, m_password, m_number;
    QString m_configDir; bool m_configured = false, m_inCall = false, m_muted = false;
    QProcess m_process; QTcpSocket m_socket; QByteArray m_buffer; quint16 m_port = 45873; QTimer m_connectTimer;
};

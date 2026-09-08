#pragma once

#include <QObject>
#include <QString>
#include <QtQml/qqmlregistration.h>

class AppController : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(QString productName READ productName CONSTANT)
    Q_PROPERTY(QString status READ status CONSTANT)
    Q_PROPERTY(QString qtVersion READ qtVersion CONSTANT)
    Q_PROPERTY(QString incomingUrl READ incomingUrl NOTIFY incomingUrlChanged)

public:
    explicit AppController(QObject *parent = nullptr);

    QString productName() const;
    QString status() const;
    QString qtVersion() const;
    QString incomingUrl() const;
    Q_INVOKABLE QString clipboardText() const;
    Q_INVOKABLE void setIncomingUrl(const QString &url);
    Q_INVOKABLE void clearIncomingUrl();

signals:
    void incomingUrlChanged();

private:
    QString m_incomingUrl;
};

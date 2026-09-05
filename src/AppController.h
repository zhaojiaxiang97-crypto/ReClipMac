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

public:
    explicit AppController(QObject *parent = nullptr);

    QString productName() const;
    QString status() const;
    QString qtVersion() const;
    Q_INVOKABLE QString clipboardText() const;
};

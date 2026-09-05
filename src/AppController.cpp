#include "AppController.h"

#include <QGuiApplication>
#include <QClipboard>

AppController::AppController(QObject *parent)
    : QObject(parent)
{
}

QString AppController::productName() const
{
    return QStringLiteral("ReClip");
}

QString AppController::status() const
{
    return QStringLiteral("C++ backend connected");
}

QString AppController::qtVersion() const
{
    return QString::fromLatin1(QT_VERSION_STR);
}

QString AppController::clipboardText() const
{
    const QClipboard *clipboard = QGuiApplication::clipboard();
    return clipboard ? clipboard->text(QClipboard::Clipboard) : QString();
}

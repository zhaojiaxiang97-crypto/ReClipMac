#pragma once

#include <QByteArray>
#include <QList>
#include <QPair>
#include <QString>
#include <atomic>
#include <memory>

namespace ReClip::YtDlp {

struct Request {
    QString url;
    QString formatSelector;
    QString outputPath;
    QList<QPair<QByteArray, QByteArray>> headers;
    double timeoutSeconds = 30;
    bool probe = false;
    bool download = false;
};

struct Result {
    bool ok = false;
    QByteArray payload;
    QString errorCode;
    QString errorMessage;
};

using CancelToken = std::shared_ptr<std::atomic_bool>;

} // namespace ReClip::YtDlp

#pragma once

#include "YtDlpTypes.h"
#include <QHash>
#include <QObject>
#include <QPointer>

class QProcess;
class QTimer;

namespace ReClip::YtDlp {

// Metadata/resolve/download facade. An explicit program opts into process
// compatibility; an empty program selects the embedded backend when compiled
// in, never PATH.
class YtDlpService final : public QObject {
    Q_OBJECT
public:
    explicit YtDlpService(QObject *parent = nullptr);
    ~YtDlpService() override;
    static bool embeddedEnabled();
    bool usesEmbedded() const;
    void setProgram(const QString &program);
    QString inspect(const Request &request);
    QString download(const Request &request);
    QString probe();
    void cancel(const QString &id);

signals:
    void finished(const QString &id, bool ok, const QByteArray &payload,
                  const QString &errorCode, const QString &errorMessage);

private:
    struct Operation {
        CancelToken cancel = std::make_shared<std::atomic_bool>(false);
        QPointer<QProcess> process;
        QPointer<QTimer> timer;
        bool timedOut = false;
        QByteArray output;
        QByteArray error;
    };
    void start(const QString &id, const Request &request, const QString &program);
    void finish(const QString &id, Result result);
    QString m_program;
    QHash<QString, std::shared_ptr<Operation>> m_operations;
};

} // namespace ReClip::YtDlp

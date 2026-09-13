#include <QtCore/qglobal.h>

// Release CPython has a different ABI from Py_DEBUG, even in a Qt Debug build.
#if defined(_MSC_VER) && defined(_DEBUG)
#pragma push_macro("_DEBUG")
#undef _DEBUG
#include <Python.h>
#pragma pop_macro("_DEBUG")
#else
#include <Python.h>
#endif

#include "PythonRuntime.h"
#include <QCoreApplication>
#include <QDir>
#include <QFile>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QPromise>
#include <condition_variable>
#include <deque>
#include <mutex>
#include <thread>

// Referencing a Qt resource from a static library requires explicit init.
static void initPythonResources() { Q_INIT_RESOURCE(reclip_python); }

namespace ReClip::YtDlp {
namespace {

struct PyDelete { void operator()(PyObject *object) const { Py_XDECREF(object); } };
using Object = std::unique_ptr<PyObject, PyDelete>;

QString pythonError()
{
    Object error(PyErr_GetRaisedException());
    Object message(error ? PyObject_Str(error.get()) : nullptr);
    const char *text = message ? PyUnicode_AsUTF8(message.get()) : nullptr;
    const QString result = text ? QString::fromUtf8(text) : QStringLiteral("Python 调用失败");
    PyErr_Clear();
    return result;
}

PyObject *checkCancelled(PyObject *self, PyObject *)
{
    auto *token = static_cast<std::atomic_bool *>(PyCapsule_GetPointer(self, "reclip.cancel"));
    if (!token) { return nullptr; }
    return PyBool_FromLong(token->load());
}
PyMethodDef cancelMethod = {"is_cancelled", checkCancelled, METH_NOARGS, nullptr};

class Runtime final {
public:
    Runtime()
        : m_root(QDir(QCoreApplication::applicationDirPath()).filePath(QStringLiteral("runtime/python")))
    {
        initPythonResources();
        m_thread = std::thread([this] { run(); });
    }

    ~Runtime()
    {
        {
            std::lock_guard<std::mutex> lock(m_mutex);
            m_stopping = true;
            if (m_active) { m_active->store(true); }
            for (auto &job : m_jobs) { job.cancel->store(true); }
        }
        m_ready.notify_one();
        m_thread.join();
    }

    QFuture<Result> submit(const Request &request, const CancelToken &cancel)
    {
        Job job;
        job.request = request;
        job.cancel = cancel;
        job.promise.start();
        auto future = job.promise.future();
        {
            std::lock_guard<std::mutex> lock(m_mutex);
            if (m_stopping || m_jobs.size() >= 16) {
                job.promise.addResult(Result{false, {}, QStringLiteral("busy"), QStringLiteral("解析队列繁忙，请稍后重试")});
                job.promise.finish();
                return future;
            }
            m_jobs.push_back(std::move(job));
        }
        m_ready.notify_one();
        return future;
    }

private:
    struct Job {
        Request request;
        CancelToken cancel;
        QPromise<Result> promise;
    };

    bool initialize()
    {
        if (m_attempted) { return m_function != nullptr; }
        m_attempted = true;
        if (!QFile::exists(m_root + QStringLiteral("/Lib/encodings/__init__.py"))) {
            m_error = QStringLiteral("应用内置 Python 标准库缺失：%1").arg(m_root);
            return false;
        }
        if (Py_IsInitialized()) {
            m_error = QStringLiteral("检测到其他 Python 解释器，拒绝混用运行时");
            return false;
        }
        PyConfig config;
        PyConfig_InitIsolatedConfig(&config);
        config.site_import = 0;
        config.write_bytecode = 0;
        config.parse_argv = 0;
        config.install_signal_handlers = 0;
        config.module_search_paths_set = 1;
        const std::wstring home = m_root.toStdWString();
        PyStatus status = PyConfig_SetString(&config, &config.home, home.c_str());
        for (const auto &suffix : {"/Lib", "/DLLs", "/Lib/site-packages"}) {
            if (PyStatus_Exception(status)) { break; }
            const std::wstring path = (m_root + QString::fromLatin1(suffix)).toStdWString();
            status = PyWideStringList_Append(&config.module_search_paths, path.c_str());
        }
        if (!PyStatus_Exception(status)) { status = Py_InitializeFromConfig(&config); }
        if (PyStatus_Exception(status)) {
            m_error = QString::fromUtf8(status.err_msg ? status.err_msg : "Python 初始化失败");
            PyConfig_Clear(&config);
            return false;
        }
        PyConfig_Clear(&config);
        m_initialized = true;
        QFile adapter(QStringLiteral(":/reclip/python/adapter.py"));
        if (!adapter.open(QIODevice::ReadOnly)) {
            m_error = QStringLiteral("内置 yt-dlp 适配模块缺失");
        } else {
            const QByteArray source = adapter.readAll();
            Object module(PyModule_New("reclip_ytdlp"));
            Object code(Py_CompileString(source.constData(), "<reclip_ytdlp>", Py_file_input));
            Object evaluated(module && code ? PyEval_EvalCode(code.get(), PyModule_GetDict(module.get()), PyModule_GetDict(module.get())) : nullptr);
            if (evaluated) { m_function = PyObject_GetAttrString(module.get(), "run"); }
            if (!m_function) { m_error = pythonError(); }
        }
        m_state = PyEval_SaveThread();
        return m_function != nullptr;
    }

    Result execute(const Job &job)
    {
        if (job.cancel->load()) { return {false, {}, QStringLiteral("cancelled"), QStringLiteral("已取消")}; }
        if (!initialize()) { return {false, {}, QStringLiteral("runtime-error"), m_error}; }
        PyEval_RestoreThread(m_state);
        Result result;
        {
            const QJsonObject request {
                {QStringLiteral("operation"), job.request.probe
                     ? QStringLiteral("probe")
                     : (job.request.download ? QStringLiteral("download") : QStringLiteral("inspect"))},
                {QStringLiteral("url"), job.request.url},
                {QStringLiteral("format"), job.request.formatSelector},
                {QStringLiteral("outputPath"), job.request.outputPath},
                {QStringLiteral("timeout"), job.request.timeoutSeconds},
            };
            QJsonObject headers;
            for (const auto &header : job.request.headers) {
                if (!header.first.isEmpty() && !header.second.isEmpty()
                    && header.first.indexOf('\r') < 0 && header.first.indexOf('\n') < 0
                    && header.second.indexOf('\r') < 0 && header.second.indexOf('\n') < 0) {
                    headers.insert(QString::fromUtf8(header.first), QString::fromUtf8(header.second));
                }
            }
            QJsonObject requestWithHeaders = request;
            requestWithHeaders.insert(QStringLiteral("httpHeaders"), headers);
            const QByteArray json = QJsonDocument(requestWithHeaders).toJson(QJsonDocument::Compact);
            Object argument(PyUnicode_DecodeUTF8(json.constData(), json.size(), "strict"));
            Object capsule(PyCapsule_New(job.cancel.get(), "reclip.cancel", nullptr));
            Object callback(capsule ? PyCFunction_New(&cancelMethod, capsule.get()) : nullptr);
            Object response(argument && callback ? PyObject_CallFunctionObjArgs(m_function, argument.get(), callback.get(), nullptr) : nullptr);
            const char *text = response ? PyUnicode_AsUTF8(response.get()) : nullptr;
            if (!text) {
                result = {false, {}, QStringLiteral("runtime-error"), pythonError()};
            } else {
                const auto envelope = QJsonDocument::fromJson(QByteArray(text)).object();
                result.ok = envelope.value(QStringLiteral("ok")).toBool();
                const QJsonValue payload = envelope.value(QStringLiteral("payload"));
                if (payload.isObject()) {
                    result.payload = QJsonDocument(payload.toObject()).toJson(QJsonDocument::Compact);
                } else if (payload.isArray()) {
                    result.payload = QJsonDocument(payload.toArray()).toJson(QJsonDocument::Compact);
                } else if (payload.isString()) {
                    result.payload = payload.toString().toUtf8();
                }
                result.errorCode = envelope.value(QStringLiteral("code")).toString();
                result.errorMessage = envelope.value(QStringLiteral("error")).toString();
                if (!result.ok && result.errorCode.isEmpty()) {
                    result.errorCode = QStringLiteral("invalid-result");
                    result.errorMessage = QStringLiteral("内置解析器返回无效结果");
                }
            }
        }
        m_state = PyEval_SaveThread();
        if (job.cancel->load()) { return {false, {}, QStringLiteral("cancelled"), QStringLiteral("已取消")}; }
        return result;
    }

    void run()
    {
        for (;;) {
            Job job;
            {
                std::unique_lock<std::mutex> lock(m_mutex);
                m_ready.wait(lock, [this] { return m_stopping || !m_jobs.empty(); });
                if (m_jobs.empty() && m_stopping) { break; }
                job = std::move(m_jobs.front());
                m_jobs.pop_front();
                m_active = job.cancel;
            }
            try {
                job.promise.addResult(execute(job));
            } catch (const std::exception &) {
                job.promise.addResult(Result{false, {}, QStringLiteral("runtime-error"), QStringLiteral("解析运行时异常")});
            }
            job.promise.finish();
            {
                std::lock_guard<std::mutex> lock(m_mutex);
                m_active.reset();
            }
        }
        if (m_initialized) {
            PyEval_RestoreThread(m_state);
            Py_XDECREF(m_function);
            Py_FinalizeEx();
        }
    }

    QString m_root;
    QString m_error;
    bool m_attempted = false;
    bool m_initialized = false;
    bool m_stopping = false;
    PyThreadState *m_state = nullptr;
    PyObject *m_function = nullptr;
    std::mutex m_mutex;
    std::condition_variable m_ready;
    std::deque<Job> m_jobs;
    CancelToken m_active;
    std::thread m_thread;
};

} // namespace

QFuture<Result> submitPython(const Request &request, const CancelToken &cancel)
{
    static Runtime runtime;
    return runtime.submit(request, cancel);
}

} // namespace ReClip::YtDlp

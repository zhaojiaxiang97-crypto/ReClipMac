package com.reclip.videodownloader;

import android.content.Context;
import android.util.Log;

import com.chaquo.python.PyObject;
import com.chaquo.python.Python;

import dev.ffmpegkit_maintained.ytdlp.DownloadProgressCallback;
import dev.ffmpegkit_maintained.ytdlp.LogCallback;
import dev.ffmpegkit_maintained.ytdlp.YtDlp;
import dev.ffmpegkit_maintained.ytdlp.YtDlpException;
import dev.ffmpegkit_maintained.ytdlp.YtDlpRequest;
import dev.ffmpegkit_maintained.ytdlp.YtDlpResponse;

import java.io.File;
import java.lang.reflect.InvocationHandler;
import java.lang.reflect.Method;
import java.lang.reflect.Proxy;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.CancellationException;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicReference;

/**
 * Android-only bridge for the embedded yt-dlp runtime.
 *
 * This file is copied into the generated Android package only when the
 * verified yt-dlp AAR is requested. The desktop and dependency-free Android
 * builds therefore do not compile against Chaquopy or yt-dlp classes.
 */
public final class AndroidYtDlpBridge {
    private static final String TAG = "VideoDownloader";
    private static final String FFMPEG_KIT_CLASS = "com.arthenica.ffmpegkit.FFmpegKit";
    private static final String FFMPEG_SESSION_CLASS = "com.arthenica.ffmpegkit.FFmpegSession";
    private static final String FFMPEG_COMPLETE_CALLBACK_CLASS =
            "com.arthenica.ffmpegkit.FFmpegSessionCompleteCallback";
    private static final String FFMPEG_LOG_CALLBACK_CLASS =
            "com.arthenica.ffmpegkit.LogCallback";
    private static final String FFMPEG_STATISTICS_CALLBACK_CLASS =
            "com.arthenica.ffmpegkit.StatisticsCallback";
    private static final ExecutorService EXECUTOR = Executors.newCachedThreadPool();
    private static final ConcurrentHashMap<String, Future<?>> OPERATIONS = new ConcurrentHashMap<>();
    private static final ConcurrentHashMap<String, Boolean> CANCELLED = new ConcurrentHashMap<>();
    private static final ConcurrentHashMap<String, Boolean> FINISHED = new ConcurrentHashMap<>();
    private static final ConcurrentHashMap<String, String> REQUEST_DIRECTORIES = new ConcurrentHashMap<>();
    private static final ConcurrentHashMap<String, String> REQUEST_TASK_IDS = new ConcurrentHashMap<>();
    private static final ConcurrentHashMap<String, Long> REQUEST_STARTED_AT = new ConcurrentHashMap<>();
    private static final ConcurrentHashMap<String, String> REQUEST_OUTPUTS = new ConcurrentHashMap<>();
    private static final ConcurrentHashMap<String, Object> FFMPEG_SESSIONS = new ConcurrentHashMap<>();
    private static volatile Context applicationContext;
    private static volatile boolean initialized;

    private interface CallbackHandler {
        void handle(Object[] arguments);
    }

    private AndroidYtDlpBridge() {
    }

    public static synchronized void attachContext(Context context) {
        if (context != null) {
            applicationContext = context.getApplicationContext();
        }
    }

    public static synchronized void initialize() {
        if (initialized || applicationContext == null) {
            return;
        }
        try {
            YtDlp.init(applicationContext);
            initialized = true;
        } catch (YtDlpException exception) {
            throw new IllegalStateException("无法初始化 Android yt-dlp 运行时", exception);
        }
    }

    public static boolean isAvailable() {
        return applicationContext != null;
    }

    public static void inspect(String requestId, String url) {
        EXECUTOR.execute(() -> {
            try {
                initialize();
                if (!initialized) {
                    finishInspection(requestId, false, "", "Android yt-dlp 运行时尚未初始化");
                    return;
                }

                PyObject options = Python.getInstance().getBuiltins().callAttr("dict");
                setOption(options, "quiet", true);
                setOption(options, "no_warnings", true);
                setOption(options, "noplaylist", true);
                setOption(options, "skip_download", true);
                setOption(options, "socket_timeout", 30);

                PyObject ytDlpModule = Python.getInstance().getModule("yt_dlp");
                PyObject downloader = ytDlpModule.callAttr("YoutubeDL", options);
                PyObject info = downloader.callAttr("extract_info", url, false);
                PyObject jsonModule = Python.getInstance().getModule("json");
                String payload = jsonModule.callAttr("dumps", info).toJava(String.class);
                finishInspection(requestId, true, payload, "");
            } catch (Exception exception) {
                finishInspection(requestId, false, "", messageFor(exception));
            }
        });
    }

    public static void download(String requestId,
                                String url,
                                String formatId,
                                String format,
                                String outputDirectory,
                                String taskId) {
        CANCELLED.remove(requestId);
        FINISHED.remove(requestId);
        REQUEST_DIRECTORIES.put(requestId, outputDirectory == null ? "" : outputDirectory);
        REQUEST_TASK_IDS.put(requestId, taskId == null ? "" : taskId);
        REQUEST_STARTED_AT.put(requestId, System.currentTimeMillis());
        REQUEST_OUTPUTS.remove(requestId);
        MainActivity.startDownloadForeground(
                requestId, "Video Downloader", REQUEST_TASK_IDS.get(requestId));
        Future<?> operation = EXECUTOR.submit(() -> runDownload(
                requestId, url, formatId, format, outputDirectory));
        OPERATIONS.put(requestId, operation);
    }

    public static void cancel(String requestId) {
        CANCELLED.put(requestId, true);
        Future<?> operation = OPERATIONS.get(requestId);
        if (operation != null) {
            operation.cancel(true);
        }
        cancelFfmpegSession(FFMPEG_SESSIONS.get(requestId));
        cleanupTemporaryFiles(requestId);
        cleanupTemporaryFilesEventually(
                REQUEST_DIRECTORIES.get(requestId),
                REQUEST_STARTED_AT.get(requestId),
                REQUEST_OUTPUTS.get(requestId));
        finishDownload(requestId, false, REQUEST_OUTPUTS.getOrDefault(requestId, ""), "已取消");
    }

    private static void runDownload(String requestId,
                                    String url,
                                    String formatId,
                                    String format,
                                    String outputDirectory) {
        final long startedAt = System.currentTimeMillis();
        final AtomicReference<String> outputPath = new AtomicReference<>("");
        boolean terminalSuccess = false;
        try {
            if (CANCELLED.containsKey(requestId)) {
                return;
            }
            initialize();
            if (CANCELLED.containsKey(requestId)) {
                return;
            }
            if (!initialized) {
                finishDownload(requestId, false, "", "Android yt-dlp 运行时尚未初始化");
                return;
            }

            File directory = new File(outputDirectory);
            if (!directory.exists() && !directory.mkdirs()) {
                finishDownload(requestId, false, "", "无法创建 Android 下载目录");
                return;
            }

            String outputTemplate = new File(
                    directory, "VideoDownloader-%(id)s.%(ext)s").getAbsolutePath();
            YtDlpRequest request = new YtDlpRequest(url)
                    .setOutputTemplate(outputTemplate)
                    .addOption("--no-playlist")
                    .addOption("--newline");

            if ("mp3".equalsIgnoreCase(format)) {
                if (!isFfmpegKitAvailable()) {
                    finishDownload(requestId, false, "",
                            "Android FFmpegKit 运行时未打入当前 APK，无法提取 MP3");
                    return;
                }
                // Download the source audio first. The Java yt-dlp wrapper
                // does not expose an executable FFmpeg path, so post-process
                // with the bundled FFmpegKit AAR in a second stage.
                request.addOption("-f", formatId == null || formatId.isEmpty()
                        ? "bestaudio/best" : formatId);
            } else {
                request.addOption("-f", formatId == null || formatId.isEmpty()
                        ? "best[ext=mp4]/best" : formatId);
            }

            LogCallback logCallback = (level, message) -> {
                if (message == null) {
                    return;
                }
                String candidate = message.trim();
                String destinationPrefix = "[download] Destination:";
                String mergerPrefix = "[Merger] Merging formats into:";
                if (candidate.startsWith(destinationPrefix)) {
                    String path = cleanPath(candidate.substring(destinationPrefix.length()));
                    outputPath.set(path);
                    REQUEST_OUTPUTS.put(requestId, path);
                } else if (candidate.startsWith(mergerPrefix)) {
                    String path = cleanPath(candidate.substring(mergerPrefix.length()));
                    outputPath.set(path);
                    REQUEST_OUTPUTS.put(requestId, path);
                }
            };

            DownloadProgressCallback progressCallback = (progress, eta, line) -> {
                String progressLine = line == null ? "" : line;
                MainActivity.updateDownloadForeground(requestId, progress, "正在下载");
                nativeHandleDownloadProgress(requestId, progress, eta, "", progressLine);
            };

            Future<YtDlpResponse> future = YtDlp.executeDebug(
                    request, logCallback, progressCallback);
            OPERATIONS.put(requestId, future);
            YtDlpResponse response = future.get();
            if (CANCELLED.containsKey(requestId)) {
                return;
            }
            if (!response.isSuccess()) {
                finishDownload(requestId, false, "", "yt-dlp 下载失败（退出码 "
                        + response.getExitCode() + "）");
                return;
            }

            String result = outputPath.get();
            if (result.isEmpty()) {
                result = newestOutput(directory, startedAt);
            }
            if (result.isEmpty()) {
                finishDownload(requestId, false, "", "下载完成但没有找到输出文件");
                return;
            }
            REQUEST_OUTPUTS.put(requestId, result);

            if ("mp3".equalsIgnoreCase(format)) {
                result = convertToMp3(requestId, result);
                if (result.isEmpty()) {
                    return;
                }
            }
            finishDownload(requestId, true, result, "");
            terminalSuccess = true;
        } catch (CancellationException ignored) {
            // cancel() already reported the terminal state to the Qt side.
        } catch (Exception exception) {
            if (!CANCELLED.containsKey(requestId)) {
                finishDownload(requestId, false, "", messageFor(exception));
            }
        } finally {
            if (CANCELLED.containsKey(requestId)) {
                cleanupTemporaryFiles(requestId);
            } else if (!terminalSuccess) {
                cleanupTemporaryFiles(requestId);
                cleanupTemporaryFilesEventually(
                        REQUEST_DIRECTORIES.get(requestId),
                        REQUEST_STARTED_AT.get(requestId),
                        REQUEST_OUTPUTS.get(requestId));
            }
            OPERATIONS.remove(requestId);
            FFMPEG_SESSIONS.remove(requestId);
            CANCELLED.remove(requestId);
            FINISHED.remove(requestId);
            REQUEST_DIRECTORIES.remove(requestId);
            REQUEST_TASK_IDS.remove(requestId);
            REQUEST_STARTED_AT.remove(requestId);
            REQUEST_OUTPUTS.remove(requestId);
        }
    }

    private static boolean isFfmpegKitAvailable() {
        try {
            Class.forName(FFMPEG_KIT_CLASS);
            return true;
        } catch (ClassNotFoundException ignored) {
            return false;
        }
    }

    private static String convertToMp3(String requestId, String sourcePath) throws Exception {
        File source = new File(sourcePath);
        if (!source.isFile()) {
            throw new IllegalStateException("找不到待转换的音频文件");
        }

        String lowerPath = sourcePath.toLowerCase();
        if (lowerPath.endsWith(".mp3")) {
            return sourcePath;
        }

        String outputPath = replaceExtension(sourcePath, ".mp3");
        REQUEST_OUTPUTS.put(requestId, outputPath);
        nativeHandleDownloadProgress(requestId, 0.85f, -1L, "", "正在使用 FFmpeg 转换为 MP3");

        final CountDownLatch completed = new CountDownLatch(1);
        final AtomicReference<Boolean> success = new AtomicReference<>(false);
        final AtomicReference<String> error = new AtomicReference<>("");

        Class<?> ffmpegKitClass = Class.forName(FFMPEG_KIT_CLASS);
        Class<?> completeCallbackClass = Class.forName(FFMPEG_COMPLETE_CALLBACK_CLASS);
        Class<?> logCallbackClass = Class.forName(FFMPEG_LOG_CALLBACK_CLASS);
        Class<?> statisticsCallbackClass = Class.forName(FFMPEG_STATISTICS_CALLBACK_CLASS);

        Object completeCallback = createCallback(completeCallbackClass, arguments -> {
            try {
                Object session = arguments != null && arguments.length > 0 ? arguments[0] : null;
                Object returnCode = session == null ? null : invoke(session, "getReturnCode");
                success.set(isReturnCodeSuccess(returnCode));
                if (!success.get()) {
                    Object failure = session == null ? null : invoke(session, "getFailStackTrace");
                    if (failure != null && !String.valueOf(failure).trim().isEmpty()) {
                        error.set(String.valueOf(failure));
                    } else {
                        Object output = session == null ? null : invoke(session, "getOutput");
                        error.set(output == null || String.valueOf(output).trim().isEmpty()
                                ? "FFmpeg MP3 转换失败" : String.valueOf(output));
                    }
                }
                Log.i(TAG, "FFmpeg MP3 session finished: success=" + success.get()
                        + ", error=" + error.get());
            } catch (Exception exception) {
                error.set(messageFor(exception));
                Log.e(TAG, "FFmpeg MP3 completion callback failed", exception);
            } finally {
                completed.countDown();
            }
        });

        Object logCallback = createCallback(logCallbackClass, arguments -> {
            if (arguments == null || arguments.length == 0 || arguments[0] == null) {
                return;
            }
            try {
                Object message = invoke(arguments[0], "getMessage");
                if (message != null && !String.valueOf(message).trim().isEmpty()) {
                    Log.i(TAG, "FFmpeg: " + String.valueOf(message).trim());
                    nativeHandleDownloadProgress(requestId, 0.9f, -1L, "",
                            "FFmpeg: " + String.valueOf(message).trim());
                }
            } catch (Exception ignored) {
                // A log callback must not interrupt the conversion session.
            }
        });

        Object statisticsCallback = createCallback(statisticsCallbackClass, arguments ->
                nativeHandleDownloadProgress(requestId, 0.9f, -1L, "", "正在转换为 MP3"));

        String[] arguments = {
                "-y",
                "-i", sourcePath,
                "-vn",
                "-codec:a", "libmp3lame",
                "-q:a", "2",
                outputPath
        };
        Method execute = ffmpegKitClass.getMethod(
                "executeWithArgumentsAsync",
                String[].class,
                completeCallbackClass,
                logCallbackClass,
                statisticsCallbackClass);
        Object session = execute.invoke(null, new Object[] {
                arguments, completeCallback, logCallback, statisticsCallback
        });
        FFMPEG_SESSIONS.put(requestId, session);
        if (CANCELLED.containsKey(requestId)) {
            cancelFfmpegSession(session);
        }

        while (!completed.await(250, TimeUnit.MILLISECONDS)) {
            if (CANCELLED.containsKey(requestId)) {
                cancelFfmpegSession(session);
            }
        }
        FFMPEG_SESSIONS.remove(requestId);

        if (CANCELLED.containsKey(requestId)) {
            throw new CancellationException();
        }
        if (!success.get() || !new File(outputPath).isFile()) {
            throw new IllegalStateException(error.get().isEmpty()
                    ? "FFmpeg MP3 转换失败" : error.get());
        }
        return outputPath;
    }

    private static Object createCallback(Class<?> callbackClass, CallbackHandler handler) {
        InvocationHandler invocationHandler = (proxy, method, arguments) -> {
            handler.handle(arguments);
            return null;
        };
        return Proxy.newProxyInstance(
                callbackClass.getClassLoader(),
                new Class<?>[] {callbackClass},
                invocationHandler);
    }

    private static Object invoke(Object target, String methodName) throws Exception {
        return target.getClass().getMethod(methodName).invoke(target);
    }

    private static boolean isReturnCodeSuccess(Object returnCode) throws Exception {
        if (returnCode == null) {
            return false;
        }
        Object value = invoke(returnCode, "isValueSuccess");
        return value instanceof Boolean && (Boolean) value;
    }

    private static void cancelFfmpegSession(Object session) {
        if (session == null) {
            return;
        }
        try {
            invoke(session, "cancel");
        } catch (Exception ignored) {
            // The completion callback will surface the failure/cancellation.
        }
    }

    private static void cleanupTemporaryFiles(String requestId) {
        cleanupTemporaryFiles(
                REQUEST_DIRECTORIES.get(requestId),
                REQUEST_STARTED_AT.get(requestId),
                REQUEST_OUTPUTS.get(requestId));
    }

    private static void cleanupTemporaryFilesEventually(String directoryPath,
                                                         Long startedAt,
                                                         String outputPath) {
        EXECUTOR.execute(() -> {
            for (int attempt = 0; attempt < 20; attempt++) {
                cleanupTemporaryFiles(directoryPath, startedAt, outputPath);
                if (!hasTemporaryFiles(directoryPath, startedAt, outputPath)) {
                    return;
                }
                try {
                    Thread.sleep(250);
                } catch (InterruptedException ignored) {
                    Thread.currentThread().interrupt();
                    return;
                }
            }
        });
    }

    private static void cleanupTemporaryFiles(String directoryPath,
                                              Long startedAt,
                                              String outputPath) {
        if (outputPath != null && !outputPath.isEmpty()) {
            String lowerOutputPath = outputPath.toLowerCase();
            if (lowerOutputPath.endsWith(".part") || lowerOutputPath.endsWith(".ytdl")) {
                deleteFile(outputPath);
            } else {
                deleteFile(outputPath + ".part");
                deleteFile(outputPath + ".ytdl");
                if (lowerOutputPath.endsWith(".mp3")) {
                    deleteFile(outputPath);
                }
            }
        }

        if (directoryPath == null || directoryPath.isEmpty() || startedAt == null) {
            return;
        }
        File directory = new File(directoryPath);
        File[] temporaryFiles = directory.listFiles(file -> file.isFile()
                && file.getName().startsWith("VideoDownloader-")
                && (file.getName().endsWith(".part") || file.getName().endsWith(".ytdl"))
                && file.lastModified() >= startedAt - 1000);
        if (temporaryFiles != null) {
            for (File file : temporaryFiles) {
                deleteFile(file.getAbsolutePath());
            }
        }
    }

    private static boolean hasTemporaryFiles(String directoryPath,
                                              Long startedAt,
                                              String outputPath) {
        if (outputPath != null && !outputPath.isEmpty()) {
            File knownOutput = new File(outputPath);
            String lowerOutputPath = outputPath.toLowerCase();
            if ((lowerOutputPath.endsWith(".part") || lowerOutputPath.endsWith(".ytdl"))
                    && knownOutput.isFile()) {
                return true;
            }
            if (new File(outputPath + ".part").isFile()
                    || new File(outputPath + ".ytdl").isFile()) {
                return true;
            }
        }
        if (directoryPath == null || directoryPath.isEmpty() || startedAt == null) {
            return false;
        }
        File directory = new File(directoryPath);
        File[] temporaryFiles = directory.listFiles(file -> file.isFile()
                && file.getName().startsWith("VideoDownloader-")
                && (file.getName().endsWith(".part") || file.getName().endsWith(".ytdl"))
                && file.lastModified() >= startedAt - 1000);
        return temporaryFiles != null && temporaryFiles.length > 0;
    }

    private static void deleteFile(String path) {
        if (path == null || path.isEmpty()) {
            return;
        }
        try {
            File file = new File(path);
            if (file.isFile() && !file.delete()) {
                Log.w(TAG, "Could not remove temporary output: " + path);
            }
        } catch (SecurityException exception) {
            Log.w(TAG, "Could not remove temporary output: " + path, exception);
        }
    }

    private static String replaceExtension(String path, String extension) {
        int separator = Math.max(path.lastIndexOf('/'), path.lastIndexOf('\\'));
        int dot = path.lastIndexOf('.');
        if (dot <= separator) {
            return path + extension;
        }
        return path.substring(0, dot) + extension;
    }

    private static String newestOutput(File directory, long startedAt) {
        File[] files = directory.listFiles(file -> file.isFile()
                && file.getName().startsWith("VideoDownloader-")
                && !file.getName().endsWith(".part")
                && !file.getName().endsWith(".ytdl")
                && file.lastModified() >= startedAt - 1000);
        File newest = newestFile(files);
        if (newest != null) {
            return newest.getAbsolutePath();
        }

        // yt-dlp may report "already downloaded" without emitting a new
        // Destination line. In that case the valid existing output is still
        // the result of this idempotent request, so use the newest matching
        // Video Downloader file as a fallback.
        files = directory.listFiles(file -> file.isFile()
                && file.getName().startsWith("VideoDownloader-")
                && !file.getName().endsWith(".part")
                && !file.getName().endsWith(".ytdl"));
        newest = newestFile(files);
        return newest == null ? "" : newest.getAbsolutePath();
    }

    private static File newestFile(File[] files) {
        if (files == null || files.length == 0) {
            return null;
        }

        File newest = files[0];
        for (File file : files) {
            if (file.lastModified() > newest.lastModified()) {
                newest = file;
            }
        }
        return newest;
    }

    private static void setOption(PyObject options, String key, Object value) {
        options.callAttr("__setitem__", key, value);
    }

    private static String cleanPath(String value) {
        String result = value == null ? "" : value.trim();
        if (result.length() >= 2 && result.startsWith("\"") && result.endsWith("\"")) {
            result = result.substring(1, result.length() - 1);
        }
        return result;
    }

    private static String messageFor(Exception exception) {
        Throwable cause = exception;
        while (cause.getCause() != null) {
            cause = cause.getCause();
        }
        String message = cause.getMessage();
        return message == null || message.isEmpty()
                ? cause.getClass().getSimpleName() : message;
    }

    private static void finishInspection(String requestId,
                                         boolean success,
                                         String payload,
                                         String error) {
        try {
            nativeHandleInspectionFinished(requestId, success, payload, error);
        } catch (UnsatisfiedLinkError ignored) {
            // The Qt JNI registration may still be in progress during startup.
        }
    }

    private static void finishDownload(String requestId,
                                       boolean success,
                                       String outputPath,
                                       String error) {
        if (FINISHED.putIfAbsent(requestId, true) != null) {
            return;
        }
        MainActivity.finishDownloadForeground(
                requestId, REQUEST_TASK_IDS.getOrDefault(requestId, ""), success, error);
        try {
            nativeHandleDownloadFinished(requestId, success, outputPath, error);
        } catch (UnsatisfiedLinkError ignored) {
            // The Qt JNI registration may still be in progress during startup.
        }
    }

    private static native void nativeHandleInspectionFinished(String requestId,
                                                               boolean success,
                                                               String payload,
                                                               String errorMessage);
    private static native void nativeHandleDownloadProgress(String requestId,
                                                             float progress,
                                                             long eta,
                                                             String speed,
                                                             String line);
    private static native void nativeHandleDownloadFinished(String requestId,
                                                            boolean success,
                                                            String outputPath,
                                                            String errorMessage);
}

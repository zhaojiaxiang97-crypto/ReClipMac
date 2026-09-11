package com.reclip.videodownloader;

import android.Manifest;
import android.content.ActivityNotFoundException;
import android.content.ClipData;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.net.Uri;
import android.os.Bundle;
import android.os.Build;
import android.provider.DocumentsContract;
import android.text.TextUtils;
import android.util.Log;

import androidx.core.content.FileProvider;

import org.qtproject.qt.android.bindings.QtActivity;

import java.io.File;
import java.io.FileNotFoundException;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.io.OutputStream;
import java.lang.reflect.Method;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

public class MainActivity extends QtActivity {
    private static final String TAG = "VideoDownloader";
    private static final int REQUEST_EXPORT_DIRECTORY = 1701;
    private static final int REQUEST_NOTIFICATIONS = 1702;
    private static final String EXTERNAL_STORAGE_AUTHORITY = "com.android.externalstorage.documents";
    private static final ExecutorService STORAGE_EXECUTOR = Executors.newSingleThreadExecutor();
    private static final ExecutorService RUNTIME_EXECUTOR = Executors.newSingleThreadExecutor();
    private static String pendingUrl;
    private static MainActivity currentActivity;
    private static Context applicationContext;
    private static String pendingRetryTaskId;

    @Override
    public void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        currentActivity = this;
        applicationContext = getApplicationContext();
        requestNotificationPermission();
        prepareBundledRuntime();
        attachYtDlpRuntimeContext();
        probeYtDlpAndroidRuntime();
        captureIntent(getIntent());
    }

    @Override
    public void onNewIntent(Intent intent) {
        super.onNewIntent(intent);
        setIntent(intent);
        captureIntent(intent);
    }

    @Override
    protected void onDestroy() {
        if (currentActivity == this) {
            currentActivity = null;
        }
        super.onDestroy();
    }

    public static String consumePendingUrl() {
        String value = pendingUrl;
        pendingUrl = null;
        return value;
    }

    public static String consumePendingRetryTaskId() {
        String value = pendingRetryTaskId;
        pendingRetryTaskId = null;
        return value;
    }

    public static void startDownloadForeground(String requestId, String title) {
        startDownloadForeground(requestId, title, "");
    }

    public static void startDownloadForeground(String requestId, String title, String taskId) {
        Context context = applicationContext;
        if (context != null) {
            DownloadForegroundService.start(context, requestId, title, taskId);
        }
    }

    public static void updateDownloadForeground(String requestId, float progress, String status) {
        DownloadForegroundService.update(requestId, progress, status);
    }

    public static void finishDownloadForeground(String requestId, boolean success, String error) {
        finishDownloadForeground(requestId, "", success, error);
    }

    public static void finishDownloadForeground(String requestId,
                                                String taskId,
                                                boolean success,
                                                String error) {
        Context context = applicationContext;
        if (context != null) {
            DownloadForegroundService.finish(context, requestId, taskId, success, error);
        }
    }

    public static void cancelAndroidRequest(String requestId) {
        if (TextUtils.isEmpty(requestId)) {
            return;
        }
        try {
            Class<?> bridgeClass = Class.forName(
                    "com.reclip.videodownloader.AndroidYtDlpBridge");
            Method cancel = bridgeClass.getMethod("cancel", String.class);
            cancel.invoke(null, requestId);
        } catch (ClassNotFoundException ignored) {
            // The dependency-free APK has no active Android download bridge.
        } catch (Exception exception) {
            Log.e(TAG, "Unable to cancel Android download from notification", exception);
        }
    }

    public static void chooseExportDirectory() {
        final MainActivity activity = currentActivity;
        if (activity == null) {
            reportStorageError("Android 页面尚未准备好，暂时无法选择导出目录");
            return;
        }

        Intent intent = new Intent(Intent.ACTION_OPEN_DOCUMENT_TREE);
        intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION
                | Intent.FLAG_GRANT_WRITE_URI_PERMISSION
                | Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION
                | Intent.FLAG_GRANT_PREFIX_URI_PERMISSION);
        // A storage root cannot be granted on Android 11+. Start in the
        // conventional Download directory so the user lands on a selectable
        // child directory instead of an unusable root.
        intent.putExtra(
                "android.provider.extra.INITIAL_URI",
                DocumentsContract.buildTreeDocumentUri(
                        EXTERNAL_STORAGE_AUTHORITY, "primary:Download"));
        try {
            activity.startActivityForResult(intent, REQUEST_EXPORT_DIRECTORY);
        } catch (ActivityNotFoundException exception) {
            reportStorageError("系统没有可用的文件夹选择器");
        }
    }

    @Override
    protected void onActivityResult(int requestCode, int resultCode, Intent data) {
        super.onActivityResult(requestCode, resultCode, data);
        if (requestCode != REQUEST_EXPORT_DIRECTORY || resultCode != RESULT_OK || data == null) {
            return;
        }

        Uri treeUri = data.getData();
        if (treeUri == null) {
            reportStorageError("文件夹选择器没有返回有效目录");
            return;
        }

        int takeFlags = data.getFlags() & (Intent.FLAG_GRANT_READ_URI_PERMISSION
                | Intent.FLAG_GRANT_WRITE_URI_PERMISSION);
        if (takeFlags == 0) {
            takeFlags = Intent.FLAG_GRANT_READ_URI_PERMISSION | Intent.FLAG_GRANT_WRITE_URI_PERMISSION;
        }
        try {
            getContentResolver().takePersistableUriPermission(treeUri, takeFlags);
        } catch (Exception exception) {
            reportStorageError("无法保存导出目录权限，请重新选择目录");
            return;
        }

        try {
            nativeHandleExportDirectory(treeUri.toString(), directoryLabel(treeUri));
        } catch (UnsatisfiedLinkError ignored) {
            // The native bridge is registered after Qt starts. A picker action
            // is only available after that point, so this is just defensive.
        }
    }

    public static void exportFile(final String requestId,
                                  final String sourcePath,
                                  final String treeUri,
                                  final String displayName,
                                  final String mimeType) {
        final MainActivity activity = currentActivity;
        if (activity == null) {
            reportExportFinished(requestId, false, "Android 页面尚未准备好");
            return;
        }

        STORAGE_EXECUTOR.execute(() -> {
            String result = null;
            boolean success = false;
            try {
                Uri tree = Uri.parse(treeUri);
                String treeDocumentId = DocumentsContract.getTreeDocumentId(tree);
                if (TextUtils.isEmpty(treeDocumentId)) {
                    throw new IllegalStateException("导出目录 URI 无效");
                }
                Uri parent = DocumentsContract.buildDocumentUriUsingTree(tree, treeDocumentId);
                Uri destination = DocumentsContract.createDocument(
                        activity.getContentResolver(), parent, mimeType, safeDisplayName(displayName));
                if (destination == null) {
                    throw new IllegalStateException("系统文件管理器拒绝创建导出文件");
                }
                try (InputStream input = new FileInputStream(new File(sourcePath));
                     OutputStream output = activity.getContentResolver().openOutputStream(destination)) {
                    if (output == null) {
                        throw new IllegalStateException("无法打开导出文件写入流");
                    }
                    byte[] buffer = new byte[1024 * 1024];
                    int count;
                    while ((count = input.read(buffer)) != -1) {
                        output.write(buffer, 0, count);
                    }
                    output.flush();
                }
                result = destination.toString();
                success = true;
            } catch (Exception exception) {
                result = exportErrorMessage(exception);
                Log.e(TAG, "SAF export failed", exception);
            }
            reportExportFinished(requestId, success, result == null ? "文件导出失败" : result);
        });
    }

    public static boolean deleteExportedFile(String exportedUri) {
        if (TextUtils.isEmpty(exportedUri)) {
            return true;
        }

        final MainActivity activity = currentActivity;
        if (activity == null) {
            return false;
        }

        try {
            Uri uri = Uri.parse(exportedUri);
            if ("content".equalsIgnoreCase(uri.getScheme())) {
                try {
                    return DocumentsContract.deleteDocument(activity.getContentResolver(), uri);
                } catch (FileNotFoundException exception) {
                    // The file is already gone, so the requested end state is met.
                    return true;
                }
            }
            if ("file".equalsIgnoreCase(uri.getScheme())) {
                File file = new File(uri.getPath());
                return !file.exists() || file.delete();
            }
        } catch (Exception exception) {
            Log.e(TAG, "Unable to delete exported file: " + exportedUri, exception);
        }
        return false;
    }

    public static void openFile(String sourcePath, String exportedUri, String mimeType) {
        final MainActivity activity = currentActivity;
        if (activity == null) {
            reportStorageError("Android 页面尚未准备好");
            return;
        }

        try {
            Uri uri = readableUri(activity, sourcePath, exportedUri);
            Intent intent = new Intent(Intent.ACTION_VIEW);
            intent.setDataAndType(uri, TextUtils.isEmpty(mimeType) ? "application/octet-stream" : mimeType);
            intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION | Intent.FLAG_ACTIVITY_NEW_TASK);
            intent.setClipData(ClipData.newRawUri("Video Downloader", uri));
            activity.startActivity(intent);
        } catch (Exception exception) {
            reportStorageError("无法打开文件：" + exportErrorMessage(exception));
        }
    }

    public static void shareFile(String sourcePath, String exportedUri, String mimeType) {
        final MainActivity activity = currentActivity;
        if (activity == null) {
            reportStorageError("Android 页面尚未准备好");
            return;
        }

        try {
            Uri uri = readableUri(activity, sourcePath, exportedUri);
            Intent intent = new Intent(Intent.ACTION_SEND);
            intent.setType(TextUtils.isEmpty(mimeType) ? "application/octet-stream" : mimeType);
            intent.putExtra(Intent.EXTRA_STREAM, uri);
            intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION | Intent.FLAG_ACTIVITY_NEW_TASK);
            intent.setClipData(ClipData.newRawUri("Video Downloader", uri));
            activity.startActivity(Intent.createChooser(intent, "分享文件"));
        } catch (Exception exception) {
            reportStorageError("无法分享文件：" + exportErrorMessage(exception));
        }
    }

    public static void openDirectory(String directoryUri) {
        final MainActivity activity = currentActivity;
        if (activity == null || TextUtils.isEmpty(directoryUri)) {
            reportStorageError("没有可打开的导出目录");
            return;
        }

        try {
            Intent intent = new Intent(Intent.ACTION_OPEN_DOCUMENT_TREE);
            intent.putExtra("android.provider.extra.INITIAL_URI", Uri.parse(directoryUri));
            intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION
                    | Intent.FLAG_GRANT_WRITE_URI_PERMISSION
                    | Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION
                    | Intent.FLAG_GRANT_PREFIX_URI_PERMISSION);
            activity.startActivityForResult(intent, REQUEST_EXPORT_DIRECTORY);
        } catch (Exception exception) {
            reportStorageError("无法打开导出目录：" + exportErrorMessage(exception));
        }
    }

    private static Uri readableUri(MainActivity activity, String sourcePath, String exportedUri) {
        if (!TextUtils.isEmpty(exportedUri)
                && (exportedUri.startsWith("content://") || exportedUri.startsWith("file://"))) {
            return Uri.parse(exportedUri);
        }

        File file = new File(sourcePath);
        if (!file.isFile()) {
            throw new IllegalStateException("文件不存在");
        }
        return FileProvider.getUriForFile(
                activity,
                activity.getPackageName() + ".qtprovider",
                file);
    }

    private static String directoryLabel(Uri treeUri) {
        try {
            String documentId = DocumentsContract.getTreeDocumentId(treeUri);
            String decoded = Uri.decode(documentId);
            int separator = decoded.indexOf(':');
            if (separator >= 0 && separator + 1 < decoded.length()) {
                decoded = decoded.substring(separator + 1);
            }
            int slash = decoded.lastIndexOf('/');
            if (slash >= 0 && slash + 1 < decoded.length()) {
                decoded = decoded.substring(slash + 1);
            }
            if (!TextUtils.isEmpty(decoded)) {
                return decoded;
            }
        } catch (Exception ignored) {
            // Use the generic label below when a provider does not expose an id.
        }
        return "已选择的目录";
    }

    private static String safeDisplayName(String displayName) {
        if (TextUtils.isEmpty(displayName)) {
            return "VideoDownloader-output";
        }
        String clean = displayName.replace('/', '_').replace('\\', '_').trim();
        return TextUtils.isEmpty(clean) ? "VideoDownloader-output" : clean;
    }

    private static String exportErrorMessage(Exception exception) {
        if (exception instanceof SecurityException) {
            return "导出目录权限已失效，请重新选择目录";
        }
        String message = exception.getMessage();
        return TextUtils.isEmpty(message) ? exception.getClass().getSimpleName() : message;
    }

    private void prepareBundledRuntime() {
        try {
            String[] entries = getAssets().list("bin");
            if (entries == null || entries.length == 0) {
                return;
            }

            File runtimeDirectory = new File(getFilesDir(), "bin");
            if (!runtimeDirectory.exists() && !runtimeDirectory.mkdirs()) {
                return;
            }

            for (String entry : entries) {
                if (TextUtils.isEmpty(entry) || entry.contains("/")
                        || entry.equals(".") || entry.equals("..")) {
                    continue;
                }

                File target = new File(runtimeDirectory, entry);
                if (target.isFile() && target.length() > 0) {
                    target.setExecutable(true, false);
                    continue;
                }

                File temporary = new File(runtimeDirectory, entry + ".tmp");
                try (InputStream input = getAssets().open("bin/" + entry);
                     OutputStream output = new FileOutputStream(temporary)) {
                    byte[] buffer = new byte[1024 * 1024];
                    int count;
                    while ((count = input.read(buffer)) != -1) {
                        output.write(buffer, 0, count);
                    }
                    output.flush();
                }
                if (target.exists()) {
                    target.delete();
                }
                if (temporary.renameTo(target)) {
                    target.setExecutable(true, false);
                } else {
                    temporary.delete();
                }
            }
        } catch (Exception ignored) {
            // Missing optional assets must not prevent the application shell
            // from starting; ToolLocator reports the actionable path later.
        }
    }

    private void requestNotificationPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU
                && checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS)
                != PackageManager.PERMISSION_GRANTED) {
            requestPermissions(new String[] {Manifest.permission.POST_NOTIFICATIONS},
                    REQUEST_NOTIFICATIONS);
        }
    }

    /**
     * The embedded Python engine is an optional build-time dependency for the
     * Android target. Keep the base APK buildable without the large AAR, while
     * making an AAR-enabled APK self-test its runtime on a real device.
     */
    private void probeYtDlpAndroidRuntime() {
        RUNTIME_EXECUTOR.execute(() -> {
            try {
                Class<?> bridgeClass = Class.forName(
                        "com.reclip.videodownloader.AndroidYtDlpBridge");
                Method attachContext = bridgeClass.getMethod(
                        "attachContext", android.content.Context.class);
                attachContext.invoke(null, this);
                Method initialize = bridgeClass.getMethod("initialize");
                initialize.invoke(null);
                Log.i(TAG, "yt-dlp Android runtime initialized");
                return;
            } catch (ClassNotFoundException ignored) {
                // The base Android APK deliberately omits the optional AAR.
            } catch (Exception exception) {
                Log.e(TAG, "yt-dlp Android runtime initialization failed", exception);
                return;
            }

            try {
                Class<?> ytDlpClass = Class.forName(
                        "dev.ffmpegkit_maintained.ytdlp.YtDlp");
                Method init = ytDlpClass.getMethod("init", android.content.Context.class);
                init.invoke(null, this);
                Log.i(TAG, "yt-dlp Android runtime initialized");
            } catch (ClassNotFoundException exception) {
                Log.i(TAG, "yt-dlp Android runtime is not bundled in this APK");
            } catch (Exception exception) {
                Log.e(TAG, "yt-dlp Android runtime initialization failed", exception);
            }
        });
    }

    private void attachYtDlpRuntimeContext() {
        try {
            Class<?> bridgeClass = Class.forName(
                    "com.reclip.videodownloader.AndroidYtDlpBridge");
            Method attachContext = bridgeClass.getMethod(
                    "attachContext", android.content.Context.class);
            attachContext.invoke(null, this);
        } catch (ClassNotFoundException ignored) {
            // The base Android APK deliberately omits the optional AAR.
        } catch (Exception exception) {
            Log.e(TAG, "Unable to attach Android yt-dlp runtime context", exception);
        }
    }

    private static void reportExportFinished(String requestId, boolean success, String result) {
        try {
            nativeHandleExportFinished(requestId, success, result);
        } catch (UnsatisfiedLinkError ignored) {
            // Defensive fallback for a bridge call during process startup.
        }
    }

    private static void reportStorageError(String message) {
        try {
            nativeHandleStorageError(message);
        } catch (UnsatisfiedLinkError ignored) {
            // Defensive fallback for a bridge call during process startup.
        }
    }

    private static void captureIntent(Intent intent) {
        if (intent == null) {
            return;
        }

        String value = null;
        String action = intent.getAction();
        if (DownloadForegroundService.ACTION_RETRY.equals(action)) {
            String taskId = intent.getStringExtra(DownloadForegroundService.EXTRA_TASK_ID);
            if (taskId != null && !taskId.trim().isEmpty()) {
                pendingRetryTaskId = taskId.trim();
            }
            return;
        } else if (Intent.ACTION_SEND.equals(action)) {
            CharSequence text = intent.getCharSequenceExtra(Intent.EXTRA_TEXT);
            if (text != null) {
                value = text.toString();
            }
        } else if (Intent.ACTION_VIEW.equals(action) && intent.getData() != null) {
            value = intent.getDataString();
        }

        if (value == null || value.trim().isEmpty()) {
            return;
        }

        pendingUrl = value.trim();
        try {
            nativeHandleUrl(pendingUrl);
        } catch (UnsatisfiedLinkError ignored) {
            // The native bridge is registered after Qt starts. The value stays
            // in pendingUrl so AppController can consume it during startup.
        }
    }

    private static native void nativeHandleUrl(String url);
    private static native void nativeHandleExportDirectory(String uri, String label);
    private static native void nativeHandleExportFinished(String requestId, boolean success, String result);
    private static native void nativeHandleStorageError(String message);
}

package com.reclip.videodownloader;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.app.Service;
import android.content.Context;
import android.content.Intent;
import android.os.Build;
import android.os.IBinder;
import android.text.TextUtils;

/**
 * Keeps a long-running Android download visible and important to the system.
 * The actual yt-dlp operation remains in AndroidYtDlpBridge; this service owns
 * only the lifecycle and user-visible notification.
 */
public final class DownloadForegroundService extends Service {
    public static final String ACTION_START = "com.reclip.videodownloader.action.START";
    public static final String ACTION_UPDATE = "com.reclip.videodownloader.action.UPDATE";
    public static final String ACTION_FINISH = "com.reclip.videodownloader.action.FINISH";
    public static final String ACTION_CANCEL = "com.reclip.videodownloader.action.CANCEL";
    public static final String ACTION_RETRY = "com.reclip.videodownloader.action.RETRY";
    public static final String EXTRA_REQUEST_ID = "requestId";
    public static final String EXTRA_TASK_ID = "taskId";
    public static final String EXTRA_TITLE = "title";
    public static final String EXTRA_PROGRESS = "progress";
    public static final String EXTRA_STATUS = "status";
    public static final String EXTRA_SUCCESS = "success";
    public static final String EXTRA_ERROR = "error";

    private static final String CHANNEL_ID = "downloads";
    private static final int NOTIFICATION_ID = 4101;
    private static final int TERMINAL_NOTIFICATION_ID = 4102;
    private static final int REQUEST_OPEN_APP = 4102;
    private static final int REQUEST_CANCEL = 4103;
    private static final int REQUEST_RETRY = 4104;

    private static volatile DownloadForegroundService instance;
    private static volatile String lastRequestId = "";
    private static volatile String lastTaskId = "";
    private static volatile String lastTitle = "Video Downloader";
    private static volatile int lastProgress;
    private static volatile String lastStatus = "准备下载";

    private String requestId = "";
    private String taskId = "";
    private String title = "Video Downloader";
    private int progress;
    private String status = "准备下载";

    @Override
    public void onCreate() {
        super.onCreate();
        instance = this;
        createNotificationChannel();
        requestId = lastRequestId;
        taskId = lastTaskId;
        title = lastTitle;
        progress = lastProgress;
        status = lastStatus;
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        if (intent == null) {
            startForeground(NOTIFICATION_ID, buildNotification(true, status));
            return START_NOT_STICKY;
        }

        String action = intent.getAction();
        if (ACTION_CANCEL.equals(action)) {
            String requestedId = intent.getStringExtra(EXTRA_REQUEST_ID);
            if (TextUtils.isEmpty(requestedId)) {
                requestedId = requestId;
            }
            MainActivity.cancelAndroidRequest(requestedId);
            status = "正在取消…";
            updateForegroundNotification(true, status);
            return START_NOT_STICKY;
        }

        if (ACTION_FINISH.equals(action)) {
            requestId = valueOrFallback(intent.getStringExtra(EXTRA_REQUEST_ID), requestId);
            title = valueOrFallback(intent.getStringExtra(EXTRA_TITLE), title);
            taskId = valueOrFallback(intent.getStringExtra(EXTRA_TASK_ID), taskId);
            progress = 100;
            boolean success = intent.getBooleanExtra(EXTRA_SUCCESS, false);
            String error = intent.getStringExtra(EXTRA_ERROR);
            String terminalStatus = success ? "下载完成" : "下载失败";
            if (!TextUtils.isEmpty(error)) {
                terminalStatus += "：" + error;
            }
            lastRequestId = requestId;
            lastTaskId = taskId;
            lastTitle = title;
            lastProgress = progress;
            lastStatus = terminalStatus;
            stopForeground(false);
            publishTerminalNotification(success, terminalStatus);
            stopSelfResult(startId);
            return START_NOT_STICKY;
        }

        requestId = valueOrFallback(intent.getStringExtra(EXTRA_REQUEST_ID), requestId);
        title = valueOrFallback(intent.getStringExtra(EXTRA_TITLE), title);
        taskId = valueOrFallback(intent.getStringExtra(EXTRA_TASK_ID), taskId);
        progress = clampProgress(intent.getIntExtra(EXTRA_PROGRESS, progress));
        status = valueOrFallback(intent.getStringExtra(EXTRA_STATUS), status);
        lastRequestId = requestId;
        lastTaskId = taskId;
        lastTitle = title;
        lastProgress = progress;
        lastStatus = status;
        startForeground(NOTIFICATION_ID, buildNotification(true, status));
        return START_NOT_STICKY;
    }

    @Override
    public void onDestroy() {
        if (instance == this) {
            instance = null;
        }
        super.onDestroy();
    }

    @Override
    public IBinder onBind(Intent intent) {
        return null;
    }

    public static void start(Context context, String requestId, String title) {
        start(context, requestId, title, "");
    }

    public static void start(Context context, String requestId, String title, String taskId) {
        if (context == null) {
            return;
        }
        lastRequestId = requestId == null ? "" : requestId;
        lastTaskId = taskId == null ? "" : taskId;
        lastTitle = TextUtils.isEmpty(title) ? "Video Downloader" : title;
        lastProgress = 0;
        lastStatus = "正在下载";
        Intent intent = new Intent(context.getApplicationContext(), DownloadForegroundService.class)
                .setAction(ACTION_START)
                .putExtra(EXTRA_REQUEST_ID, lastRequestId)
                .putExtra(EXTRA_TASK_ID, lastTaskId)
                .putExtra(EXTRA_TITLE, lastTitle)
                .putExtra(EXTRA_PROGRESS, 0)
                .putExtra(EXTRA_STATUS, lastStatus);
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.getApplicationContext().startForegroundService(intent);
        } else {
            context.getApplicationContext().startService(intent);
        }
    }

    public static void update(String requestId, float fraction, String status) {
        if (!TextUtils.isEmpty(requestId) && !requestId.equals(lastRequestId)) {
            return;
        }
        lastProgress = clampProgress(Math.round(fraction * 100.0f));
        if (!TextUtils.isEmpty(status)) {
            lastStatus = status;
        }
        DownloadForegroundService service = instance;
        if (service != null) {
            service.requestId = lastRequestId;
            service.progress = lastProgress;
            service.status = lastStatus;
            service.updateForegroundNotification(true, service.status);
        }
    }

    public static void finish(Context context,
                               String requestId,
                               boolean success,
                               String error) {
        finish(context, requestId, "", success, error);
    }

    public static void finish(Context context,
                               String requestId,
                               String taskId,
                               boolean success,
                               String error) {
        if (!TextUtils.isEmpty(requestId) && !requestId.equals(lastRequestId)) {
            return;
        }
        Intent intent = new Intent(context.getApplicationContext(), DownloadForegroundService.class)
                .setAction(ACTION_FINISH)
                .putExtra(EXTRA_REQUEST_ID, requestId == null ? "" : requestId)
                .putExtra(EXTRA_TASK_ID, taskId == null ? "" : taskId)
                .putExtra(EXTRA_TITLE, lastTitle)
                .putExtra(EXTRA_SUCCESS, success)
                .putExtra(EXTRA_ERROR, error == null ? "" : error);
        context.getApplicationContext().startService(intent);
    }

    private void updateForegroundNotification(boolean ongoing, String notificationStatus) {
        NotificationManager manager = getSystemService(NotificationManager.class);
        if (manager != null) {
            manager.notify(NOTIFICATION_ID, buildNotification(ongoing, notificationStatus));
        }
    }

    private void publishTerminalNotification(boolean success, String notificationStatus) {
        NotificationManager manager = getSystemService(NotificationManager.class);
        if (manager != null) {
            manager.notify(TERMINAL_NOTIFICATION_ID,
                    buildNotification(false, notificationStatus, !success && !taskId.isEmpty()));
        }
    }

    private Notification buildNotification(boolean ongoing, String notificationStatus) {
        return buildNotification(ongoing, notificationStatus, false);
    }

    private Notification buildNotification(boolean ongoing,
                                           String notificationStatus,
                                           boolean retryAllowed) {
        Intent openIntent = new Intent(this, MainActivity.class)
                .setAction(Intent.ACTION_MAIN)
                .addCategory(Intent.CATEGORY_LAUNCHER)
                .addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP | Intent.FLAG_ACTIVITY_CLEAR_TOP);
        PendingIntent openPendingIntent = PendingIntent.getActivity(
                this,
                REQUEST_OPEN_APP,
                openIntent,
                PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);

        Notification.Builder builder = Build.VERSION.SDK_INT >= Build.VERSION_CODES.O
                ? new Notification.Builder(this, CHANNEL_ID)
                : new Notification.Builder(this);
        builder.setSmallIcon(getApplicationInfo().icon == 0
                        ? android.R.drawable.stat_sys_download
                        : getApplicationInfo().icon)
                .setContentTitle(title)
                .setContentText(notificationStatus)
                .setContentIntent(openPendingIntent)
                .setOnlyAlertOnce(true)
                .setOngoing(ongoing)
                .setAutoCancel(!ongoing)
                .setCategory(Notification.CATEGORY_PROGRESS);

        if (ongoing) {
            builder.setProgress(100, progress, false);
            Intent cancelIntent = new Intent(this, DownloadForegroundService.class)
                    .setAction(ACTION_CANCEL)
                    .putExtra(EXTRA_REQUEST_ID, requestId);
            PendingIntent cancelPendingIntent = PendingIntent.getService(
                    this,
                    REQUEST_CANCEL,
                    cancelIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
            builder.addAction(new Notification.Action.Builder(
                    null, "取消", cancelPendingIntent).build());
        } else {
            builder.setProgress(0, 0, false);
            if (retryAllowed) {
                Intent retryIntent = new Intent(this, MainActivity.class)
                        .setAction(ACTION_RETRY)
                        .putExtra(EXTRA_TASK_ID, taskId)
                        .addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP | Intent.FLAG_ACTIVITY_CLEAR_TOP);
                PendingIntent retryPendingIntent = PendingIntent.getActivity(
                        this,
                        REQUEST_RETRY,
                        retryIntent,
                        PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
                builder.addAction(new Notification.Action.Builder(
                        null, "重试", retryPendingIntent).build());
            }
        }
        return builder.build();
    }

    private void createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return;
        }
        NotificationManager manager = getSystemService(NotificationManager.class);
        if (manager != null) {
            NotificationChannel channel = new NotificationChannel(
                    CHANNEL_ID, "下载任务", NotificationManager.IMPORTANCE_LOW);
            channel.setDescription("显示视频下载的进度和结果");
            manager.createNotificationChannel(channel);
        }
    }

    private static int clampProgress(int value) {
        return Math.max(0, Math.min(100, value));
    }

    private static String valueOrFallback(String value, String fallback) {
        return TextUtils.isEmpty(value) ? fallback : value;
    }
}

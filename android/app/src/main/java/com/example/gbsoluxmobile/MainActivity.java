package com.example.gbsoluxmobile;

import android.app.DownloadManager;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.database.Cursor;
import android.net.Uri;
import android.os.Bundle;
import android.os.Environment;
import android.webkit.CookieManager;
import android.widget.Toast;
import androidx.core.content.FileProvider;
import io.flutter.embedding.android.FlutterActivity;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.embedding.engine.FlutterEngine;
import java.io.File;

public class MainActivity extends FlutterActivity {
    private static final String CHANNEL = "com.example.gbsoluxmobile/file";
    private long currentDownloadId = -1;
    private BroadcastReceiver downloadReceiver;

    @Override
    public void configureFlutterEngine(FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);
        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL)
                .setMethodCallHandler(
                        (call, result) -> {
                            if (call.method.equals("downloadFile")) {
                                String url = call.argument("url");
                                String filename = call.argument("filename");
                                String mimeType = call.argument("mimeType");
                                downloadFile(url, filename, mimeType, result);
                            } else if (call.method.equals("openFile")) {
                                String url = call.argument("url");
                                openFile(url, result);
                            } else if (call.method.equals("showFileChooser")) {
                                showFileChooser(result);
                            } else {
                                result.notImplemented();
                            }
                        }
                );

        // Register download completion receiver
        registerDownloadReceiver();
    }

    @Override
    protected void onDestroy() {
        super.onDestroy();
        if (downloadReceiver != null) {
            unregisterReceiver(downloadReceiver);
        }
    }

    private void downloadFile(String url, String filename, String mimeType, MethodChannel.Result result) {
        try {
            DownloadManager downloadManager = (DownloadManager) getSystemService(Context.DOWNLOAD_SERVICE);
            Uri uri = Uri.parse(url);
            DownloadManager.Request request = new DownloadManager.Request(uri);

            // Add cookies for authentication
            CookieManager cookieManager = CookieManager.getInstance();
            String cookieString = cookieManager.getCookie(url);
            if (cookieString != null && !cookieString.isEmpty()) {
                request.addRequestHeader("Cookie", cookieString);
            }

            // Set proper filename with extension if missing
            if (filename != null && !filename.contains(".")) {
                // Try to infer extension from mimeType
                if (mimeType != null) {
                    if (mimeType.contains("pdf")) {
                        filename += ".pdf";
                    } else if (mimeType.contains("image/jpeg")) {
                        filename += ".jpg";
                    } else if (mimeType.contains("image/png")) {
                        filename += ".png";
                    } else if (mimeType.contains("text")) {
                        filename += ".txt";
                    }
                }
            }

            request.setTitle(filename != null ? filename : "Download");
            request.setDescription("Downloading file...");
            request.setNotificationVisibility(DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED);

            // Use appropriate directory based on file type
            String directory = Environment.DIRECTORY_DOWNLOADS;
            if (mimeType != null && mimeType.contains("image")) {
                directory = Environment.DIRECTORY_PICTURES;
            }

            request.setDestinationInExternalPublicDir(directory, filename);
            request.setMimeType(mimeType);

            // Allow downloads over mobile data and WiFi
            request.setAllowedNetworkTypes(DownloadManager.Request.NETWORK_WIFI | DownloadManager.Request.NETWORK_MOBILE);

            currentDownloadId = downloadManager.enqueue(request);
            Toast.makeText(this, "Téléchargement démarré: " + (filename != null ? filename : "Fichier"), Toast.LENGTH_SHORT).show();
            result.success("Download started with ID: " + currentDownloadId);
        } catch (Exception e) {
            result.error("DOWNLOAD_FAILED", e.getMessage(), null);
        }
    }

    private void openFile(String url, MethodChannel.Result result) {
        try {
            // Check if it's a local file path or URL
            File file = new File(url);
            Uri fileUri;

            if (file.exists()) {
                // Local file - use FileProvider for Android 7+
                fileUri = FileProvider.getUriForFile(this, getApplicationContext().getPackageName() + ".fileprovider", file);
            } else {
                // URL - parse directly
                fileUri = Uri.parse(url);
            }

            Intent intent = new Intent(Intent.ACTION_VIEW);
            intent.setDataAndType(fileUri, getMimeTypeFromUri(fileUri));
            intent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_GRANT_READ_URI_PERMISSION);
            startActivity(intent);
            result.success("File opened");
        } catch (Exception e) {
            Toast.makeText(this, "Impossible d'ouvrir le fichier: " + e.getMessage(), Toast.LENGTH_LONG).show();
            result.error("OPEN_FAILED", e.getMessage(), null);
        }
    }

    private String getMimeTypeFromUri(Uri uri) {
        String path = uri.getPath();
        if (path != null) {
            if (path.endsWith(".pdf")) return "application/pdf";
            if (path.endsWith(".jpg") || path.endsWith(".jpeg")) return "image/jpeg";
            if (path.endsWith(".png")) return "image/png";
            if (path.endsWith(".doc")) return "application/msword";
            if (path.endsWith(".docx")) return "application/vnd.openxmlformats-officedocument.wordprocessingml.document";
            if (path.endsWith(".xls")) return "application/vnd.ms-excel";
            if (path.endsWith(".xlsx")) return "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet";
        }
        return "*/*";
    }

    private void showFileChooser(MethodChannel.Result result) {
        try {
            Intent intent = new Intent(Intent.ACTION_GET_CONTENT);
            intent.setType("*/*");
            intent.addCategory(Intent.CATEGORY_OPENABLE);
            startActivityForResult(intent, 1);
            result.success("File chooser opened");
        } catch (Exception e) {
            result.error("CHOOSER_FAILED", e.getMessage(), null);
        }
    }

    private void registerDownloadReceiver() {
        downloadReceiver = new BroadcastReceiver() {
            @Override
            public void onReceive(Context context, Intent intent) {
                long id = intent.getLongExtra(DownloadManager.EXTRA_DOWNLOAD_ID, -1);
                if (currentDownloadId == id) {
                    DownloadManager downloadManager = (DownloadManager) getSystemService(Context.DOWNLOAD_SERVICE);
                    DownloadManager.Query query = new DownloadManager.Query();
                    query.setFilterById(id);
                    Cursor cursor = downloadManager.query(query);

                    if (cursor.moveToFirst()) {
                        int status = cursor.getInt(cursor.getColumnIndex(DownloadManager.COLUMN_STATUS));
                        if (status == DownloadManager.STATUS_SUCCESSFUL) {
                            // Download completed successfully
                            String uriString = cursor.getString(cursor.getColumnIndex(DownloadManager.COLUMN_LOCAL_URI));
                            Toast.makeText(MainActivity.this, "Téléchargement terminé: " + uriString, Toast.LENGTH_LONG).show();

                            // Optionally open the file
                            try {
                                Intent openIntent = new Intent(Intent.ACTION_VIEW);
                                openIntent.setData(Uri.parse(uriString));
                                openIntent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_GRANT_READ_URI_PERMISSION);
                                startActivity(openIntent);
                            } catch (Exception e) {
                                Toast.makeText(MainActivity.this, "Impossible d'ouvrir le fichier automatiquement", Toast.LENGTH_SHORT).show();
                            }
                        } else if (status == DownloadManager.STATUS_FAILED) {
                            int reason = cursor.getInt(cursor.getColumnIndex(DownloadManager.COLUMN_REASON));
                            Toast.makeText(MainActivity.this, "Échec du téléchargement: " + reason, Toast.LENGTH_LONG).show();
                        }
                    }
                    cursor.close();
                }
            }
        };

        IntentFilter filter = new IntentFilter(DownloadManager.ACTION_DOWNLOAD_COMPLETE);
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(downloadReceiver, filter, Context.RECEIVER_NOT_EXPORTED);
        } else {
            registerReceiver(downloadReceiver, filter);
        }
    }
}

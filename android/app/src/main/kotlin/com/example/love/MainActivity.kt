package com.example.love

import android.content.ContentValues
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.example.love/backup")
            .setMethodCallHandler { call, result ->
                if (call.method != "saveToDownloads") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }

                val name = call.argument<String>("name")
                val bytes = call.argument<ByteArray>("bytes")
                if (name == null || bytes == null) {
                    result.error("invalid_arguments", "Backup name and bytes are required.", null)
                    return@setMethodCallHandler
                }

                try {
                    saveToDownloads(name, bytes)
                    result.success(null)
                } catch (error: Exception) {
                    result.error("save_failed", error.message, null)
                }
            }
    }

    private fun saveToDownloads(name: String, bytes: ByteArray) {
        check(Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            "Saving backups to Downloads requires Android 10 or later."
        }
        val values = ContentValues().apply {
            put(MediaStore.Downloads.DISPLAY_NAME, name)
            put(MediaStore.Downloads.MIME_TYPE, "application/zip")
            put(MediaStore.Downloads.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
            put(MediaStore.Downloads.IS_PENDING, 1)
        }
        val uri = contentResolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
            ?: error("Could not create the backup in Downloads.")
        contentResolver.openOutputStream(uri)?.use { it.write(bytes) }
            ?: error("Could not write the backup in Downloads.")
        values.clear()
        values.put(MediaStore.Downloads.IS_PENDING, 0)
        contentResolver.update(uri, values, null, null)
    }
}

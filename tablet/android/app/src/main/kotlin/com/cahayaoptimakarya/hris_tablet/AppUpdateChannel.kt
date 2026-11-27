package com.cahayaoptimakarya.hris_tablet

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * Wajib update tanpa Play Store: Dart mengunduh APK baru dari HRIS ke
 * cache/updates/update.apk, lalu kanal ini membuka layar pemasang Android.
 * Android tetap meminta satu ketukan "Update" dan, sekali saja, izin
 * "Izinkan dari sumber ini" untuk aplikasi ini.
 */
object AppUpdateChannel {
    fun register(activity: Activity, engine: FlutterEngine) {
        MethodChannel(engine.dartExecutor.binaryMessenger, "cok/app_update").setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "versionCode" -> {
                        val info = activity.packageManager.getPackageInfo(activity.packageName, 0)
                        val code = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                            info.longVersionCode
                        } else {
                            @Suppress("DEPRECATION")
                            info.versionCode.toLong()
                        }
                        result.success(code)
                    }
                    "updateFilePath" -> {
                        val dir = File(activity.cacheDir, "updates")
                        dir.mkdirs()
                        result.success(File(dir, "update.apk").absolutePath)
                    }
                    "canInstall" -> {
                        val allowed = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            activity.packageManager.canRequestPackageInstalls()
                        } else {
                            true
                        }
                        result.success(allowed)
                    }
                    "openInstallSettings" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            activity.startActivity(
                                Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES, Uri.parse("package:" + activity.packageName))
                            )
                        } else {
                            activity.startActivity(Intent(Settings.ACTION_SECURITY_SETTINGS))
                        }
                        result.success(true)
                    }
                    "install" -> {
                        val file = File(call.argument<String>("path")!!)
                        val uri = FileProvider.getUriForFile(activity, activity.packageName + ".updates", file)
                        val intent = Intent(Intent.ACTION_VIEW)
                            .setDataAndType(uri, "application/vnd.android.package-archive")
                            .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK)
                        activity.startActivity(intent)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                result.error("app_update_failed", e.message, null)
            }
        }
    }
}

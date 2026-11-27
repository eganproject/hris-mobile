package com.cahayaoptimakarya.hris_mobile

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.ComponentName
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Saluran "Absensi" berprioritas tinggi supaya notifikasi absen muncul
        // di atas layar (heads-up), bukan hanya diam di bilah notifikasi.
        // Server mengirim notifikasi dengan channel_id "absensi".
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel("absensi", "Absensi", NotificationManager.IMPORTANCE_HIGH)
            channel.description = "Pemberitahuan saat absen masuk atau pulang tercatat"
            getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
        }
    }

    /**
     * Pintasan ke setelan HP yang sering membuat notifikasi tidak muncul:
     * izin notifikasi, penghemat baterai, dan "mulai otomatis" (Xiaomi, Oppo,
     * Vivo, Realme, Huawei). Dipakai layar Profil > "Notifikasi tidak muncul?".
     */
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "hris/notif-help").setMethodCallHandler { call, result ->
            when (call.method) {
                "status" -> result.success(
                    mapOf(
                        "manufacturer" to Build.MANUFACTURER.lowercase(),
                        "batteryRestricted" to batteryRestricted(),
                        "hasAutostart" to autostartIntents().any { canOpen(it) },
                    )
                )
                "openNotificationSettings" -> result.success(open(notificationSettingsIntent()))
                "requestBattery" -> result.success(requestBattery())
                "openAutostart" -> result.success(autostartIntents().any { open(it) } || open(appDetailsIntent()))
                "openAppDetails" -> result.success(open(appDetailsIntent()))
                else -> result.notImplemented()
            }
        }
    }

    private fun batteryRestricted(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return false
        val pm = getSystemService(PowerManager::class.java) ?: return false
        return !pm.isIgnoringBatteryOptimizations(packageName)
    }

    private fun requestBattery(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return false
        val direct = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS, Uri.parse("package:$packageName"))
        return open(direct) || open(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)) || open(appDetailsIntent())
    }

    private fun notificationSettingsIntent(): Intent =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
        } else {
            appDetailsIntent()
        }

    private fun appDetailsIntent(): Intent =
        Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName"))

    private fun autostartIntents(): List<Intent> = listOf(
        // Xiaomi / Redmi / POCO
        "com.miui.securitycenter" to "com.miui.permcenter.autostart.AutoStartManagementActivity",
        // Oppo / Realme (ColorOS)
        "com.coloros.safecenter" to "com.coloros.safecenter.permission.startup.StartupAppListActivity",
        "com.coloros.safecenter" to "com.coloros.safecenter.startupapp.StartupAppListActivity",
        "com.oppo.safe" to "com.oppo.safe.permission.startup.StartupAppListActivity",
        // Vivo / iQOO
        "com.vivo.permissionmanager" to "com.vivo.permissionmanager.activity.BgStartUpManagerActivity",
        "com.iqoo.secure" to "com.iqoo.secure.ui.phoneoptimize.BgStartUpManager",
        "com.iqoo.secure" to "com.iqoo.secure.ui.phoneoptimize.AddWhiteListActivity",
        // Huawei / Honor
        "com.huawei.systemmanager" to "com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity",
        "com.huawei.systemmanager" to "com.huawei.systemmanager.optimize.process.ProtectActivity",
    ).map { (pkg, cls) -> Intent().setComponent(ComponentName(pkg, cls)) }

    private fun canOpen(intent: Intent): Boolean =
        try {
            packageManager.resolveActivity(intent, 0) != null
        } catch (e: Exception) {
            false
        }

    private fun open(intent: Intent): Boolean =
        try {
            startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
            true
        } catch (e: Exception) {
            false
        }
}

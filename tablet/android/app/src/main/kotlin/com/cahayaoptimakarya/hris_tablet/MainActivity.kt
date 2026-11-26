package com.cahayaoptimakarya.hris_tablet

import android.app.ActivityManager
import android.content.Context
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Kunci layar tablet memakai fitur bawaan Android "sematkan aplikasi" (screen
 * pinning): tombol Home/Recent tidak bisa dipakai sampai HR melepasnya dari menu HR.
 */
class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "hris_tablet/lock").setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "start" -> {
                        startLockTask()
                        result.success(true)
                    }
                    "stop" -> {
                        stopLockTask()
                        result.success(true)
                    }
                    "isLocked" -> {
                        val am = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
                        val locked = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            am.lockTaskModeState != ActivityManager.LOCK_TASK_MODE_NONE
                        } else {
                            @Suppress("DEPRECATION")
                            am.isInLockTaskMode
                        }
                        result.success(locked)
                    }
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                result.error("lock_failed", e.message, null)
            }
        }
    }
}

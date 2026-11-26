package com.cahayaoptimakarya.hris_mobile

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

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
}

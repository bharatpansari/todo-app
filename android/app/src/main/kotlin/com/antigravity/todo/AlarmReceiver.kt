package com.antigravity.todo

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build

class AlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val taskId = intent.getStringExtra("taskId")
        val speakText = intent.getStringExtra("speakText")

        if (taskId != null && speakText != null) {
            val serviceIntent = Intent(context, SpeakForegroundService::class.java).apply {
                putExtra("taskId", taskId)
                putExtra("speakText", speakText)
            }

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(serviceIntent)
            } else {
                context.startService(serviceIntent)
            }
        }
    }
}

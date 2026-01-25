package com.example.talkative_todo

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.PowerManager
import android.util.Log
import android.os.Build
import android.os.Handler
import android.os.Looper

class AlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val taskId = intent.getStringExtra("taskId")
        val speakText = intent.getStringExtra("speakText") ?: "It is time for your task!"
        val isRecurring = intent.getBooleanExtra("isRecurring", false)
        
        // TTS Settings
        val ttsLanguage = intent.getStringExtra("ttsLanguage") ?: "en-US"
        val ttsSpeechRate = intent.getFloatExtra("ttsSpeechRate", 0.75f)
        val ttsPitch = intent.getFloatExtra("ttsPitch", 1.0f)
        val ttsVolume = intent.getFloatExtra("ttsVolume", 1.0f)
        
        Log.d("AlarmReceiver", "Alarm received for task: $taskId, text: $speakText, recurring: $isRecurring, lang: $ttsLanguage")

        // Acquire a WakeLock to keep CPU running long enough to start the service
        val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
        val wakeLock = powerManager.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK,
            "TalkativeTodo::AlarmWakeLock"
        )
        wakeLock.acquire(10 * 60 * 1000L /*10 minutes*/)

        // Start SpeakingService with TTS settings and taskId
        val serviceIntent = Intent(context, SpeakingService::class.java).apply {
            putExtra("speakText", speakText)
            putExtra(SpeakingService.EXTRA_TASK_ID, taskId)
            putExtra("ttsLanguage", ttsLanguage)
            putExtra("ttsSpeechRate", ttsSpeechRate)
            putExtra("ttsPitch", ttsPitch)
            putExtra("ttsVolume", ttsVolume)
        }
        
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(serviceIntent)
            } else {
                context.startService(serviceIntent)
            }
        } finally {
            // Release WakeLock after service starts - foreground service handles keeping device awake
            if (wakeLock.isHeld) {
                wakeLock.release()
            }
        }
        
        // Notify Flutter about the alarm (for recurring task auto-reschedule)
        // Use a slight delay to ensure Flutter engine is ready
        if (taskId != null) {
            Handler(Looper.getMainLooper()).postDelayed({
                try {
                    MainActivity.notifyFlutter(taskId)
                    Log.d("AlarmReceiver", "Notified Flutter about alarm for: $taskId")
                } catch (e: Exception) {
                    Log.e("AlarmReceiver", "Failed to notify Flutter: ${e.message}")
                }
            }, 500)
        }
    }
}


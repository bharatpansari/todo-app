package com.example.talkative_todo

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import org.json.JSONObject

/**
 * Handles snooze and dismiss actions from the notification.
 */
class SnoozeReceiver : BroadcastReceiver() {

    companion object {
        const val ACTION_SNOOZE = "com.example.talkative_todo.ACTION_SNOOZE"
        const val ACTION_DISMISS = "com.example.talkative_todo.ACTION_DISMISS"
        
        const val EXTRA_TASK_ID = "taskId"
        const val EXTRA_SPEAK_TEXT = "speakText"
        const val EXTRA_SNOOZE_MINUTES = "snoozeMinutes"
        const val EXTRA_TTS_LANGUAGE = "ttsLanguage"
        const val EXTRA_TTS_SPEECH_RATE = "ttsSpeechRate"
        const val EXTRA_TTS_PITCH = "ttsPitch"
        const val EXTRA_TTS_VOLUME = "ttsVolume"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val taskId = intent.getStringExtra(EXTRA_TASK_ID)
        val speakText = intent.getStringExtra(EXTRA_SPEAK_TEXT) ?: "Task Reminder"
        
        Log.d("SnoozeReceiver", "Received action: ${intent.action} for task: $taskId")

        // Stop the speaking service first
        stopSpeakingService(context)

        when (intent.action) {
            ACTION_SNOOZE -> {
                val snoozeMinutes = intent.getIntExtra(EXTRA_SNOOZE_MINUTES, 5)
                val ttsLanguage = intent.getStringExtra(EXTRA_TTS_LANGUAGE) ?: "en-US"
                val ttsSpeechRate = intent.getFloatExtra(EXTRA_TTS_SPEECH_RATE, 0.75f)
                val ttsPitch = intent.getFloatExtra(EXTRA_TTS_PITCH, 1.0f)
                val ttsVolume = intent.getFloatExtra(EXTRA_TTS_VOLUME, 1.0f)
                
                if (taskId != null) {
                    scheduleSnoozeAlarm(
                        context, taskId, snoozeMinutes, speakText,
                        ttsLanguage, ttsSpeechRate, ttsPitch, ttsVolume
                    )
                    notifyFlutterSnoozed(taskId, snoozeMinutes)
                }
            }
            ACTION_DISMISS -> {
                // Dismiss only stops the alarm (already done above), no Flutter callback needed
                Log.d("SnoozeReceiver", "Task $taskId dismissed without marking complete")
            }
        }
    }

    private fun stopSpeakingService(context: Context) {
        val stopIntent = Intent(context, SpeakingService::class.java).apply {
            action = SpeakingService.ACTION_STOP
        }
        context.startService(stopIntent)
        Log.d("SnoozeReceiver", "Sent stop command to SpeakingService")
    }

    private fun scheduleSnoozeAlarm(
        context: Context,
        taskId: String,
        snoozeMinutes: Int,
        speakText: String,
        ttsLanguage: String,
        ttsSpeechRate: Float,
        ttsPitch: Float,
        ttsVolume: Float
    ) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        
        // Check if we can schedule exact alarms on Android 12+
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            if (!alarmManager.canScheduleExactAlarms()) {
                Log.e("SnoozeReceiver", "Cannot schedule exact alarms! Permission not granted.")
                // Try to schedule with setAndAllowWhileIdle as fallback (less precise)
            }
        }
        
        val triggerAtMillis = System.currentTimeMillis() + (snoozeMinutes * 60 * 1000L)
        
        Log.d("SnoozeReceiver", "Scheduling snooze: taskId=$taskId, snoozeMinutes=$snoozeMinutes, triggerAt=$triggerAtMillis")
        
        val intent = Intent(context, AlarmReceiver::class.java).apply {
            putExtra("taskId", taskId)
            putExtra("speakText", speakText)
            putExtra("isRecurring", false) // Snoozed alarms are not recurring
            putExtra("ttsLanguage", ttsLanguage)
            putExtra("ttsSpeechRate", ttsSpeechRate)
            putExtra("ttsPitch", ttsPitch)
            putExtra("ttsVolume", ttsVolume)
            putExtra("isSnoozed", true) // Mark as snoozed alarm
        }
        
        // Use a different request code for snoozed alarms to not conflict with original
        val snoozeRequestCode = "snooze_${taskId}".hashCode()
        Log.d("SnoozeReceiver", "Using request code: $snoozeRequestCode")
        
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            snoozeRequestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // Save to SharedPreferences for reboot restoration
        saveSnoozeToPrefs(context, taskId, triggerAtMillis, speakText, 
            ttsLanguage, ttsSpeechRate, ttsPitch, ttsVolume)

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && alarmManager.canScheduleExactAlarms()) {
                alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAtMillis, pendingIntent)
                Log.d("SnoozeReceiver", "Scheduled exact alarm (Android 12+) for task $taskId at $triggerAtMillis")
            } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAtMillis, pendingIntent)
                Log.d("SnoozeReceiver", "Scheduled exact alarm (Android 6+) for task $taskId at $triggerAtMillis")
            } else {
                alarmManager.setExact(AlarmManager.RTC_WAKEUP, triggerAtMillis, pendingIntent)
                Log.d("SnoozeReceiver", "Scheduled exact alarm (legacy) for task $taskId")
            }
        } catch (e: SecurityException) {
            Log.e("SnoozeReceiver", "SecurityException scheduling alarm: ${e.message}")
            // Fallback to inexact alarm
            alarmManager.set(AlarmManager.RTC_WAKEUP, triggerAtMillis, pendingIntent)
            Log.d("SnoozeReceiver", "Scheduled inexact alarm as fallback for task $taskId")
        }

        Log.d("SnoozeReceiver", "Snooze alarm scheduled successfully for task $taskId in $snoozeMinutes minutes")
    }

    private fun saveSnoozeToPrefs(
        context: Context,
        taskId: String,
        time: Long,
        text: String,
        ttsLanguage: String,
        ttsSpeechRate: Float,
        ttsPitch: Float,
        ttsVolume: Float
    ) {
        val prefs = context.getSharedPreferences("alarms_db", Context.MODE_PRIVATE)
        val json = JSONObject()
        json.put("time", time)
        json.put("text", text)
        json.put("isRecurring", false)
        json.put("repeatType", "none")
        json.put("ttsLanguage", ttsLanguage)
        json.put("ttsSpeechRate", ttsSpeechRate.toDouble())
        json.put("ttsPitch", ttsPitch.toDouble())
        json.put("ttsVolume", ttsVolume.toDouble())
        json.put("isSnoozed", true)
        prefs.edit().putString("snooze_$taskId", json.toString()).apply()
    }

    private fun notifyFlutterSnoozed(taskId: String, snoozeMinutes: Int) {
        Handler(Looper.getMainLooper()).postDelayed({
            try {
                MainActivity.notifyFlutterSnoozed(taskId, snoozeMinutes)
                Log.d("SnoozeReceiver", "Notified Flutter about snooze for: $taskId")
            } catch (e: Exception) {
                Log.e("SnoozeReceiver", "Failed to notify Flutter about snooze: ${e.message}")
            }
        }, 200)
    }


}

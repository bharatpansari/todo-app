package com.antigravity.todo

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log

class AlarmScheduler(private val context: Context) {
    private val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

    fun scheduleExactAlarm(taskId: String, triggerAtMillis: Long, speakText: String) {
        val intent = Intent(context, AlarmReceiver::class.java).apply {
            putExtra("taskId", taskId)
            putExtra("speakText", speakText)
        }

        // Use hashCode of taskId for a unique request code interaction
        val requestCode = taskId.hashCode()
        
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val triggerTime = if (triggerAtMillis < System.currentTimeMillis()) {
             System.currentTimeMillis() + 1000 // If past, trigger immediately (1s delay)
        } else {
            triggerAtMillis
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && !alarmManager.canScheduleExactAlarms()) {
            Log.e("AlarmScheduler", "Exact alarm permission missing")
            // Best effort: usage standard set (inexact) or just fail gracefully
            alarmManager.setAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP,
                triggerTime,
                pendingIntent
            )
        } else {
             // Precise
            alarmManager.setExactAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP,
                triggerTime,
                pendingIntent
            )
        }
        
        // Persist to SharedPreferences for Boot Reschedule
        saveToPrefs(taskId, triggerTime, speakText)
        
        Log.d("AlarmScheduler", "Scheduled alarm for $triggerTime ($speakText)")
    }

    fun cancelAlarm(taskId: String) {
        val intent = Intent(context, AlarmReceiver::class.java)
        val requestCode = taskId.hashCode()
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        alarmManager.cancel(pendingIntent)
        
        removeFromPrefs(taskId)
    }

    private fun saveToPrefs(taskId: String, time: Long, text: String) {
        val prefs = context.getSharedPreferences("scheduled_tasks", Context.MODE_PRIVATE)
        val tasks = prefs.getStringSet("ids", mutableSetOf())?.toMutableSet() ?: mutableSetOf()
        
        tasks.add(taskId)
        prefs.edit()
            .putStringSet("ids", tasks)
            .putLong("${taskId}_time", time)
            .putString("${taskId}_text", text)
            .apply()
    }

    private fun removeFromPrefs(taskId: String) {
        val prefs = context.getSharedPreferences("scheduled_tasks", Context.MODE_PRIVATE)
        val tasks = prefs.getStringSet("ids", mutableSetOf())?.toMutableSet() ?: return
        
        tasks.remove(taskId)
        prefs.edit()
            .putStringSet("ids", tasks)
            .remove("${taskId}_time")
            .remove("${taskId}_text")
            .apply()
    }
}

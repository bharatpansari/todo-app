package com.example.talkative_todo

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import org.json.JSONObject

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED || intent.action == Intent.ACTION_MY_PACKAGE_REPLACED) {
            Log.d("BootReceiver", "Rescheduling alarms after boot/update")
            val prefs = context.getSharedPreferences("alarms_db", Context.MODE_PRIVATE)
            val allEntries = prefs.all
            
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

            for ((taskId, value) in allEntries) {
                try {
                    val json = JSONObject(value as String)
                    val time = json.getLong("time")
                    val text = json.getString("text")
                    
                    // TTS Settings (with defaults for backwards compatibility)
                    val ttsLanguage = json.optString("ttsLanguage", "en-US")
                    val ttsSpeechRate = json.optDouble("ttsSpeechRate", 0.75).toFloat()
                    val ttsPitch = json.optDouble("ttsPitch", 1.0).toFloat()
                    val ttsVolume = json.optDouble("ttsVolume", 1.0).toFloat()

                    if (time > System.currentTimeMillis()) {
                        val alarmIntent = Intent(context, AlarmReceiver::class.java).apply {
                            putExtra("taskId", taskId)
                            putExtra("speakText", text)
                            putExtra("ttsLanguage", ttsLanguage)
                            putExtra("ttsSpeechRate", ttsSpeechRate)
                            putExtra("ttsPitch", ttsPitch)
                            putExtra("ttsVolume", ttsVolume)
                        }
                        
                        val pendingIntent = PendingIntent.getBroadcast(
                            context,
                            taskId.hashCode(),
                            alarmIntent,
                            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                        )

                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, time, pendingIntent)
                        } else {
                            alarmManager.setExact(AlarmManager.RTC_WAKEUP, time, pendingIntent)
                        }
                        Log.d("BootReceiver", "Rescheduled alarm for task: $taskId at $time with lang=$ttsLanguage")
                    } else {
                        // Cleanup old alarms
                        prefs.edit().remove(taskId).apply()
                    }
                } catch (e: Exception) {
                    Log.e("BootReceiver", "Error rescheduling alarm: ${e.message}")
                    e.printStackTrace()
                }
            }
        }
    }
}

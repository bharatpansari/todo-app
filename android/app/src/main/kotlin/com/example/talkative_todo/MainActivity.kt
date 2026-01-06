package com.example.talkative_todo

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.antigravity.todo/alarm"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "scheduleAlarm" -> {
                    val taskId = call.argument<String>("taskId")
                    val triggerAtMillis = call.argument<Long>("triggerAtMillis")
                    val speakText = call.argument<String>("speakText")
                    if (taskId != null && triggerAtMillis != null) {
                        scheduleAlarm(taskId, triggerAtMillis, speakText ?: "Task Reminder")
                        result.success(null)
                    } else {
                        result.error("INVALID_ARGS", "Missing arguments", null)
                    }
                }
                "cancelAlarm" -> {
                    val taskId = call.argument<String>("taskId")
                    if (taskId != null) {
                        cancelAlarm(taskId)
                        result.success(null)
                    } else {
                        result.error("INVALID_ARGS", "Missing taskId", null)
                    }
                }
                "requestExactAlarmPermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                        val intent = Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM)
                        startActivity(intent)
                    }
                    result.success(null)
                }
                "requestBatteryOptimizationIgnore" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS)
                        intent.data = Uri.parse("package:$packageName")
                        startActivity(intent)
                    }
                    result.success(null)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun scheduleAlarm(taskId: String, triggerAtMillis: Long, speakText: String) {
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(this, AlarmReceiver::class.java).apply {
            putExtra("taskId", taskId)
            putExtra("speakText", speakText)
        }
        
        // requestCode is hash of taskId to ensure uniqueness
        val requestCode = taskId.hashCode()
        
        val pendingIntent = PendingIntent.getBroadcast(
            this,
            requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // Save to SharedPreferences for reboot restoration
        saveAlarmToPrefs(taskId, triggerAtMillis, speakText)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAtMillis, pendingIntent)
        } else {
            alarmManager.setExact(AlarmManager.RTC_WAKEUP, triggerAtMillis, pendingIntent)
        }
    }

    private fun cancelAlarm(taskId: String) {
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(this, AlarmReceiver::class.java)
        val pendingIntent = PendingIntent.getBroadcast(
            this,
            taskId.hashCode(),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        alarmManager.cancel(pendingIntent)
        
        removeAlarmFromPrefs(taskId)
    }

    private fun saveAlarmToPrefs(taskId: String, time: Long, text: String) {
        val prefs = getSharedPreferences("alarms_db", Context.MODE_PRIVATE)
        val json = JSONObject()
        json.put("time", time)
        json.put("text", text)
        prefs.edit().putString(taskId, json.toString()).apply()
    }

    private fun removeAlarmFromPrefs(taskId: String) {
        val prefs = getSharedPreferences("alarms_db", Context.MODE_PRIVATE)
        prefs.edit().remove(taskId).apply()
    }
}

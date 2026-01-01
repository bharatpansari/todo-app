package com.antigravity.todo

import android.app.AlarmManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.provider.Settings
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.antigravity.todo/alarm"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            val alarmScheduler = AlarmScheduler(this)
            
            when (call.method) {
                "scheduleAlarm" -> {
                    val taskId = call.argument<String>("taskId")
                    val triggerAtMillis = call.argument<Long>("triggerAtMillis")
                    val speakText = call.argument<String>("speakText")

                    if (taskId != null && triggerAtMillis != null && speakText != null) {
                        alarmScheduler.scheduleExactAlarm(taskId, triggerAtMillis, speakText)
                        result.success(true)
                    } else {
                        result.error("INVALID_ARGS", "Missing arguments", null)
                    }
                }
                "cancelAlarm" -> {
                    val taskId = call.argument<String>("taskId")
                    if (taskId != null) {
                        alarmScheduler.cancelAlarm(taskId)
                        result.success(true)
                    } else {
                        result.error("INVALID_ARGS", "Missing taskId", null)
                    }
                }
                "requestExactAlarmPermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
                        if (!alarmManager.canScheduleExactAlarms()) {
                            val intent = Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM)
                            startActivity(intent)
                        }
                    }
                    result.success(true)
                }
                "requestBatteryOptimizationIgnore" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        val intent = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
                        startActivity(intent)
                    }
                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
}

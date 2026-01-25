package com.example.talkative_todo

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.speech.tts.TextToSpeech
import android.util.Log
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import java.util.Locale

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.example.talkative_todo/alarm"
    private var testTts: TextToSpeech? = null

    companion object {
        private var methodChannel: MethodChannel? = null

        fun notifyFlutter(taskId: String) {
            methodChannel?.invokeMethod("onAlarmFired", mapOf("taskId" to taskId))
        }
        
        fun notifyFlutterSnoozed(taskId: String, snoozeMinutes: Int) {
            methodChannel?.invokeMethod("onTaskSnoozed", mapOf(
                "taskId" to taskId,
                "snoozeMinutes" to snoozeMinutes
            ))
        }
        
        fun notifyFlutterMarkDone(taskId: String) {
            methodChannel?.invokeMethod("onTaskMarkedDone", mapOf("taskId" to taskId))
        }
    }

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel = channel
        
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "scheduleAlarm" -> {
                    val taskId = call.argument<String>("taskId")
                    val triggerAtMillis = call.argument<Long>("triggerAtMillis")
                    val speakText = call.argument<String>("speakText")
                    val isRecurring = call.argument<Boolean>("isRecurring") ?: false
                    val repeatType = call.argument<String>("repeatType") ?: "none"
                    // TTS Settings
                    val ttsLanguage = call.argument<String>("ttsLanguage") ?: "en-US"
                    val ttsSpeechRate = call.argument<Double>("ttsSpeechRate") ?: 0.75
                    val ttsPitch = call.argument<Double>("ttsPitch") ?: 1.0
                    val ttsVolume = call.argument<Double>("ttsVolume") ?: 1.0
                    val requestCode = call.argument<Int>("requestCode") ?: 0
                    
                    if (taskId != null && triggerAtMillis != null) {
                        scheduleAlarm(taskId, requestCode, triggerAtMillis, speakText ?: "Task Reminder", isRecurring, repeatType,
                            ttsLanguage, ttsSpeechRate.toFloat(), ttsPitch.toFloat(), ttsVolume.toFloat())
                        result.success(null)
                    } else {
                        result.error("INVALID_ARGS", "Missing arguments", null)
                    }
                }
                "cancelAlarm" -> {
                    val taskId = call.argument<String>("taskId")
                    val requestCode = call.argument<Int>("requestCode") ?: 0
                    if (taskId != null) {
                        cancelAlarm(taskId, requestCode)
                        result.success(null)
                    } else {
                        result.error("INVALID_ARGS", "Missing taskId", null)
                    }
                }
                "testTts" -> {
                    val text = call.argument<String>("text") ?: "Test"
                    val ttsLanguage = call.argument<String>("ttsLanguage") ?: "en-US"
                    val ttsSpeechRate = call.argument<Double>("ttsSpeechRate") ?: 0.75
                    val ttsPitch = call.argument<Double>("ttsPitch") ?: 1.0
                    val ttsVolume = call.argument<Double>("ttsVolume") ?: 1.0
                    
                    testTtsSpeak(text, ttsLanguage, ttsSpeechRate.toFloat(), ttsPitch.toFloat(), ttsVolume.toFloat(), result)
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
                "isLanguageAvailable" -> {
                    val language = call.argument<String>("language")
                    if (language != null) {
                        checkLanguageAvailability(language, result)
                    } else {
                        result.error("INVALID_ARGS", "Missing language", null)
                    }
                }
                "openTtsSettings" -> {
                    val intent = Intent()
                    intent.action = "com.android.settings.TTS_SETTINGS"
                    intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                    startActivity(intent)
                    result.success(null)
                }
                "updateWidget" -> {
                    val tasksJson = call.argument<String>("tasksJson")
                    if (tasksJson != null) {
                        TaskWidgetProvider.saveWidgetTasks(this, tasksJson)
                        result.success(null)
                    } else {
                        result.error("INVALID_ARGS", "Missing tasksJson", null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun testTtsSpeak(text: String, language: String, rate: Float, pitch: Float, volume: Float, result: MethodChannel.Result) {
        // Cleanup previous instance
        testTts?.stop()
        testTts?.shutdown()
        
        val mainHandler = android.os.Handler(android.os.Looper.getMainLooper())
        
        testTts = TextToSpeech(this) { status ->
            if (status == TextToSpeech.SUCCESS) {
                val parts = language.split("-")
                val locale = if (parts.size >= 2) Locale(parts[0], parts[1]) else Locale(parts[0])
                val langResult = testTts?.setLanguage(locale)
                
                Log.d("MainActivity", "TTS setLanguage result for $language: $langResult")
                
                var languageStatus = "available"
                if (langResult == TextToSpeech.LANG_MISSING_DATA || langResult == TextToSpeech.LANG_NOT_SUPPORTED) {
                    Log.w("MainActivity", "Language $language not available (result=$langResult), using default")
                    testTts?.setLanguage(Locale.US)
                    languageStatus = if (langResult == TextToSpeech.LANG_MISSING_DATA) "missing_data" else "not_supported"
                }
                
                testTts?.setSpeechRate(rate)
                testTts?.setPitch(pitch)
                
                val params = android.os.Bundle()
                params.putFloat(TextToSpeech.Engine.KEY_PARAM_VOLUME, volume)
                
                testTts?.speak(text, TextToSpeech.QUEUE_FLUSH, params, "test_utterance")
                
                // Auto-cleanup test TTS after 10 seconds
                mainHandler.postDelayed({
                    testTts?.stop()
                    testTts?.shutdown()
                    testTts = null
                    Log.d("MainActivity", "Auto-cleaned up test TTS instance")
                }, 10000)
                
                Log.d("MainActivity", "Returning languageStatus to Flutter: $languageStatus")
                
                // Return status to Flutter on main thread
                mainHandler.post {
                    result.success(languageStatus)
                }
            } else {
                Log.e("MainActivity", "TTS initialization failed with status: $status")
                mainHandler.post {
                    result.error("TTS_INIT_ERROR", "TTS initialization failed", null)
                }
            }
        }
    }

    private fun scheduleAlarm(taskId: String, requestCodeOffset: Int, triggerAtMillis: Long, speakText: String, isRecurring: Boolean, repeatType: String,
                              ttsLanguage: String, ttsSpeechRate: Float, ttsPitch: Float, ttsVolume: Float) {
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(this, AlarmReceiver::class.java).apply {
            putExtra("taskId", taskId)
            putExtra("speakText", speakText)
            putExtra("isRecurring", isRecurring)
            // TTS Settings
            putExtra("ttsLanguage", ttsLanguage)
            putExtra("ttsSpeechRate", ttsSpeechRate)
            putExtra("ttsPitch", ttsPitch)
            putExtra("ttsVolume", ttsVolume)
            putExtra("requestCodeOffset", requestCodeOffset) // Pass offset for logging/debugging
        }
        
        // Ensure unique pending intent ID: hash(taskId) + offset
        // Using string concatenation to ensure uniqueness: "taskId_offset" hash
        val uniqueId = "${taskId}_$requestCodeOffset".hashCode()
        
        val pendingIntent = PendingIntent.getBroadcast(
            this,
            uniqueId,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // Save to SharedPreferences for reboot restoration (only save main alarm for now? 
        // Or save all? If we save all, we need unique keys in prefs.
        // Let's us key: "taskId_offset"
        saveAlarmToPrefs("${taskId}_$requestCodeOffset", triggerAtMillis, speakText, isRecurring, repeatType,
            ttsLanguage, ttsSpeechRate, ttsPitch, ttsVolume)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAtMillis, pendingIntent)
        } else {
            alarmManager.setExact(AlarmManager.RTC_WAKEUP, triggerAtMillis, pendingIntent)
        }
    }

    private fun cancelAlarm(taskId: String, requestCodeOffset: Int) {
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(this, AlarmReceiver::class.java)
        
        val uniqueId = "${taskId}_$requestCodeOffset".hashCode()
        
        val pendingIntent = PendingIntent.getBroadcast(
            this,
            uniqueId,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        alarmManager.cancel(pendingIntent)
        
        removeAlarmFromPrefs("${taskId}_$requestCodeOffset")
    }

    private fun saveAlarmToPrefs(taskId: String, time: Long, text: String, isRecurring: Boolean, repeatType: String,
                                  ttsLanguage: String, ttsSpeechRate: Float, ttsPitch: Float, ttsVolume: Float) {
        val prefs = getSharedPreferences("alarms_db", Context.MODE_PRIVATE)
        val json = JSONObject()
        json.put("time", time)
        json.put("text", text)
        json.put("isRecurring", isRecurring)
        json.put("repeatType", repeatType)
        json.put("ttsLanguage", ttsLanguage)
        json.put("ttsSpeechRate", ttsSpeechRate.toDouble())
        json.put("ttsPitch", ttsPitch.toDouble())
        json.put("ttsVolume", ttsVolume.toDouble())
        prefs.edit().putString(taskId, json.toString()).apply()
    }

    private fun removeAlarmFromPrefs(taskId: String) {
        val prefs = getSharedPreferences("alarms_db", Context.MODE_PRIVATE)
        prefs.edit().remove(taskId).apply()
    }

    override fun onDestroy() {
        testTts?.stop()
        testTts?.shutdown()
        super.onDestroy()
    }

    private fun checkLanguageAvailability(language: String, result: MethodChannel.Result) {
        // Use a temporary TTS instance to check availability
        // Note: Creating a new TTS instance is async, but checking availability usually requires an initialized instance.
        // However, we can use the existing testTts instance if initialized, or create a one-off.
        // For simplicity and to avoid async complexity in this synchronous-like check, 
        // we'll try to use the testTts instance if it exists, or create a new short-lived one.
        
        // Actually, creating TTS is always async callback based. 
        // A better approach for "isLanguageAvailable" which is called from UI 
        // might be to maintain a persistent TTS instance in MainActivity or just use the one we might have.
        
        if (testTts == null) {
             testTts = TextToSpeech(this) { status ->
                 if (status == TextToSpeech.SUCCESS) {
                     // Initialized, now check
                     performCheck(language, result)
                 } else {
                     result.error("TTS_INIT_ERROR", "Failed to initialize TTS", null)
                 }
             }
        } else {
             performCheck(language, result)
        }
    }

    private fun performCheck(language: String, result: MethodChannel.Result) {
        val parts = language.split("-")
        val locale = if (parts.size >= 2) Locale(parts[0], parts[1]) else Locale(parts[0])
        
        val availability = testTts?.isLanguageAvailable(locale)
        
        when (availability) {
            TextToSpeech.LANG_AVAILABLE, 
            TextToSpeech.LANG_COUNTRY_AVAILABLE -> {
                result.success("available")
            }
            TextToSpeech.LANG_MISSING_DATA -> {
                result.success("missing_data")
            }
            TextToSpeech.LANG_NOT_SUPPORTED -> {
                result.success("not_supported")
            }
            else -> {
                result.success("unknown") // includes LANG_MISSING_DATA which we handled? No, logic is subtle
            }
        }
    }
}


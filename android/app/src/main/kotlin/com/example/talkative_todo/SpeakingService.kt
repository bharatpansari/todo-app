package com.example.talkative_todo

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.speech.tts.TextToSpeech
import android.util.Log
import androidx.core.app.NotificationCompat
import java.util.Locale

class SpeakingService : Service(), TextToSpeech.OnInitListener {
    private var tts: TextToSpeech? = null
    private var textToSpeak: String? = null
    private val CHANNEL_ID = "TalkingAlarmChannel"
    private var isStopped = false
    private var isTtsInitialized = false
    private val handler = Handler(Looper.getMainLooper())
    
    // TTS Settings
    private var ttsLanguage: String = "en-US"
    private var ttsSpeechRate: Float = 0.75f
    private var ttsPitch: Float = 1.0f
    private var ttsVolume: Float = 1.0f
    
    // Task info for snooze functionality
    private var currentTaskId: String? = null

    companion object {
        const val ACTION_STOP = "com.example.talkative_todo.ACTION_STOP"
        const val EXTRA_TASK_ID = "taskId"
    }

    override fun onCreate() {
        super.onCreate()
        Log.d("SpeakingService", "onCreate")
        tts = TextToSpeech(this, this)
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d("SpeakingService", "onStartCommand")
        if (intent?.action == ACTION_STOP) {
            stopSpeaking()
            return START_NOT_STICKY
        }

        textToSpeak = intent?.getStringExtra("speakText") ?: "Time for your task"
        currentTaskId = intent?.getStringExtra(EXTRA_TASK_ID)
        
        // Read TTS settings from intent
        ttsLanguage = intent?.getStringExtra("ttsLanguage") ?: "en-US"
        ttsSpeechRate = intent?.getFloatExtra("ttsSpeechRate", 0.75f) ?: 0.75f
        ttsPitch = intent?.getFloatExtra("ttsPitch", 1.0f) ?: 1.0f
        ttsVolume = intent?.getFloatExtra("ttsVolume", 1.0f) ?: 1.0f
        
        Log.d("SpeakingService", "TTS Settings: lang=$ttsLanguage, rate=$ttsSpeechRate, pitch=$ttsPitch, vol=$ttsVolume, taskId=$currentTaskId")
        
        isStopped = false
        
        val notification = createNotification(textToSpeak!!)
        startForeground(1, notification)

        // If TTS is already initialized, apply settings and speak immediately
        if (isTtsInitialized && !isStopped) {
             applyTtsSettings()
             speak()
        }
        
        return START_STICKY
    }

    private fun stopSpeaking() {
        Log.d("SpeakingService", "Stopping speaking")
        isStopped = true
        handler.removeCallbacksAndMessages(null) // Remove pending loops
        if (tts != null) {
            tts?.stop()
            tts?.shutdown()
            tts = null
        }
        isTtsInitialized = false
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    override fun onInit(status: Int) {
        if (status == TextToSpeech.SUCCESS) {
            Log.d("SpeakingService", "TTS Init successful")
            
            // Set Audio Attributes to usage ALARM for better visibility/volume
            val attributes = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_ALARM)
                .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                .build()
            tts?.setAudioAttributes(attributes)

            applyTtsSettings()
            isTtsInitialized = true
            speak()
        } else {
            Log.e("SpeakingService", "TTS Initialization failed")
        }
    }
    
    private fun applyTtsSettings() {
        // Parse language code (e.g., "en-US" -> Locale("en", "US"))
        val parts = ttsLanguage.split("-")
        val locale = if (parts.size >= 2) Locale(parts[0], parts[1]) else Locale(parts[0])
        
        val langResult = tts?.setLanguage(locale)
        if (langResult == TextToSpeech.LANG_MISSING_DATA || langResult == TextToSpeech.LANG_NOT_SUPPORTED) {
            Log.w("SpeakingService", "Language $ttsLanguage not available, falling back to US English")
            tts?.setLanguage(Locale.US)
        }
        
        tts?.setSpeechRate(ttsSpeechRate)
        tts?.setPitch(ttsPitch)
        
        Log.d("SpeakingService", "Applied TTS settings: lang=$ttsLanguage, rate=$ttsSpeechRate, pitch=$ttsPitch")
    }

    private fun speak() {
        if (isStopped || textToSpeak == null) return

        textToSpeak?.let { text ->
             Log.d("SpeakingService", "Speaking: $text")
             val params = android.os.Bundle()
             params.putString(TextToSpeech.Engine.KEY_PARAM_UTTERANCE_ID, "task_speech")
             params.putFloat(TextToSpeech.Engine.KEY_PARAM_VOLUME, ttsVolume)
             
             tts?.speak(text, TextToSpeech.QUEUE_FLUSH, params, "task_speech")
             
             tts?.setOnUtteranceProgressListener(object : android.speech.tts.UtteranceProgressListener() {
                 override fun onStart(utteranceId: String?) {}
                 
                 override fun onDone(utteranceId: String?) {
                     if (!isStopped) {
                         // Loop after 2 seconds delay
                         handler.postDelayed({
                             speak()
                         }, 2000)
                     }
                 }
                 
                 override fun onError(utteranceId: String?) {
                     Log.e("SpeakingService", "Error in utterance")
                     // Retry once or just stop? Let's try to loop anyway
                     if (!isStopped) {
                         handler.postDelayed({
                             speak()
                         }, 2000)
                     }
                 }
             })
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val serviceChannel = NotificationChannel(
                CHANNEL_ID,
                "Talking Alarm Service",
                NotificationManager.IMPORTANCE_HIGH
            )
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(serviceChannel)
        }
    }

    private fun createNotification(text: String): Notification {
        val taskId = currentTaskId
        val requestCodeBase = taskId?.hashCode() ?: 0
        
        // Snooze 5 min action
        val snooze5Intent = Intent(this, SnoozeReceiver::class.java).apply {
            action = SnoozeReceiver.ACTION_SNOOZE
            putExtra(SnoozeReceiver.EXTRA_TASK_ID, taskId)
            putExtra(SnoozeReceiver.EXTRA_SPEAK_TEXT, text)
            putExtra(SnoozeReceiver.EXTRA_SNOOZE_MINUTES, 5)
            putExtra(SnoozeReceiver.EXTRA_TTS_LANGUAGE, ttsLanguage)
            putExtra(SnoozeReceiver.EXTRA_TTS_SPEECH_RATE, ttsSpeechRate)
            putExtra(SnoozeReceiver.EXTRA_TTS_PITCH, ttsPitch)
            putExtra(SnoozeReceiver.EXTRA_TTS_VOLUME, ttsVolume)
        }
        val snooze5PendingIntent = PendingIntent.getBroadcast(
            this, requestCodeBase + 1, snooze5Intent, 
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
        // Snooze 10 min action
        val snooze10Intent = Intent(this, SnoozeReceiver::class.java).apply {
            action = SnoozeReceiver.ACTION_SNOOZE
            putExtra(SnoozeReceiver.EXTRA_TASK_ID, taskId)
            putExtra(SnoozeReceiver.EXTRA_SPEAK_TEXT, text)
            putExtra(SnoozeReceiver.EXTRA_SNOOZE_MINUTES, 10)
            putExtra(SnoozeReceiver.EXTRA_TTS_LANGUAGE, ttsLanguage)
            putExtra(SnoozeReceiver.EXTRA_TTS_SPEECH_RATE, ttsSpeechRate)
            putExtra(SnoozeReceiver.EXTRA_TTS_PITCH, ttsPitch)
            putExtra(SnoozeReceiver.EXTRA_TTS_VOLUME, ttsVolume)
        }
        val snooze10PendingIntent = PendingIntent.getBroadcast(
            this, requestCodeBase + 2, snooze10Intent, 
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
        // Mark Done action
        val doneIntent = Intent(this, SnoozeReceiver::class.java).apply {
            action = SnoozeReceiver.ACTION_MARK_DONE
            putExtra(SnoozeReceiver.EXTRA_TASK_ID, taskId)
        }
        val donePendingIntent = PendingIntent.getBroadcast(
            this, requestCodeBase + 3, doneIntent, 
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
        // Stop action (legacy, still useful)
        val stopIntent = Intent(this, SpeakingService::class.java).apply {
            action = ACTION_STOP
        }
        val stopPendingIntent = PendingIntent.getService(
            this, 0, stopIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val builder = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Task Alarm")
            .setContentText(text)
            .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setOngoing(true)
        
        // Add action buttons if we have a taskId
        if (taskId != null) {
            builder.addAction(android.R.drawable.ic_menu_recent_history, "Snooze 5m", snooze5PendingIntent)
                   .addAction(android.R.drawable.ic_menu_recent_history, "Snooze 10m", snooze10PendingIntent)
                   .addAction(android.R.drawable.ic_menu_save, "Done", donePendingIntent)
        } else {
            // Fallback to simple stop button if no taskId
            builder.addAction(android.R.drawable.ic_media_pause, "Stop", stopPendingIntent)
        }
        
        return builder.build()
    }

    override fun onBind(intent: Intent?): IBinder? {
        return null
    }

    override fun onDestroy() {
        Log.d("SpeakingService", "onDestroy")
        if (tts != null) {
            tts?.stop()
            tts?.shutdown()
        }
        super.onDestroy()
    }
}

package com.example.talkative_todo

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
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
    private val handler = Handler(Looper.getMainLooper())

    companion object {
        const val ACTION_STOP = "com.example.talkative_todo.ACTION_STOP"
    }

    override fun onCreate() {
        super.onCreate()
        tts = TextToSpeech(this, this)
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            stopSpeaking()
            return START_NOT_STICKY
        }

        textToSpeak = intent?.getStringExtra("speakText") ?: "Time for your task"
        isStopped = false
        
        val notification = createNotification(textToSpeak!!)
        startForeground(1, notification)

        // If TTS is already initialized, speak immediately
        // Otherwise onInit will trigger it
        if (tts != null) {
             // We can check if language is available, but onInit handles the setup.
             // If this is a re-entry, we just updated text.
        }
        
        return START_STICKY
    }

    private fun stopSpeaking() {
        isStopped = true
        if (tts != null) {
            tts?.stop()
            tts?.shutdown()
            tts = null
        }
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    override fun onInit(status: Int) {
        if (status == TextToSpeech.SUCCESS) {
            val result = tts?.setLanguage(Locale.US)
            tts?.setSpeechRate(0.75f) // Slower speed as requested

            if (result == TextToSpeech.LANG_MISSING_DATA || result == TextToSpeech.LANG_NOT_SUPPORTED) {
                Log.e("SpeakingService", "Language not supported")
            } else {
                speak()
            }
        } else {
            Log.e("SpeakingService", "TTS Initialization failed")
        }
    }

    private fun speak() {
        if (isStopped) return

        textToSpeak?.let { text ->
             val params = android.os.Bundle()
             params.putString(TextToSpeech.Engine.KEY_PARAM_UTTERANCE_ID, "task_speech")
             
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
        val stopIntent = Intent(this, SpeakingService::class.java).apply {
            action = ACTION_STOP
        }
        val stopPendingIntent = PendingIntent.getService(
            this, 0, stopIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Task Alarm")
            .setContentText(text)
            .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setOngoing(true) // Persistent notification
            .addAction(android.R.drawable.ic_media_pause, "Stop / Dismiss", stopPendingIntent)
            .build()
    }

    override fun onBind(intent: Intent?): IBinder? {
        return null
    }

    override fun onDestroy() {
        if (tts != null) {
            tts?.stop()
            tts?.shutdown()
        }
        super.onDestroy()
    }
}

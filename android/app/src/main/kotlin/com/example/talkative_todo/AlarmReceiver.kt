package com.example.talkative_todo

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.PowerManager
import android.util.Log
import android.os.Build

class AlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val taskId = intent.getStringExtra("taskId")
        val speakText = intent.getStringExtra("speakText") ?: "It is time for your task!"
        
        Log.d("AlarmReceiver", "Alarm received for task: $taskId, text: $speakText")

        // Acquire a WakeLock to keep CPU running long enough to start the service
        val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
        val wakeLock = powerManager.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK,
            "TalkativeTodo::AlarmWakeLock"
        )
        wakeLock.acquire(10 * 60 * 1000L /*10 minutes*/)

        // Start SpeakingService
        val serviceIntent = Intent(context, SpeakingService::class.java).apply {
            putExtra("speakText", speakText)
        }
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.startForegroundService(serviceIntent)
        } else {
            context.startService(serviceIntent)
        }
        
        // Release WakeLock is handled by service or we hope service starts fast enough. 
        // Actually, better to release it after a short delay or pass responsibility.
        // For simplicity, we release it here after a safe margin, or let the service hold its own.
        // Letting service hold is safer, but we need to bridge the gap.
        // We will release this one shortly.
        
        // Note: In production code, managing WakeLocks across components requires care.
        // Here we rely on startForegroundService being quick.
        // wakeLock.release() - Removed to let timeout handle it, ensuring Service starts.
    }
}

package com.antigravity.todo

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED || 
            intent.action == Intent.ACTION_MY_PACKAGE_REPLACED) {
            
            Log.d("BootReceiver", "Boot completed or package replaced. Rescheduling alarms.")
            rescheduleAlarms(context)
        }
    }

    private fun rescheduleAlarms(context: Context) {
        val prefs = context.getSharedPreferences("scheduled_tasks", Context.MODE_PRIVATE)
        val taskIds = prefs.getStringSet("ids", emptySet()) ?: return
        
        val alarmScheduler = AlarmScheduler(context)
        
        for (taskId in taskIds) {
            val time = prefs.getLong("${taskId}_time", 0)
            val text = prefs.getString("${taskId}_text", "")
            
            if (time > System.currentTimeMillis() && !text.isNullOrEmpty()) {
                alarmScheduler.scheduleExactAlarm(taskId, time, text)
                Log.d("BootReceiver", "Rescheduled $taskId at $time")
            } else {
                 // Clean up expired
                 // We don't remove mostly to keep logic simple, 
                 // but good practice to clean up in a real app maintenance job.
                 // For now, if time is passed, we just skip scheduling.
            }
        }
    }
}

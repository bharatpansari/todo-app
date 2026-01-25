package com.example.talkative_todo

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.util.Log
import android.view.View
import android.widget.RemoteViews
import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.*

/**
 * Home screen widget showing next 3 upcoming tasks.
 */
class TaskWidgetProvider : AppWidgetProvider() {

    companion object {
        private const val TAG = "TaskWidgetProvider"
        const val ACTION_REFRESH = "com.example.talkative_todo.WIDGET_REFRESH"
        const val PREFS_NAME = "widget_prefs"
        const val PREFS_TASKS_KEY = "widget_tasks"
        
        /**
         * Trigger widget update from anywhere in the app.
         */
        fun updateWidget(context: Context) {
            val intent = Intent(context, TaskWidgetProvider::class.java).apply {
                action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
            }
            val ids = AppWidgetManager.getInstance(context)
                .getAppWidgetIds(ComponentName(context, TaskWidgetProvider::class.java))
            intent.putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
            context.sendBroadcast(intent)
            Log.d(TAG, "Widget update broadcast sent")
        }
        
        /**
         * Save tasks data for the widget.
         */
        fun saveWidgetTasks(context: Context, tasksJson: String) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            prefs.edit().putString(PREFS_TASKS_KEY, tasksJson).apply()
            Log.d(TAG, "Saved widget tasks: $tasksJson")
            updateWidget(context)
        }
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        Log.d(TAG, "onUpdate called for ${appWidgetIds.size} widgets")
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        
        if (intent.action == ACTION_REFRESH) {
            Log.d(TAG, "Refresh action received")
            updateWidget(context)
        }
    }

    private fun updateAppWidget(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int
    ) {
        val views = RemoteViews(context.packageName, R.layout.widget_task_list)
        
        // Set up click to open app
        val openAppIntent = Intent(context, MainActivity::class.java)
        val openAppPendingIntent = PendingIntent.getActivity(
            context, 0, openAppIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        views.setOnClickPendingIntent(R.id.widget_container, openAppPendingIntent)
        
        // Set up refresh button
        val refreshIntent = Intent(context, TaskWidgetProvider::class.java).apply {
            action = ACTION_REFRESH
        }
        val refreshPendingIntent = PendingIntent.getBroadcast(
            context, 1, refreshIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        views.setOnClickPendingIntent(R.id.refresh_button, refreshPendingIntent)
        
        // Load tasks from SharedPreferences
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val tasksJson = prefs.getString(PREFS_TASKS_KEY, "[]") ?: "[]"
        
        try {
            val tasks = JSONArray(tasksJson)
            val taskCount = minOf(tasks.length(), 3)
            
            if (taskCount == 0) {
                // Show empty state
                views.setViewVisibility(R.id.empty_text, View.VISIBLE)
                views.setViewVisibility(R.id.task_row_1, View.GONE)
                views.setViewVisibility(R.id.task_row_2, View.GONE)
                views.setViewVisibility(R.id.task_row_3, View.GONE)
            } else {
                views.setViewVisibility(R.id.empty_text, View.GONE)
                
                // Populate task rows
                for (i in 0 until 3) {
                    val rowId = when (i) {
                        0 -> R.id.task_row_1
                        1 -> R.id.task_row_2
                        else -> R.id.task_row_3
                    }
                    val titleId = when (i) {
                        0 -> R.id.task_title_1
                        1 -> R.id.task_title_2
                        else -> R.id.task_title_3
                    }
                    val timeId = when (i) {
                        0 -> R.id.task_time_1
                        1 -> R.id.task_time_2
                        else -> R.id.task_time_3
                    }
                    
                    if (i < taskCount) {
                        val task = tasks.getJSONObject(i)
                        val title = task.optString("title", "Task")
                        val timeStr = task.optString("time", "")
                        
                        views.setViewVisibility(rowId, View.VISIBLE)
                        views.setTextViewText(titleId, title)
                        views.setTextViewText(timeId, formatTime(timeStr))
                    } else {
                        views.setViewVisibility(rowId, View.GONE)
                    }
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error parsing tasks: ${e.message}")
            views.setViewVisibility(R.id.empty_text, View.VISIBLE)
            views.setTextViewText(R.id.empty_text, "Error loading tasks")
        }
        
        appWidgetManager.updateAppWidget(appWidgetId, views)
        Log.d(TAG, "Widget $appWidgetId updated")
    }
    
    private fun formatTime(isoTime: String): String {
        if (isoTime.isEmpty()) return ""
        
        return try {
            val inputFormat = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", Locale.getDefault())
            val date = inputFormat.parse(isoTime.substringBefore('.'))
            
            val now = Calendar.getInstance()
            val taskCal = Calendar.getInstance().apply { time = date!! }
            
            val outputFormat = if (now.get(Calendar.DAY_OF_YEAR) == taskCal.get(Calendar.DAY_OF_YEAR) &&
                                  now.get(Calendar.YEAR) == taskCal.get(Calendar.YEAR)) {
                SimpleDateFormat("h:mm a", Locale.getDefault())
            } else {
                SimpleDateFormat("MMM d", Locale.getDefault())
            }
            
            outputFormat.format(date!!)
        } catch (e: Exception) {
            Log.e(TAG, "Error formatting time: ${e.message}")
            ""
        }
    }
}

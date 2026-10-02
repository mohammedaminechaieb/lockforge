package com.example.lockforge

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin

/**
 * Fixed home-screen layout — live clock (native TextClock), next calendar
 * event and weather — since an AppWidget can't host an arbitrary canvas.
 * Event/weather text comes from the last HomeWidgetService.pushAll().
 */
class LockForgeWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        val data = HomeWidgetPlugin.getData(context)
        val eventLabel = data.getString("event_label", "No events today")
        val weatherLabel = data.getString("weather_label", "")
        val openApp = PendingIntent.getActivity(
            context, 0,
            Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        for (widgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.lockforge_widget).apply {
                setTextViewText(R.id.widget_event, eventLabel)
                setTextViewText(R.id.widget_weather, weatherLabel)
                setOnClickPendingIntent(R.id.widget_root, openApp)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}

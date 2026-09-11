package com.example.lockforge

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin

/**
 * Renders a fixed layout — clock, next calendar event, weather — since a
 * real Android AppWidget can't host an arbitrary user-designed canvas the
 * way the in-app LockPreviewScreen does. Data comes from whatever
 * HomeWidgetService last pushed (see lib/services/home_widget_service.dart),
 * which happens each time the user opens the live preview in-app.
 */
class LockForgeWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        val data = HomeWidgetPlugin.getData(context)
        val timeLabel = data.getString("time_label", "--:--")
        val eventLabel = data.getString("event_label", "No events today")
        val weatherLabel = data.getString("weather_label", "")

        for (widgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.lockforge_widget).apply {
                setTextViewText(R.id.widget_time, timeLabel)
                setTextViewText(R.id.widget_event, eventLabel)
                setTextViewText(R.id.widget_weather, weatherLabel)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}

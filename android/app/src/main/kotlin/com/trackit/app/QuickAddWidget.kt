package com.trackit.app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews

/**
 * Home-screen widget with two shortcuts: add an expense, or open today's
 * workout. Each opens the app with MainActivity.EXTRA_ACTION set.
 */
class QuickAddWidget : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        manager: AppWidgetManager,
        widgetIds: IntArray,
    ) {
        for (id in widgetIds) {
            val views = RemoteViews(context.packageName, R.layout.quick_add_widget)
            views.setOnClickPendingIntent(
                R.id.widget_add_expense,
                open(context, "add_expense", 1),
            )
            views.setOnClickPendingIntent(
                R.id.widget_workout,
                open(context, "workout", 2),
            )
            manager.updateAppWidget(id, views)
        }
    }

    private fun open(context: Context, action: String, requestCode: Int): PendingIntent {
        val intent = Intent(context, MainActivity::class.java).apply {
            putExtra(MainActivity.EXTRA_ACTION, action)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        return PendingIntent.getActivity(
            context,
            requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }
}

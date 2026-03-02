package com.nwpu.nwpu_course_monitor

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.util.Log
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class CourseTodayWidgetProvider : HomeWidgetProvider() {
    companion object {
        private const val TAG = "CourseWidgetProvider"
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.course_today_widget)
            try {
                val openAppIntent = HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java)
                views.setOnClickPendingIntent(R.id.widget_container, openAppIntent)

                val mode = widgetData.getString("widget_mode", "today") ?: "today"
                if (mode == "empty") {
                    bindEmptyMode(views, widgetData)
                } else {
                    bindTodayMode(views, widgetData)
                }
            } catch (error: Throwable) {
                Log.e(TAG, "Widget update failed", error)
                bindErrorMode(views)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }

    private fun bindTodayMode(views: RemoteViews, widgetData: SharedPreferences) {
        views.setViewVisibility(R.id.today_container, View.VISIBLE)
        views.setViewVisibility(R.id.empty_container, View.GONE)
        views.setTextViewText(
            R.id.widget_title,
            widgetData.getString("widget_title", "今日课程")
        )
        views.setTextViewText(
            R.id.widget_today,
            widgetData.getString("widget_today", "暂无课程")
        )
        views.setTextViewText(
            R.id.widget_footer,
            widgetData.getString("widget_footer", "点击打开课程管家")
        )
    }

    private fun bindEmptyMode(views: RemoteViews, widgetData: SharedPreferences) {
        views.setViewVisibility(R.id.today_container, View.GONE)
        views.setViewVisibility(R.id.empty_container, View.VISIBLE)
        views.setTextViewText(
            R.id.widget_title,
            widgetData.getString("widget_empty_left_title", "今日无课")
        )
        views.setTextViewText(
            R.id.empty_left_title,
            widgetData.getString("widget_empty_left_title", "今日无课")
        )
        views.setTextViewText(
            R.id.empty_left_body,
            widgetData.getString("widget_empty_left_body", "祝你今天顺利。")
        )
        views.setTextViewText(
            R.id.empty_right_title,
            widgetData.getString("widget_empty_right_title", "明日课程")
        )
        views.setTextViewText(
            R.id.empty_right_body,
            widgetData.getString("widget_empty_right_body", "明日暂无课程")
        )
    }

    private fun bindErrorMode(views: RemoteViews) {
        views.setViewVisibility(R.id.today_container, View.VISIBLE)
        views.setViewVisibility(R.id.empty_container, View.GONE)
        views.setTextViewText(R.id.widget_title, "课程管家")
        views.setTextViewText(R.id.widget_today, "组件更新失败，请打开 App 后点击“立即同步组件”")
        views.setTextViewText(R.id.widget_footer, "点击打开课程管家")
    }
}

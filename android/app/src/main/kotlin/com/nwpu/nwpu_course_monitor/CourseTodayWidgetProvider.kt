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

        private val CARD_CONTAINER_IDS = intArrayOf(
            R.id.card_1,
            R.id.card_2,
            R.id.card_3,
            R.id.card_4
        )
        private val CARD_STRIP_IDS = intArrayOf(
            R.id.card_1_strip,
            R.id.card_2_strip,
            R.id.card_3_strip,
            R.id.card_4_strip
        )
        private val CARD_TITLE_IDS = intArrayOf(
            R.id.card_1_title,
            R.id.card_2_title,
            R.id.card_3_title,
            R.id.card_4_title
        )
        private val CARD_META_IDS = intArrayOf(
            R.id.card_1_meta,
            R.id.card_2_meta,
            R.id.card_3_meta,
            R.id.card_4_meta
        )
        private val CARD_STATUS_IDS = intArrayOf(
            R.id.card_1_status,
            R.id.card_2_status,
            R.id.card_3_status,
            R.id.card_4_status
        )
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

                val mode = widgetData.getString("widget_mode", "empty") ?: "empty"
                if (mode == "today") {
                    bindTodayMode(views, widgetData)
                } else {
                    bindEmptyMode(views, widgetData)
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
            R.id.widget_header_left,
            widgetData.getString("widget_header_left", "今日课程")
        )
        views.setTextViewText(
            R.id.widget_header_right,
            widgetData.getString("widget_header_right", "")
        )

        CARD_CONTAINER_IDS.indices.forEach { index ->
            val visible = widgetData.getBoolean("widget_card_${index}_visible", false)
            views.setViewVisibility(CARD_CONTAINER_IDS[index], if (visible) View.VISIBLE else View.GONE)
            if (!visible) {
                return@forEach
            }

            views.setTextViewText(
                CARD_TITLE_IDS[index],
                widgetData.getString("widget_card_${index}_title", "")
            )
            views.setTextViewText(
                CARD_META_IDS[index],
                widgetData.getString("widget_card_${index}_meta", "")
            )
            views.setTextViewText(
                CARD_STATUS_IDS[index],
                widgetData.getString("widget_card_${index}_status", "")
            )

            val tone = widgetData.getString("widget_card_${index}_tone", "upcoming") ?: "upcoming"
            views.setInt(CARD_CONTAINER_IDS[index], "setBackgroundResource", cardBackground(tone))
            views.setInt(CARD_STRIP_IDS[index], "setBackgroundResource", cardStrip(tone))
        }

        val overflowVisible = widgetData.getBoolean("widget_overflow_visible", false)
        views.setViewVisibility(R.id.widget_today_more, if (overflowVisible) View.VISIBLE else View.GONE)
        views.setTextViewText(
            R.id.widget_today_more,
            widgetData.getString("widget_overflow_text", "")
        )
    }

    private fun bindEmptyMode(views: RemoteViews, widgetData: SharedPreferences) {
        views.setViewVisibility(R.id.today_container, View.GONE)
        views.setViewVisibility(R.id.empty_container, View.VISIBLE)
        views.setViewVisibility(R.id.widget_today_more, View.GONE)

        views.setTextViewText(
            R.id.widget_header_left,
            widgetData.getString("widget_header_left", "今日无课")
        )
        views.setTextViewText(
            R.id.widget_header_right,
            widgetData.getString("widget_header_right", "")
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
        views.setViewVisibility(R.id.widget_today_more, View.GONE)
        views.setTextViewText(R.id.widget_header_left, "课程管家")
        views.setTextViewText(R.id.widget_header_right, "同步失败")
        views.setTextViewText(R.id.card_1_title, "组件更新失败")
        views.setTextViewText(R.id.card_1_meta, "请打开 App 后点击“立即同步组件”")
        views.setTextViewText(R.id.card_1_status, "")
        views.setViewVisibility(R.id.card_1, View.VISIBLE)
        views.setViewVisibility(R.id.card_2, View.GONE)
        views.setViewVisibility(R.id.card_3, View.GONE)
        views.setViewVisibility(R.id.card_4, View.GONE)
        views.setInt(R.id.card_1, "setBackgroundResource", R.drawable.widget_card_bg_done)
        views.setInt(R.id.card_1_strip, "setBackgroundResource", R.drawable.widget_card_strip_done)
    }

    private fun cardBackground(tone: String): Int {
        return when (tone) {
            "done" -> R.drawable.widget_card_bg_done
            "live" -> R.drawable.widget_card_bg_live
            else -> R.drawable.widget_card_bg_upcoming
        }
    }

    private fun cardStrip(tone: String): Int {
        return when (tone) {
            "done" -> R.drawable.widget_card_strip_done
            "live" -> R.drawable.widget_card_strip_live
            else -> R.drawable.widget_card_strip_upcoming
        }
    }
}

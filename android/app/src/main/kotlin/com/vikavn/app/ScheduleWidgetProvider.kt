package com.vikavn.app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.graphics.Color
import android.view.View
import android.widget.RemoteViews
import java.util.Calendar
import java.util.Locale

class ScheduleWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        val views = build(context)
        ids.forEach { manager.updateAppWidget(it, views) }
    }

    companion object {
        private const val PREFS = "vika_schedule_widget"
        private val DAY_IDS = intArrayOf(
            R.id.widget_day0, R.id.widget_day1, R.id.widget_day2, R.id.widget_day3,
            R.id.widget_day4, R.id.widget_day5, R.id.widget_day6,
        )
        private val DAY_NAMES = arrayOf("Thứ 2", "Thứ 3", "Thứ 4", "Thứ 5", "Thứ 6", "Thứ 7", "Chủ nhật")

        fun save(context: Context, args: Map<*, *>) {
            val days = (args["days"] as? List<*>)?.mapNotNull { (it as? Number)?.toInt() } ?: emptyList()
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
                .putBoolean("active", args["active"] as? Boolean ?: false)
                .putBoolean("mascot", args["mascot"] as? Boolean ?: true)
                .putString("days", days.joinToString(","))
                .putInt("minute", (args["minute"] as? Number)?.toInt() ?: 18 * 60)
                .putString("trainedDay", args["trainedDay"] as? String ?: "")
                .apply()
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(ComponentName(context, ScheduleWidgetProvider::class.java))
            if (ids.isEmpty()) return
            val views = build(context)
            ids.forEach { manager.updateAppWidget(it, views) }
        }

        private fun build(context: Context): RemoteViews {
            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val views = RemoteViews(context.packageName, R.layout.schedule_widget)
            context.packageManager.getLaunchIntentForPackage(context.packageName)?.let { launch ->
                val pending = PendingIntent.getActivity(
                    context,
                    0,
                    launch,
                    PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
                )
                views.setOnClickPendingIntent(R.id.widget_root, pending)
            }
            views.setViewVisibility(
                R.id.widget_mascot,
                if (prefs.getBoolean("mascot", true)) View.VISIBLE else View.GONE,
            )

            val active = prefs.getBoolean("active", false)
            val days = prefs.getString("days", "").orEmpty().split(",").mapNotNull { it.toIntOrNull() }.toSet()
            val minute = prefs.getInt("minute", 18 * 60)
            val time = String.format(Locale.US, "%02d:%02d", minute / 60, minute % 60)
            val cal = Calendar.getInstance()
            val today = (cal.get(Calendar.DAY_OF_WEEK) + 5) % 7
            val todayKey = String.format(
                Locale.US,
                "%04d-%02d-%02d",
                cal.get(Calendar.YEAR),
                cal.get(Calendar.MONTH) + 1,
                cal.get(Calendar.DAY_OF_MONTH),
            )
            val nowMinute = cal.get(Calendar.HOUR_OF_DAY) * 60 + cal.get(Calendar.MINUTE)
            val trainedToday = prefs.getString("trainedDay", "") == todayKey

            for (i in 0 until 7) {
                val on = active && i in days
                val done = on && i == today && trainedToday
                views.setInt(
                    DAY_IDS[i],
                    "setBackgroundResource",
                    when {
                        done -> R.drawable.widget_day_done
                        on && i == today -> R.drawable.widget_day_on_today
                        on -> R.drawable.widget_day_on
                        i == today -> R.drawable.widget_day_off_today
                        else -> R.drawable.widget_day_off
                    },
                )
                views.setTextColor(
                    DAY_IDS[i],
                    when {
                        done -> Color.parseColor("#10351B")
                        on || i == today -> Color.WHITE
                        else -> Color.parseColor("#A9A4E0")
                    },
                )
            }

            if (!active || days.isEmpty()) {
                views.setTextViewText(R.id.widget_eyebrow, "LỊCH TẬP VIKA")
                views.setTextViewText(R.id.widget_title, "Mở Vika để lên lịch")
                views.setTextViewText(R.id.widget_sub, "Chọn ngày và giờ tập trong Hồ sơ")
                return views
            }

            val start = if (trainedToday) 1 else 0
            val offset = (start..7).firstOrNull { ((today + it) % 7) in days } ?: 0
            val dayLabel = when (offset) {
                0 -> "Hôm nay"
                1 -> "Ngày mai"
                else -> DAY_NAMES[(today + offset) % 7]
            }

            when {
                trainedToday -> {
                    views.setTextViewText(R.id.widget_eyebrow, "HÔM NAY")
                    views.setTextViewText(R.id.widget_title, "Đã tập xong!")
                    views.setTextViewText(R.id.widget_sub, "Buổi tới: $dayLabel · $time")
                }
                offset == 0 && nowMinute >= minute -> {
                    views.setTextViewText(R.id.widget_eyebrow, "HÔM NAY CÓ LỊCH TẬP")
                    views.setTextViewText(R.id.widget_title, "Đang chờ bạn")
                    views.setTextViewText(R.id.widget_sub, "Lịch lúc $time · chạm để tập")
                }
                offset == 0 -> {
                    views.setTextViewText(R.id.widget_eyebrow, "HÔM NAY CÓ LỊCH TẬP")
                    views.setTextViewText(R.id.widget_title, "Hôm nay · $time")
                    views.setTextViewText(R.id.widget_sub, "Chạm để mở Vika")
                }
                else -> {
                    views.setTextViewText(R.id.widget_eyebrow, "BUỔI TẬP TIẾP THEO")
                    views.setTextViewText(R.id.widget_title, "$dayLabel · $time")
                    views.setTextViewText(R.id.widget_sub, "Hôm nay nghỉ ngơi nhé")
                }
            }
            return views
        }
    }
}

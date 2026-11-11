package com.knotes.app

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.graphics.drawable.Icon
import android.os.Build
import org.json.JSONArray
import org.json.JSONObject
import java.util.Calendar

/**
 * Daily reminders that fire while the app is closed. Flutter sends the full
 * list after every data change; each alarm re-arms itself for the next day.
 */
class ReminderReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED,
            Intent.ACTION_TIMEZONE_CHANGED,
            Intent.ACTION_TIME_CHANGED -> rescheduleAll(context)
            ACTION_FIRE -> {
                val id = intent.getIntExtra(EXTRA_ID, -1)
                val reminder = load(context).firstOrNull { it.optInt("id") == id } ?: return
                post(
                    context,
                    id,
                    reminder.optString("title", "knotes"),
                    reminder.optString("body"),
                    reminder.optString("channelId", "knotes_habits"),
                    reminder.optString("route").ifEmpty { null },
                    reminder.optString("habitId").ifEmpty { null },
                )
                // The skip only applies to the day it was sent for.
                reminder.put("skipToday", false)
                arm(context, reminder, afterFire = true)
            }
            ACTION_DONE -> {
                val id = intent.getIntExtra(EXTRA_ID, -1)
                val habitId = intent.getStringExtra(EXTRA_HABIT) ?: return
                // The day the reminder was shown, even if tapped after midnight.
                val day = intent.getStringExtra(EXTRA_DAY) ?: today()
                val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                val done = prefs.getStringSet(KEY_DONE, emptySet())!!.toMutableSet()
                done.add("$habitId|$day")
                prefs.edit().putStringSet(KEY_DONE, done).apply()
                dismiss(context, id)
            }
            ACTION_SNOOZE -> {
                val id = intent.getIntExtra(EXTRA_ID, -1)
                dismiss(context, id)
                val alarms = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
                setAlarm(alarms, System.currentTimeMillis() + SNOOZE_MS, pending(context, id))
            }
        }
    }

    companion object {
        private const val ACTION_FIRE = "com.knotes.app.ACTION_REMINDER"
        private const val ACTION_DONE = "com.knotes.app.ACTION_REMINDER_DONE"
        private const val ACTION_SNOOZE = "com.knotes.app.ACTION_REMINDER_SNOOZE"
        private const val EXTRA_ID = "reminder_id"
        private const val EXTRA_HABIT = "habit_id"
        private const val EXTRA_DAY = "day"
        private const val PREFS = "knotes_reminders"
        private const val KEY_LIST = "list"
        private const val KEY_DONE = "done"
        private const val SNOOZE_MS = 30 * 60 * 1000L

        fun pendingDone(context: Context): List<String> {
            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            return prefs.getStringSet(KEY_DONE, emptySet())!!.toList()
        }

        fun acknowledgeDone(context: Context, entries: List<String>) {
            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val remaining = prefs.getStringSet(KEY_DONE, emptySet())!!.toMutableSet()
            remaining.removeAll(entries.toSet())
            prefs.edit().putStringSet(KEY_DONE, remaining).apply()
        }

        private fun today() = String.format(
            java.util.Locale.ROOT, "%1\$tY-%1\$tm-%1\$td", Calendar.getInstance()
        )

        private fun dismiss(context: Context, id: Int) {
            (context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager)?.cancel(id)
        }

        private fun flags() = PendingIntent.FLAG_UPDATE_CURRENT or
            (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0)

        private fun action(context: Context, action: String, id: Int, habitId: String?): PendingIntent {
            val intent = Intent(context, ReminderReceiver::class.java).apply {
                this.action = action
                putExtra(EXTRA_ID, id)
                if (habitId != null) putExtra(EXTRA_HABIT, habitId)
                putExtra(EXTRA_DAY, today())
            }
            // Distinct request codes per action so they do not replace each other.
            val code = id * 4 + if (action == ACTION_DONE) 1 else 2
            return PendingIntent.getBroadcast(context, code, intent, flags())
        }

        private fun setAlarm(alarms: AlarmManager, at: Long, intent: PendingIntent) {
            // Inexact on purpose: no exact-alarm permission, and minutes of drift are fine.
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                alarms.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, intent)
            } else {
                alarms.set(AlarmManager.RTC_WAKEUP, at, intent)
            }
        }

        fun schedule(context: Context, json: String) {
            val previous = load(context).map { it.optInt("id") }
            previous.forEach { cancel(context, it) }
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .edit().putString(KEY_LIST, json).apply()
            rescheduleAll(context)
        }

        private fun rescheduleAll(context: Context) {
            load(context).forEach { arm(context, it) }
        }

        private fun load(context: Context): List<JSONObject> {
            val raw = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .getString(KEY_LIST, null) ?: return emptyList()
            return try {
                val array = JSONArray(raw)
                (0 until array.length()).map { array.getJSONObject(it) }
            } catch (_: Exception) {
                emptyList()
            }
        }

        private fun pending(context: Context, id: Int): PendingIntent {
            val intent = Intent(context, ReminderReceiver::class.java).apply {
                action = ACTION_FIRE
                putExtra(EXTRA_ID, id)
            }
            return PendingIntent.getBroadcast(context, id * 4, intent, flags())
        }

        private fun cancel(context: Context, id: Int) {
            val alarms = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            alarms.cancel(pending(context, id))
        }

        private fun arm(context: Context, reminder: JSONObject, afterFire: Boolean = false) {
            val parts = reminder.optString("time").split(":")
            val hour = parts.getOrNull(0)?.toIntOrNull() ?: return
            val minute = parts.getOrNull(1)?.toIntOrNull() ?: return
            val now = Calendar.getInstance()
            val next = (now.clone() as Calendar).apply {
                set(Calendar.HOUR_OF_DAY, hour)
                set(Calendar.MINUTE, minute)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
            }
            val date = reminder.optString("date")
            if (date.isNotEmpty()) {
                // One-shot: ring on that day only, never re-arm after firing.
                if (afterFire) return
                val ymd = date.split("-").mapNotNull { it.toIntOrNull() }
                if (ymd.size != 3) return
                next.set(ymd[0], ymd[1] - 1, ymd[2])
                if (!next.after(now)) return
            } else {
                if (!next.after(now) || reminder.optBoolean("skipToday")) {
                    next.add(Calendar.DAY_OF_YEAR, 1)
                }
                val days = reminder.optString("days")
                if (days.isNotEmpty()) {
                    var guard = 0
                    while (!days.contains(isoWeekday(next).toString()) && guard++ < 7) {
                        next.add(Calendar.DAY_OF_YEAR, 1)
                    }
                }
            }
            val alarms = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            setAlarm(alarms, next.timeInMillis, pending(context, reminder.optInt("id")))
        }

        // Calendar uses Sunday = 1; Flutter sends ISO weekdays (Monday = 1).
        private fun isoWeekday(day: Calendar) = (day.get(Calendar.DAY_OF_WEEK) + 5) % 7 + 1

        fun post(
            context: Context,
            id: Int,
            title: String,
            body: String,
            channelId: String,
            route: String? = null,
            habitId: String? = null,
        ) {
            val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager ?: return
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N && !manager.areNotificationsEnabled()) return
            val open = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
                if (route != null) putExtra("route", route)
            }
            val flags = flags()
            val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                Notification.Builder(context, channelId)
            } else {
                @Suppress("DEPRECATION")
                Notification.Builder(context)
            }
            val notification = builder
                .setContentTitle(title)
                .setContentText(body)
                .setStyle(Notification.BigTextStyle().bigText(body))
                .setSmallIcon(R.mipmap.ic_launcher)
                .setAutoCancel(true)
                .setContentIntent(PendingIntent.getActivity(context, id, open, flags))
            if (habitId != null) {
                notification.addAction(
                    Notification.Action.Builder(null as Icon?, "Hecho", action(context, ACTION_DONE, id, habitId)).build()
                )
            }
            notification.addAction(
                Notification.Action.Builder(null as Icon?, "Posponer 30 min", action(context, ACTION_SNOOZE, id, null)).build()
            )
            manager.notify(id, notification.build())
        }
    }
}

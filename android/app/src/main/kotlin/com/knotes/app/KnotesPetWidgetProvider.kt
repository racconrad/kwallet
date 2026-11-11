package com.knotes.app

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.BitmapFactory
import android.graphics.Bitmap
import android.graphics.Matrix
import android.util.Base64
import android.os.Build
import android.os.SystemClock
import android.view.View
import android.widget.RemoteViews

class KnotesPetWidgetProvider : AppWidgetProvider() {

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        when (intent.action) {
            ACTION_PET_TAP -> handlePetTap(context)
            ACTION_TAP_EXPIRED -> updateAllWidgets(context)
        }
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }

    companion object {
        const val ACTION_PET_TAP = "com.knotes.app.ACTION_PET_TAP"
        const val ACTION_TAP_EXPIRED = "com.knotes.app.ACTION_TAP_EXPIRED"
        private const val TAP_REACTION_MS = 6000L
        const val PREFS_NAME = "knotes_widget_data"
        const val KEY_PET_NAME = "pet_name"
        const val KEY_PET_LEVEL = "pet_level"
        const val KEY_PET_XP = "pet_xp"
        const val KEY_PET_XP_IN_LEVEL = "pet_xp_in_level"
        const val KEY_COMPLETED_HABITS = "completed_habits"
        const val KEY_TOTAL_HABITS = "total_habits"
        const val KEY_PENDING_HABITS = "pending_habits"
        const val KEY_STATUS_MESSAGE = "status_message"
        const val KEY_PET_STYLE = "pet_style"
        const val KEY_THEME_PALETTE = "theme_palette"
        const val KEY_WIDGET_BG_MODE = "widget_bg_mode"
        const val KEY_WIDGET_BG_COLOR = "widget_bg_color"
        const val KEY_PET_POSE = "pet_pose"
        const val KEY_PET_FACING_RIGHT = "pet_facing_right"
        const val KEY_TAP_POSE = "tap_pose"
        const val KEY_TAP_MOOD = "tap_mood"
        const val KEY_PET_MOOD = "pet_mood"
        const val KEY_LAST_TAP_TIME = "last_tap_time"
        const val KEY_TAP_COUNT = "tap_count"

        private fun handlePetTap(context: Context) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val now = System.currentTimeMillis()
            val lastTap = prefs.getLong(KEY_LAST_TAP_TIME, 0L)
            val tapCount = prefs.getInt(KEY_TAP_COUNT, 0)
            val isQuickTap = (now - lastTap) < 1400L
            val newCount = if (isQuickTap) tapCount + 1 else 1

            val editor = prefs.edit()
                .putLong(KEY_LAST_TAP_TIME, now)
                .putInt(KEY_TAP_COUNT, newCount)

            if (newCount >= 4) {
                // Rapid taps trigger annoyance reaction with pixel-art red 'X'
                editor.putString(KEY_TAP_MOOD, "annoyed")
                editor.putString(KEY_TAP_POSE, "idle")
                editor.putInt(KEY_TAP_COUNT, 0)
            } else {
                // Interactive cycle: idle -> celebrate -> play -> walk
                val currentPose = prefs.getString(KEY_TAP_POSE, "idle") ?: "idle"
                val nextPose = when (currentPose) {
                    "idle" -> "celebrate"
                    "celebrate" -> "curious"
                    "curious" -> "walk"
                    else -> "idle"
                }
                editor.putString(KEY_TAP_MOOD, "happy")
                editor.putString(KEY_TAP_POSE, nextPose)
            }
            editor.apply()
            updateAllWidgets(context)
            scheduleTapExpiry(context)
        }

        // Without this the tap reaction stays until the next 30-minute system update.
        private fun scheduleTapExpiry(context: Context) {
            val intent = Intent(context, KnotesPetWidgetProvider::class.java).apply {
                action = ACTION_TAP_EXPIRED
            }
            val flags = PendingIntent.FLAG_UPDATE_CURRENT or
                (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0)
            val pending = PendingIntent.getBroadcast(context, 202, intent, flags)
            val alarms = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            alarms.set(
                AlarmManager.ELAPSED_REALTIME,
                SystemClock.elapsedRealtime() + TAP_REACTION_MS + 200L,
                pending,
            )
        }

        fun updateAppWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int
        ) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val petName = prefs.getString(KEY_PET_NAME, "Mishi") ?: "Mishi"
            val petLevel = prefs.getInt(KEY_PET_LEVEL, 1)
            val xpInLevel = prefs.getInt(KEY_PET_XP_IN_LEVEL, 0)
            val completedHabits = prefs.getInt(KEY_COMPLETED_HABITS, 0)
            val totalHabits = prefs.getInt(KEY_TOTAL_HABITS, 0)
            val pendingHabits = prefs.getInt(KEY_PENDING_HABITS, 0)
            val petStyle = (prefs.getString(KEY_PET_STYLE, "classic") ?: "classic").lowercase()
            val themePalette = (prefs.getString(KEY_THEME_PALETTE, "iris") ?: "iris").lowercase()
            val storedPose = (prefs.getString(KEY_PET_POSE, "idle") ?: "idle").lowercase()
            val storedMood = (prefs.getString(KEY_PET_MOOD, "normal") ?: "normal").lowercase()
            val bgMode = (prefs.getString(KEY_WIDGET_BG_MODE, "default") ?: "default").lowercase()
            val customBgColor = prefs.getInt(KEY_WIDGET_BG_COLOR, 0)

            val now = System.currentTimeMillis()
            val lastTap = prefs.getLong(KEY_LAST_TAP_TIME, 0L)
            val isRecentTap = (now - lastTap) <= TAP_REACTION_MS

            val effectiveMood = if (isRecentTap) prefs.getString(KEY_TAP_MOOD, storedMood) ?: storedMood else storedMood
            val effectivePose = if (isRecentTap) prefs.getString(KEY_TAP_POSE, storedPose) ?: storedPose else storedPose
            val effectiveStatus = prefs.getString(KEY_STATUS_MESSAGE, "knotes") ?: "knotes"

            val views = RemoteViews(context.packageName, R.layout.knotes_pet_widget)

            // Update brand or status message depending on dynamic state
            views.setTextViewText(R.id.widget_brand, effectiveStatus)

            // Apply background configuration (default card, transparent/no-bg, or custom color)
            when (bgMode) {
                "transparent" -> {
                    views.setInt(R.id.widget_root, "setBackgroundColor", Color.TRANSPARENT)
                    views.setInt(R.id.widget_cat_stage, "setBackgroundColor", Color.TRANSPARENT)
                    views.setInt(R.id.widget_bottom_bar, "setBackgroundResource", R.drawable.widget_bottom_bar_bg_translucent)
                }
                "color" -> {
                    val effectiveColor = if (customBgColor != 0) customBgColor else when (themePalette) {
                        "forest" -> 0xFF212722.toInt()
                        "ember" -> 0xFF291E19.toInt()
                        "ocean" -> 0xFF191F29.toInt()
                        "plum" -> 0xFF281F2C.toInt()
                        "rose" -> 0xFF2C1E23.toInt()
                        "gold" -> 0xFF2C261A.toInt()
                        else -> 0xFF1C1929.toInt()
                    }
                    views.setInt(R.id.widget_root, "setBackgroundColor", effectiveColor)
                    views.setInt(R.id.widget_cat_stage, "setBackgroundColor", Color.TRANSPARENT)
                    views.setInt(R.id.widget_bottom_bar, "setBackgroundResource", R.drawable.widget_bottom_bar_bg)
                }
                else -> {
                    views.setInt(R.id.widget_root, "setBackgroundResource", R.drawable.widget_card_bg)
                    views.setInt(R.id.widget_cat_stage, "setBackgroundResource", R.drawable.widget_cat_stage_bg)
                    views.setInt(R.id.widget_bottom_bar, "setBackgroundResource", R.drawable.widget_bottom_bar_bg)
                }
            }

            // Flutter supplies the current species, growth stage and coat from its atlas.
            val encodedSprite = prefs.getString("pet_sprite_$effectivePose", null)
                ?: prefs.getString("pet_sprite_idle", null)
            val bitmap = try {
                encodedSprite?.let {
                    val bytes = Base64.decode(it, Base64.DEFAULT)
                    BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
                }
            } catch (_: IllegalArgumentException) { null }
            if (bitmap != null) {
                val displayed = if (prefs.getBoolean(KEY_PET_FACING_RIGHT, true)) bitmap else {
                    val matrix = Matrix().apply { preScale(-1f, 1f) }
                    Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height, matrix, false)
                }
                views.setImageViewBitmap(R.id.widget_cat_avatar, displayed)
            } else {
                views.setImageViewResource(R.id.widget_cat_avatar, getCatDrawableRes(context, petStyle, effectivePose))
            }

            // Mood indicators (Pixel Art Red 'X' for annoyed, Heart for happy)
            when {
                effectiveMood == "annoyed" -> {
                    views.setViewVisibility(R.id.widget_cat_anger_x, View.VISIBLE)
                    views.setViewVisibility(R.id.widget_cat_heart, View.GONE)
                }
                effectiveMood == "happy" && effectivePose != "sleep" -> {
                    views.setViewVisibility(R.id.widget_cat_anger_x, View.GONE)
                    views.setViewVisibility(R.id.widget_cat_heart, View.VISIBLE)
                }
                else -> {
                    views.setViewVisibility(R.id.widget_cat_anger_x, View.GONE)
                    views.setViewVisibility(R.id.widget_cat_heart, View.GONE)
                }
            }

            // Theme colors
            val (accentColor, chipBgRes) = when (themePalette) {
                "forest" -> Pair(0xFFB2D39C.toInt(), R.drawable.widget_chip_accent_forest)
                "ember" -> Pair(0xFFFFB59A.toInt(), R.drawable.widget_chip_accent_ember)
                "ocean" -> Pair(0xFFAAC7FF.toInt(), R.drawable.widget_chip_accent_ocean)
                "plum" -> Pair(0xFFD9B7ED.toInt(), R.drawable.widget_chip_accent_plum)
                "rose" -> Pair(0xFFF1B3C7.toInt(), R.drawable.widget_chip_accent_rose)
                "gold" -> Pair(0xFFE9CB81.toInt(), R.drawable.widget_chip_accent_gold)
                else -> Pair(0xFFC7B8FF.toInt(), R.drawable.widget_chip_accent_iris)
            }

            views.setTextViewText(R.id.widget_pet_name, petName.uppercase())
            views.setTextViewText(R.id.widget_pet_level, "Nv. $petLevel")
            views.setTextColor(R.id.widget_pet_level, accentColor)
            views.setInt(R.id.widget_pet_level, "setBackgroundResource", chipBgRes)

            views.setProgressBar(R.id.widget_pet_xp_progress, 100, xpInLevel.coerceIn(0, 100), false)
            views.setTextViewText(R.id.widget_pet_xp_text, "$xpInLevel / 100 XP")

            val habitsSummary = if (totalHabits == 0) {
                "Sin habitos"
            } else if (pendingHabits == 0) {
                "$completedHabits/$totalHabits listos"
            } else {
                "$pendingHabits pend. ($completedHabits/$totalHabits)"
            }
            views.setTextViewText(R.id.widget_habits_summary, habitsSummary)
            views.setInt(R.id.widget_habit_icon, "setColorFilter", accentColor)

            // PendingIntent flags
            val pendingIntentFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            } else {
                PendingIntent.FLAG_UPDATE_CURRENT
            }

            // 1. Interactive Pet Tap PendingIntent (on stage and avatar)
            val tapIntent = Intent(context, KnotesPetWidgetProvider::class.java).apply {
                action = ACTION_PET_TAP
            }
            val pendingTap = PendingIntent.getBroadcast(context, 201, tapIntent, pendingIntentFlags)
            views.setOnClickPendingIntent(R.id.widget_cat_stage, pendingTap)
            views.setOnClickPendingIntent(R.id.widget_cat_avatar, pendingTap)

            // 2. Launch App PendingIntent (on bottom bar for tasks/habits)
            val launchIntent = Intent(context, MainActivity::class.java).apply {
                action = Intent.ACTION_MAIN
                addCategory(Intent.CATEGORY_LAUNCHER)
                setFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                putExtra("route", "habits")
            }
            val pendingLaunch = PendingIntent.getActivity(context, 0, launchIntent, pendingIntentFlags)
            views.setOnClickPendingIntent(R.id.widget_bottom_bar, pendingLaunch)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }

        private fun getCatDrawableRes(context: Context, style: String, pose: String): Int {
            val candidateName = when {
                style == "classic" && pose == "idle" -> "ic_widget_cat"
                style == "classic" -> "ic_widget_cat_$pose"
                pose == "idle" -> "ic_widget_cat_$style"
                else -> "ic_widget_cat_${style}_$pose"
            }
            val resId = context.resources.getIdentifier(candidateName, "drawable", context.packageName)
            if (resId != 0) return resId

            // Fallback to idle of style
            val fallbackStyle = "ic_widget_cat_$style"
            val fallbackStyleId = context.resources.getIdentifier(fallbackStyle, "drawable", context.packageName)
            if (fallbackStyleId != 0) return fallbackStyleId

            return R.drawable.ic_widget_cat
        }

        fun updateAllWidgets(context: Context) {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val component = ComponentName(context, KnotesPetWidgetProvider::class.java)
            val ids = appWidgetManager.getAppWidgetIds(component)
            if (ids != null && ids.isNotEmpty()) {
                for (id in ids) {
                    updateAppWidget(context, appWidgetManager, id)
                }
            }
        }
    }
}

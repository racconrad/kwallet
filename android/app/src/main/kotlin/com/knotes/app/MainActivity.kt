package com.knotes.app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.Manifest
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val WIDGET_CHANNEL = "com.knotes.app/widget"
    private val NOTIFICATION_CHANNEL = "com.knotes.app/notifications"
    private var pendingNotificationResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val vault = CredentialVault(applicationContext)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.knotes.app/credentials").setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "read" -> result.success(vault.read())
                    "write" -> { vault.write(call.argument<String>("token")); result.success(null) }
                    else -> result.notImplemented()
                }
            } catch (_: Exception) {
                result.error("CREDENTIAL_STORE", "No se pudo acceder al almacenamiento seguro", null)
            }
        }
        createNotificationChannels()

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, WIDGET_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "updateWidgetData", "updatePetState" -> {
                    val args = call.arguments as? Map<*, *>
                    if (args != null) {
                        val prefs = getSharedPreferences(KnotesPetWidgetProvider.PREFS_NAME, Context.MODE_PRIVATE)
                        val editor = prefs.edit()

                        (args["pet_name"] as? String)?.let { editor.putString(KnotesPetWidgetProvider.KEY_PET_NAME, it) }
                        (args["pet_level"] as? Number)?.let { editor.putInt(KnotesPetWidgetProvider.KEY_PET_LEVEL, it.toInt()) }
                        (args["pet_xp"] as? Number)?.let { editor.putInt(KnotesPetWidgetProvider.KEY_PET_XP, it.toInt()) }
                        (args["pet_xp_in_level"] as? Number)?.let { editor.putInt(KnotesPetWidgetProvider.KEY_PET_XP_IN_LEVEL, it.toInt()) }
                        (args["completed_habits"] as? Number)?.let { editor.putInt(KnotesPetWidgetProvider.KEY_COMPLETED_HABITS, it.toInt()) }
                        (args["total_habits"] as? Number)?.let { editor.putInt(KnotesPetWidgetProvider.KEY_TOTAL_HABITS, it.toInt()) }
                        (args["pending_habits"] as? Number)?.let { editor.putInt(KnotesPetWidgetProvider.KEY_PENDING_HABITS, it.toInt()) }
                        (args["status_message"] as? String)?.let { editor.putString(KnotesPetWidgetProvider.KEY_STATUS_MESSAGE, it) }
                        (args["pet_style"] as? String)?.let { editor.putString(KnotesPetWidgetProvider.KEY_PET_STYLE, it) }
                        (args["theme_palette"] as? String)?.let { editor.putString(KnotesPetWidgetProvider.KEY_THEME_PALETTE, it) }
                        (args["widget_bg_mode"] as? String)?.let { editor.putString(KnotesPetWidgetProvider.KEY_WIDGET_BG_MODE, it) }
                        (args["widget_bg_color"] as? Number)?.let { editor.putInt(KnotesPetWidgetProvider.KEY_WIDGET_BG_COLOR, it.toInt()) }

                        (args["pet_pose"] as? String)?.let {
                            editor.putString(KnotesPetWidgetProvider.KEY_PET_POSE, it)
                            editor.putLong(KnotesPetWidgetProvider.KEY_LAST_TAP_TIME, 0L)
                        }
                        (args["pet_mood"] as? String)?.let { editor.putString(KnotesPetWidgetProvider.KEY_PET_MOOD, it) }
                        (args["pet_facing_right"] as? Boolean)?.let { editor.putBoolean(KnotesPetWidgetProvider.KEY_PET_FACING_RIGHT, it) }
                        (args["pet_sprites"] as? Map<*, *>)?.forEach { (pose, sprite) ->
                            if (pose is String && sprite is String && sprite.length <= 200000) {
                                editor.putString("pet_sprite_$pose", sprite)
                            }
                        }

                        editor.apply()
                        KnotesPetWidgetProvider.updateAllWidgets(applicationContext)
                        result.success(true)
                    } else {
                        result.error("INVALID_ARGUMENTS", "Arguments must be a map", null)
                    }
                }
                "getLaunchRoute" -> {
                    val route = intent?.getStringExtra("route")
                    intent?.removeExtra("route")
                    result.success(route)
                }
                "consumePendingAffection" -> {
                    result.success(0)
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NOTIFICATION_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "showNotification" -> {
                    val args = call.arguments as? Map<*, *>
                    if (args != null) {
                        val id = (args["id"] as? Number)?.toInt() ?: 1000
                        val title = args["title"] as? String ?: "knotes"
                        val body = args["body"] as? String ?: ""
                        val channelId = args["channelId"] as? String ?: "knotes_habits"
                        showSystemNotification(id, title, body, channelId)
                        result.success(true)
                    } else {
                        result.error("INVALID_ARGUMENTS", "Arguments must be a map", null)
                    }
                }
                "areNotificationsEnabled" -> {
                    val manager = getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
                    val enabled = manager?.areNotificationsEnabled() ?: true
                    result.success(enabled)
                }
                "requestNotificationPermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        if (checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED) {
                            result.success(true)
                        } else {
                            pendingNotificationResult = result
                            requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 101)
                        }
                    } else {
                        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
                        result.success(manager?.areNotificationsEnabled() ?: true)
                    }
                }
                "openUrl" -> {
                    val url = call.argument<String>("url")
                    if (url != null) {
                        try {
                            val browserIntent = Intent(Intent.ACTION_VIEW, Uri.parse(url)).apply {
                                flags = Intent.FLAG_ACTIVITY_NEW_TASK
                            }
                            startActivity(browserIntent)
                            result.success(true)
                        } catch (_: Exception) {
                            result.success(false)
                        }
                    } else {
                        result.error("INVALID_URL", "URL cannot be null", null)
                    }
                }
                "pendingReminderDone" -> result.success(ReminderReceiver.pendingDone(this))
                "acknowledgeReminderDone" -> {
                    val entries = call.argument<List<String>>("entries") ?: emptyList()
                    ReminderReceiver.acknowledgeDone(this, entries)
                    result.success(null)
                }
                "scheduleReminders" -> {
                    val json = call.arguments as? String
                    if (json != null) {
                        ReminderReceiver.schedule(this, json)
                        result.success(true)
                    } else {
                        result.error("INVALID_ARGUMENTS", "Expected a JSON list", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager ?: return
            val channels = listOf(
                NotificationChannel("knotes_habits", "Hábitos y Rutinas", NotificationManager.IMPORTANCE_DEFAULT).apply {
                    description = "Recordatorios de hábitos y rutinas diarias"
                },
                NotificationChannel("knotes_finances", "Finanzas y Compromisos", NotificationManager.IMPORTANCE_DEFAULT).apply {
                    description = "Alertas de compromisos y presupuestos"
                },
                NotificationChannel("knotes_pet", "Mascota y Compañero", NotificationManager.IMPORTANCE_DEFAULT).apply {
                    description = "Avisos y cuidados de tu mascota"
                }
            )
            for (channel in channels) {
                manager.createNotificationChannel(channel)
            }
        }
    }

    private fun showSystemNotification(id: Int, title: String, body: String, channelId: String) =
        ReminderReceiver.post(this, id, title, body, channelId)

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 101) {
            val granted = grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
            pendingNotificationResult?.success(granted)
            pendingNotificationResult = null
        }
    }
}

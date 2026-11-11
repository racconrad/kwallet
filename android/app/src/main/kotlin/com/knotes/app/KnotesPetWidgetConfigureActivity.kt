package com.knotes.app

import android.app.Activity
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.os.Bundle
import android.view.Gravity
import android.view.View
import android.widget.*

class KnotesPetWidgetConfigureActivity : Activity() {

    private var appWidgetId = AppWidgetManager.INVALID_APPWIDGET_ID

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Set result to CANCELED in case user cancels or exits
        setResult(RESULT_CANCELED)

        appWidgetId = intent?.extras?.getInt(
            AppWidgetManager.EXTRA_APPWIDGET_ID,
            AppWidgetManager.INVALID_APPWIDGET_ID
        ) ?: AppWidgetManager.INVALID_APPWIDGET_ID

        if (appWidgetId == AppWidgetManager.INVALID_APPWIDGET_ID) {
            finish()
            return
        }

        val prefs = getSharedPreferences(KnotesPetWidgetProvider.PREFS_NAME, Context.MODE_PRIVATE)
        var selectedPalette = prefs.getString(KnotesPetWidgetProvider.KEY_THEME_PALETTE, "iris") ?: "iris"
        var selectedBgMode = prefs.getString(KnotesPetWidgetProvider.KEY_WIDGET_BG_MODE, "default") ?: "default"
        var selectedPetStyle = prefs.getString(KnotesPetWidgetProvider.KEY_PET_STYLE, "classic") ?: "classic"

        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(48, 40, 48, 40)
            gravity = Gravity.CENTER_HORIZONTAL
            val bg = GradientDrawable().apply {
                setColor(0xFF1E221E.toInt())
                cornerRadius = 32f
            }
            background = bg
        }

        val title = TextView(this).apply {
            text = "Personalizar Widget knotes"
            textSize = 20f
            setTextColor(Color.WHITE)
            gravity = Gravity.CENTER
            setPadding(0, 0, 0, 24)
        }
        root.addView(title)

        // 1. Selector de Paleta / Tema
        val paletteLabel = TextView(this).apply {
            text = "Paleta de color:"
            textSize = 14f
            setTextColor(0xFFB0B8AE.toInt())
            setPadding(0, 8, 0, 8)
        }
        root.addView(paletteLabel)

        val palettes = listOf(
            "iris" to "Iris (Violeta)",
            "ember" to "Brasa (Naranja)",
            "ocean" to "Océano (Azul)",
            "forest" to "Bosque (Verde)",
            "plum" to "Ciruela (Púrpura)",
            "rose" to "Rosa",
            "gold" to "Miel (Dorado)"
        )
        val paletteSpinner = Spinner(this).apply {
            adapter = ArrayAdapter(
                this@KnotesPetWidgetConfigureActivity,
                android.R.layout.simple_spinner_dropdown_item,
                palettes.map { it.second }
            )
            val initialIndex = palettes.indexOfFirst { it.first == selectedPalette }.coerceAtLeast(0)
            setSelection(initialIndex)
            onItemSelectedListener = object : AdapterView.OnItemSelectedListener {
                override fun onItemSelected(p0: AdapterView<*>?, p1: View?, position: Int, id: Long) {
                    selectedPalette = palettes[position].first
                }
                override fun onNothingSelected(p0: AdapterView<*>?) {}
            }
        }
        root.addView(paletteSpinner)

        // 2. Fondo del Widget
        val bgLabel = TextView(this).apply {
            text = "Fondo del widget:"
            textSize = 14f
            setTextColor(0xFFB0B8AE.toInt())
            setPadding(0, 20, 0, 8)
        }
        root.addView(bgLabel)

        val bgModes = listOf(
            "default" to "Tarjeta sólida",
            "transparent" to "Sin fondo (Transparente)"
        )
        val bgSpinner = Spinner(this).apply {
            adapter = ArrayAdapter(
                this@KnotesPetWidgetConfigureActivity,
                android.R.layout.simple_spinner_dropdown_item,
                bgModes.map { it.second }
            )
            val initialIndex = bgModes.indexOfFirst { it.first == selectedBgMode }.coerceAtLeast(0)
            setSelection(initialIndex)
            onItemSelectedListener = object : AdapterView.OnItemSelectedListener {
                override fun onItemSelected(p0: AdapterView<*>?, p1: View?, position: Int, id: Long) {
                    selectedBgMode = bgModes[position].first
                }
                override fun onNothingSelected(p0: AdapterView<*>?) {}
            }
        }
        root.addView(bgSpinner)

        // 3. Estilo de Mascota
        val petLabel = TextView(this).apply {
            text = "Compañero:"
            textSize = 14f
            setTextColor(0xFFB0B8AE.toInt())
            setPadding(0, 20, 0, 8)
        }
        root.addView(petLabel)

        val petStyles = listOf(
            "classic" to "Mishi (Clásico)",
            "cream" to "Canela",
            "ink" to "Sombra",
            "ginger" to "Naranjito",
            "siamese" to "Milo (Siamés)",
            "calico" to "Manchas (Calicó)",
            "silver" to "Plata",
            "snow" to "Copito"
        )
        val petSpinner = Spinner(this).apply {
            adapter = ArrayAdapter(
                this@KnotesPetWidgetConfigureActivity,
                android.R.layout.simple_spinner_dropdown_item,
                petStyles.map { it.second }
            )
            val initialIndex = petStyles.indexOfFirst { it.first == selectedPetStyle }.coerceAtLeast(0)
            setSelection(initialIndex)
            onItemSelectedListener = object : AdapterView.OnItemSelectedListener {
                override fun onItemSelected(p0: AdapterView<*>?, p1: View?, position: Int, id: Long) {
                    selectedPetStyle = petStyles[position].first
                }
                override fun onNothingSelected(p0: AdapterView<*>?) {}
            }
        }
        root.addView(petSpinner)

        val spacer = Space(this).apply {
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                32
            )
        }
        root.addView(spacer)

        // Botón Guardar
        val saveButton = Button(this).apply {
            text = "Guardar widget"
            setTextColor(Color.BLACK)
            val btnBg = GradientDrawable().apply {
                setColor(0xFFC7B8FF.toInt())
                cornerRadius = 24f
            }
            background = btnBg
            setOnClickListener {
                prefs.edit()
                    .putString(KnotesPetWidgetProvider.KEY_THEME_PALETTE, selectedPalette)
                    .putString(KnotesPetWidgetProvider.KEY_WIDGET_BG_MODE, selectedBgMode)
                    .putString(KnotesPetWidgetProvider.KEY_PET_STYLE, selectedPetStyle)
                    .apply()

                val appWidgetManager = AppWidgetManager.getInstance(this@KnotesPetWidgetConfigureActivity)
                KnotesPetWidgetProvider.updateAppWidget(this@KnotesPetWidgetConfigureActivity, appWidgetManager, appWidgetId)

                val resultValue = Intent().apply {
                    putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
                }
                setResult(RESULT_OK, resultValue)
                finish()
            }
        }
        root.addView(saveButton)

        val scrollView = ScrollView(this).apply {
            addView(root)
        }
        setContentView(scrollView)
    }
}

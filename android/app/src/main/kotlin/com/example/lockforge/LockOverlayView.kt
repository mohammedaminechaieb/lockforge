package com.example.lockforge

import android.app.WallpaperManager
import android.content.Context
import android.graphics.*
import android.os.Handler
import android.os.Looper
import android.view.MotionEvent
import android.view.View
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONObject
import java.util.Calendar
import android.graphics.drawable.BitmapDrawable

/**
 * Reads two things pushed from the Flutter side via home_widget's shared
 * storage (same HomeWidgetPlugin.getData() helper NightDeckWidgetProvider
 * uses — see NightDeck's project for the reference pattern):
 *   - "theme_json"       — the full ThemePack (background choice, every
 *                           widget's type/position/font/color/clock
 *                           format) pushed whenever the user opens the
 *                           in-app preview or taps "Push current design
 *                           now" on the Lock Screen settings screen.
 *   - "live_values_json" — a small map of last-known live values
 *                           {"weather": "...", "steps": "...",
 *                           "calendar": "..."} refreshed the same way.
 * "clock" widgets are rendered with a true native live clock — no need
 * to wait on a Dart push for something a Calendar object gives for free
 * — but the FORMAT (24h vs 12h, seconds, date) still follows whatever
 * the user configured in the editor, read from the pushed JSON.
 * Unlike a real AppWidget (limited to RemoteViews' small set of allowed
 * views), this is a full-screen window we own outright, so it can render
 * the exact arbitrary canvas positions/styles the user designed — no
 * RemoteViews restrictions apply here.
 */
class LockOverlayView(context: Context, private val onDismiss: () -> Unit) : View(context) {

    private val appContext = context.applicationContext
    private val handler = Handler(Looper.getMainLooper())
    private val tick = object : Runnable {
        override fun run() {
            invalidate()
            handler.postDelayed(this, 1000)
        }
    }

    private var wallpaper: Bitmap? = null
    private var downY = 0f

    init {
        loadWallpaper()
    }

    private fun loadWallpaper() {
        runCatching {
            val drawable = WallpaperManager.getInstance(context).drawable
            if (drawable is BitmapDrawable) wallpaper = drawable.bitmap
        }
    }

    override fun onAttachedToWindow() {
        super.onAttachedToWindow()
        handler.post(tick)
    }

    override fun onDetachedFromWindow() {
        handler.removeCallbacks(tick)
        super.onDetachedFromWindow()
    }

    override fun onTouchEvent(event: MotionEvent): Boolean {
        // Simple swipe-up-to-dismiss, echoing a real lock screen gesture.
        // (Real authentication, if the device has a secure lock set, is
        // still enforced by Android afterward — this only dismisses OUR
        // themed layer, see LockActivity's class doc.)
        when (event.action) {
            MotionEvent.ACTION_DOWN -> downY = event.y
            MotionEvent.ACTION_UP -> if (downY - event.y > 120) onDismiss()
        }
        return true
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)

        val data = HomeWidgetPlugin.getData(appContext)
        val themeJson = data.getString("theme_json", null)
        val theme = themeJson?.let { runCatching { JSONObject(it) }.getOrNull() }
        val useWallpaper = theme?.optBoolean("useWallpaperBackground", true) ?: true

        if (useWallpaper) {
            wallpaper?.let {
                val src = Rect(0, 0, it.width, it.height)
                val dst = Rect(0, 0, width, height)
                canvas.drawBitmap(it, src, dst, null)
            } ?: canvas.drawColor(Color.BLACK)
            // Dim scrim so text stays legible over a busy wallpaper — same
            // reason every real lock screen does this.
            canvas.drawColor(Color.argb(90, 0, 0, 0))
        } else {
            val bgColor = theme?.optInt("backgroundColor", Color.BLACK) ?: Color.BLACK
            canvas.drawColor(bgColor)
        }

        if (theme == null) return
        val liveValuesJson = data.getString("live_values_json", "{}")
        val liveValues = runCatching { JSONObject(liveValuesJson ?: "{}") }.getOrDefault(JSONObject())

        val widgets = theme.optJSONArray("widgets") ?: return
        for (i in 0 until widgets.length()) {
            drawWidget(canvas, widgets.getJSONObject(i), liveValues)
        }
    }

    private fun drawWidget(canvas: Canvas, widget: JSONObject, liveValues: JSONObject) {
        val type = widget.optString("type", "text")
        val xFraction = widget.optDouble("x", 0.5)
        val yFraction = widget.optDouble("y", 0.5)
        val fontSize = widget.optDouble("fontSize", 24.0).toFloat()
        val colorArgb = widget.optInt("color", Color.WHITE)

        val text = when (type) {
            "clock" -> liveClockText(widget)
            "text" -> widget.optString("customText", "")
            "weather" -> liveValues.optString("weather", "--")
            "steps" -> liveValues.optString("steps", "-- steps")
            "calendar" -> liveValues.optString("calendar", "No events today")
            else -> ""
        }

        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = colorArgb
            textSize = fontSize
            textAlign = Paint.Align.CENTER
        }

        val x = (xFraction * width).toFloat()
        val y = (yFraction * height).toFloat()

        // Multi-line support (clock+date combo uses \n) — drawText doesn't
        // wrap on its own, so split and draw each line stacked.
        text.split("\n").forEachIndexed { index, line ->
            canvas.drawText(line, x, y + index * (fontSize * 1.15f), paint)
        }
    }

    private fun liveClockText(widget: JSONObject): String {
        val now = Calendar.getInstance()
        val use24h = widget.optBoolean("use24HourClock", true)
        val showSeconds = widget.optBoolean("showSeconds", false)
        val showDate = widget.optBoolean("showDateWithClock", false)

        val timePart = if (use24h) {
            val h = String.format("%02d", now.get(Calendar.HOUR_OF_DAY))
            val m = String.format("%02d", now.get(Calendar.MINUTE))
            if (showSeconds) "$h:$m:${String.format("%02d", now.get(Calendar.SECOND))}" else "$h:$m"
        } else {
            var hour12 = now.get(Calendar.HOUR) 
            if (hour12 == 0) hour12 = 12
            val m = String.format("%02d", now.get(Calendar.MINUTE))
            val suffix = if (now.get(Calendar.AM_PM) == Calendar.PM) "PM" else "AM"
            if (showSeconds) "$hour12:$m:${String.format("%02d", now.get(Calendar.SECOND))} $suffix" else "$hour12:$m $suffix"
        }

        if (!showDate) return timePart

        val weekdays = arrayOf("", "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday")
        val months = arrayOf("", "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec")
        val datePart = "${weekdays[now.get(Calendar.DAY_OF_WEEK)]}, ${months[now.get(Calendar.MONTH) + 1]} ${now.get(Calendar.DAY_OF_MONTH)}"
        return "$timePart\n$datePart"
    }
}

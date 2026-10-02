package com.example.lockforge

import android.content.Context
import android.graphics.*
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.view.MotionEvent
import android.view.View
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONObject
import java.util.Calendar
import kotlin.math.max

/**
 * Renders the user's design natively from what Dart pushed via home_widget:
 *   - "theme_json"       — the full ThemePack (background + every widget)
 *   - "live_values_json" — last-known {"weather","steps","calendar"} text
 *
 * Coordinates match the Flutter editor exactly: each widget's (x, y) is
 * the CENTER of its text block as a fraction of the screen, and font
 * sizes are Flutter logical pixels (so they're scaled by screen density).
 *
 * The window behind this view is transparent and shows the system
 * wallpaper (see LockOverlayTheme), so "wallpaper" backgrounds need no
 * permission and always match the user's current wallpaper.
 */
class LockOverlayView(context: Context, private val onDismiss: () -> Unit) : View(context) {

    private val appContext = context.applicationContext
    private val density = resources.displayMetrics.density
    private val handler = Handler(Looper.getMainLooper())
    private val tick = object : Runnable {
        override fun run() {
            invalidate()
            handler.postDelayed(this, 1000)
        }
    }

    private var cachedThemeRaw: String? = null
    private var theme: JSONObject? = null
    private var liveValues = JSONObject()
    private var backgroundBitmap: Bitmap? = null

    private val textPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { textAlign = Paint.Align.CENTER }
    private val hintPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        textAlign = Paint.Align.CENTER
        color = Color.argb(170, 255, 255, 255)
        textSize = 13 * density
    }
    private val bitmapPaint = Paint(Paint.FILTER_BITMAP_FLAG)

    private var downY = 0f
    private var dragOffset = 0f

    override fun onAttachedToWindow() {
        super.onAttachedToWindow()
        handler.post(tick)
    }

    override fun onDetachedFromWindow() {
        handler.removeCallbacks(tick)
        super.onDetachedFromWindow()
    }

    override fun onTouchEvent(event: MotionEvent): Boolean {
        // Swipe up to dismiss — the view follows the finger like a real lock
        // screen. Real authentication (if set) is still enforced by Android.
        when (event.actionMasked) {
            MotionEvent.ACTION_DOWN -> {
                downY = event.y
                animate().cancel()
            }
            MotionEvent.ACTION_MOVE -> {
                dragOffset = (event.y - downY).coerceAtMost(0f)
                translationY = dragOffset
                alpha = 1f + dragOffset / height
            }
            MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                if (-dragOffset > height * 0.2f) {
                    animate().translationY(-height.toFloat()).alpha(0f).setDuration(180).withEndAction(onDismiss).start()
                } else {
                    animate().translationY(0f).alpha(1f).setDuration(180).start()
                }
                dragOffset = 0f
            }
        }
        return true
    }

    private fun reloadIfChanged() {
        val data = HomeWidgetPlugin.getData(appContext)
        val raw = data.getString("theme_json", null)
        if (raw != cachedThemeRaw) {
            cachedThemeRaw = raw
            theme = raw?.let { runCatching { JSONObject(it) }.getOrNull() }
            backgroundBitmap = loadBackgroundImage(theme)
        }
        liveValues = runCatching { JSONObject(data.getString("live_values_json", "{}") ?: "{}") }.getOrDefault(JSONObject())
    }

    private fun loadBackgroundImage(theme: JSONObject?): Bitmap? {
        if (theme?.optString("backgroundType") != "image") return null
        val path = theme.optString("backgroundImagePath").takeIf { it.isNotEmpty() } ?: return null
        return runCatching {
            // Sample down to roughly screen size so a 50 MP photo doesn't OOM.
            val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
            BitmapFactory.decodeFile(path, bounds)
            val target = max(resources.displayMetrics.widthPixels, resources.displayMetrics.heightPixels)
            var sample = 1
            while (max(bounds.outWidth, bounds.outHeight) / (sample * 2) >= target) sample *= 2
            BitmapFactory.decodeFile(path, BitmapFactory.Options().apply { inSampleSize = sample })
        }.getOrNull()
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        reloadIfChanged()
        val theme = theme

        val type = theme?.optString("backgroundType")
            ?.takeIf { it.isNotEmpty() }
            ?: if (theme?.optBoolean("useWallpaperBackground", true) != false) "wallpaper" else "color"
        val dim = (theme?.optDouble("dim", 0.2) ?: 0.2).toFloat().coerceIn(0f, 0.9f)

        when (type) {
            "color" -> canvas.drawColor(theme?.optInt("backgroundColor", Color.BLACK) ?: Color.BLACK)
            "image" -> {
                backgroundBitmap?.let { drawCenterCrop(canvas, it) } ?: canvas.drawColor(Color.BLACK)
                canvas.drawColor(Color.argb((dim * 255).toInt(), 0, 0, 0))
            }
            // Wallpaper shows through the transparent window; just add the scrim.
            else -> canvas.drawColor(Color.argb((dim * 255).toInt(), 0, 0, 0))
        }

        val widgets = theme?.optJSONArray("widgets")
        if (widgets != null) {
            for (i in 0 until widgets.length()) drawWidget(canvas, widgets.getJSONObject(i))
        }

        canvas.drawText("Swipe up to unlock", width / 2f, height - 48 * density, hintPaint)
    }

    private fun drawCenterCrop(canvas: Canvas, bmp: Bitmap) {
        val scale = max(width / bmp.width.toFloat(), height / bmp.height.toFloat())
        val w = bmp.width * scale
        val h = bmp.height * scale
        val left = (width - w) / 2f
        val top = (height - h) / 2f
        canvas.drawBitmap(bmp, null, RectF(left, top, left + w, top + h), bitmapPaint)
    }

    private fun drawWidget(canvas: Canvas, widget: JSONObject) {
        val text = when (widget.optString("type", "text")) {
            "clock" -> liveClockText(widget)
            "date" -> dateText()
            "text" -> widget.optString("customText", "")
            "weather" -> liveValues.optString("weather", "--")
            "steps" -> liveValues.optString("steps", "-- steps")
            "calendar" -> liveValues.optString("calendar", "No events today")
            else -> ""
        }
        if (text.isEmpty()) return

        val fontPx = widget.optDouble("fontSize", 24.0).toFloat() * density
        textPaint.color = widget.optInt("color", Color.WHITE)
        textPaint.textSize = fontPx
        textPaint.typeface = typefaceFor(widget)
        if (widget.optBoolean("shadow", true)) {
            textPaint.setShadowLayer(fontPx * 0.15f, 0f, density, Color.argb(140, 0, 0, 0))
        } else {
            textPaint.clearShadowLayer()
        }

        // Center the whole (possibly multi-line) block on (x, y), with the
        // same 1.15 line height the Flutter renderer uses. A clock's date
        // line is a smaller caption (see dateLineSize in canvas_widget_renderer.dart).
        val lines = text.split("\n")
        val isClockWithDate = widget.optString("type") == "clock" && lines.size == 2
        val sizes = lines.indices.map { i ->
            if (isClockWithDate && i == 1) (fontPx * 0.28f).coerceIn(12 * density, 40 * density) else fontPx
        }
        val cx = (widget.optDouble("x", 0.5) * width).toFloat()
        val cy = (widget.optDouble("y", 0.5) * height).toFloat()
        var top = cy - sizes.sumOf { (it * 1.15f).toDouble() }.toFloat() / 2f
        lines.forEachIndexed { i, line ->
            textPaint.textSize = sizes[i]
            val fm = textPaint.fontMetrics
            val lineHeight = sizes[i] * 1.15f
            val baseline = top + (lineHeight - (fm.descent - fm.ascent)) / 2f - fm.ascent
            canvas.drawText(line, cx, baseline, textPaint)
            top += lineHeight
        }
    }

    private fun typefaceFor(widget: JSONObject): Typeface {
        // New saves store the CSS-style weight (100..900); older ones the index.
        val weight = when {
            widget.has("fontWeightValue") -> widget.optInt("fontWeightValue", 400)
            widget.has("fontWeight") -> (widget.optInt("fontWeight", 3) + 1) * 100
            else -> 400
        }.coerceIn(100, 900)
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            Typeface.create(Typeface.DEFAULT, weight, false)
        } else {
            if (weight >= 600) Typeface.DEFAULT_BOLD else Typeface.DEFAULT
        }
    }

    /** Must match formatClock() in lib/widgets/canvas_widget_renderer.dart. */
    private fun liveClockText(widget: JSONObject): String {
        val now = Calendar.getInstance()
        val use24h = widget.optBoolean("use24HourClock", true)
        val showSeconds = widget.optBoolean("showSeconds", false)
        val showDate = widget.optBoolean("showDateWithClock", false)
        fun two(n: Int) = n.toString().padStart(2, '0')

        val minute = two(now.get(Calendar.MINUTE))
        val second = two(now.get(Calendar.SECOND))
        val time = if (use24h) {
            val h = two(now.get(Calendar.HOUR_OF_DAY))
            if (showSeconds) "$h:$minute:$second" else "$h:$minute"
        } else {
            val h = now.get(Calendar.HOUR).let { if (it == 0) 12 else it }
            val suffix = if (now.get(Calendar.AM_PM) == Calendar.PM) "PM" else "AM"
            if (showSeconds) "$h:$minute:$second $suffix" else "$h:$minute $suffix"
        }
        return if (showDate) "$time\n${dateText()}" else time
    }

    /** Must match formatDate() in lib/widgets/canvas_widget_renderer.dart. */
    private fun dateText(): String {
        val now = Calendar.getInstance()
        val weekdays = arrayOf("", "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday")
        val months = arrayOf("Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec")
        return "${weekdays[now.get(Calendar.DAY_OF_WEEK)]}, ${months[now.get(Calendar.MONTH)]} ${now.get(Calendar.DAY_OF_MONTH)}"
    }
}

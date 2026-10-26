package com.matsavin.pixelpals

import android.animation.ValueAnimator
import android.annotation.SuppressLint
import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RectF
import android.graphics.Typeface
import android.text.Layout
import android.text.StaticLayout
import android.text.TextPaint
import android.text.TextUtils
import android.view.MotionEvent
import android.view.View
import android.view.animation.PathInterpolator
import kotlin.math.abs
import kotlin.math.sin

/**
 * The peeking pal: no pill, just the pet sitting to the right of the front camera hole (the clock
 * is on the left, status icons far right, so that spot is free). Tapping it (with [TapService] on)
 * or the Peek notification button opens a card just below the status bar with the mood, today's
 * message, zodiac sign and care bars. Tapping the pet in the card pets it; anywhere else closes it.
 *
 * Battery: redraws at 8 fps only while visible with the screen on; stops while the phone sleeps.
 */
@SuppressLint("ViewConstructor")
class IslandView(context: Context, private val holeSize: Float, private val onSizeChange: () -> Unit) : View(context) {
    private val dp = resources.displayMetrics.density

    var profile: Profile? = null
    var care = PetCare()
    var reaction: Pair<PetEmotion, Long>? = null
    var message = ""
        set(value) {
            field = value
            cardLayout = null
        }
    var curious = true
    var asleep = false
        set(value) {
            field = value
            if (value) stopTicking() else startTicking()
            invalidate()
        }

    /** Whether the pal itself takes taps (only above the status bar, see [TapService]). */
    var tappable = false
    var onOpen: () -> Unit = {}
    var onPat: () -> Unit = {}

    /** How far down the open card slides, so it sits just below the status bar. */
    var cardShift = 0f

    /** Whether the card is open (or opening). The window is resized around this. */
    var expanded = false
        private set
    private var progress = 0f // 0 = peeking, 1 = card

    // Just taller than the camera hole, so the pet stays clear of the clock and status icons.
    val pillHeight get() = maxOf(holeSize + 8 * dp, 30 * dp)
    private val petSize get() = pillHeight - 6 * dp
    private val petGap get() = holeSize / 2 + 5 * dp

    /** Peeking, the window starts at the hole's centre and only covers the pet (the tap target). */
    val collapsedWidth get() = petGap + petSize + 6 * dp
    val cardWidth = 300 * dp
    val currentWidth get() = if (expanded) cardWidth else collapsedWidth
    val currentHeight get() = if (expanded) cardShift + cardHeight() else pillHeight + 8 * dp // room for a small hop

    private val fill = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.argb(170, 0, 0, 0) }
    private val outline = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeWidth = 1 * dp
        color = Color.argb(40, 255, 255, 255)
    }
    private val signPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { textAlign = Paint.Align.CENTER }
    private val titlePaint = TextPaint(Paint.ANTI_ALIAS_FLAG).apply { textSize = 13 * dp; typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD) }
    private val bodyPaint = TextPaint(Paint.ANTI_ALIAS_FLAG).apply { textSize = 13 * dp; color = Color.argb(235, 255, 255, 255) }
    private val barPaint = Paint(Paint.ANTI_ALIAS_FLAG)
    private val zPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.WHITE; textSize = 9 * dp; typeface = Typeface.DEFAULT_BOLD }

    private val cardPad = 14 * dp
    private val cardPet get() = 44 * dp
    private var cardLayout: StaticLayout? = null

    private fun layout(): StaticLayout {
        cardLayout?.let { return it }
        val width = (cardWidth - 2 * cardPad).toInt()
        return StaticLayout.Builder.obtain(message, 0, message.length, bodyPaint, width)
            .setAlignment(Layout.Alignment.ALIGN_NORMAL).setLineSpacing(2 * dp, 1f)
            .setMaxLines(3).setEllipsize(TextUtils.TruncateAt.END).build().also { cardLayout = it }
    }

    /** Card height fitted to its content: pet row, message, bars. */
    private fun cardHeight() = cardPad + cardPet + 10 * dp + layout().height + 14 * dp + 5 * dp + cardPad

    // --- Animation ---------------------------------------------------------------------------

    private val ticker = object : Runnable {
        override fun run() {
            invalidate()
            postDelayed(this, 125)
        }
    }
    private var ticking = false

    private fun startTicking() {
        if (ticking || asleep || !isAttachedToWindow) return
        ticking = true
        post(ticker)
    }

    private fun stopTicking() {
        ticking = false
        removeCallbacks(ticker)
    }

    override fun onAttachedToWindow() {
        super.onAttachedToWindow()
        startTicking()
        // Pops in when it first appears.
        scaleX = 0.6f
        scaleY = 0.6f
        alpha = 0f
        animate().scaleX(1f).scaleY(1f).alpha(1f).setDuration(260).setInterpolator(EASE).start()
    }

    override fun onDetachedFromWindow() {
        stopTicking()
        super.onDetachedFromWindow()
    }

    private var animator: ValueAnimator? = null

    fun setExpanded(value: Boolean) {
        if (value == expanded && animator == null) return
        animator?.cancel()
        if (value) {
            expanded = true
            onSizeChange() // grow the window first, then animate into it
        }
        animator = ValueAnimator.ofFloat(progress, if (value) 1f else 0f).apply {
            duration = 240
            interpolator = EASE
            addUpdateListener {
                progress = it.animatedValue as Float
                invalidate()
            }
            addListener(object : android.animation.AnimatorListenerAdapter() {
                override fun onAnimationEnd(animation: android.animation.Animator) {
                    animator = null
                    if (!value) {
                        expanded = false
                        onSizeChange() // shrink the window back to the pill
                    }
                }
            })
            start()
        }
    }

    private var petRect = RectF()

    @SuppressLint("ClickableViewAccessibility")
    override fun onTouchEvent(event: MotionEvent): Boolean {
        if (!expanded && !tappable) return false
        when (event.action) {
            MotionEvent.ACTION_OUTSIDE -> if (expanded) setExpanded(false)
            MotionEvent.ACTION_UP -> when {
                !expanded -> onOpen()
                petRect.contains(event.x, event.y) -> onPat()
                event.y >= cardShift * progress -> setExpanded(false)
            }
        }
        return true
    }

    private fun emotion(now: Long): PetEmotion {
        val r = reaction
        if (r != null && now - r.second < 4_000) return r.first
        return care.at(now).emotion
    }

    // --- Drawing -----------------------------------------------------------------------------

    override fun onDraw(canvas: Canvas) {
        val p = profile ?: return
        val now = System.currentTimeMillis()
        val t = now / 1000.0
        val emotion = emotion(now)
        val reacting = reaction?.let { now - it.second < 4_000 } == true
        val wiggle = !asleep && emotion != PetEmotion.SAD && (t % 6.0) < 0.7
        val frame = when {
            asleep -> 1
            wiggle || reacting -> 2
            (t % 3.4) < 0.18 -> 1
            else -> emotion.frame
        }
        val hop = when {
            asleep -> 0f
            reacting -> abs(sin(t * 9)).toFloat() * 2 * dp
            wiggle -> abs(sin(t * 9)).toFloat() * 1.5f * dp
            else -> 0f
        }

        // No background while peeking; the card fades and grows in as it opens, sliding down below
        // the status bar. Peeking, the hole's centre is the window's left edge; open, its middle.
        val centerX = if (expanded) cardWidth / 2 else 0f
        val top = cardShift * progress
        val bgWidth = lerp(petSize * 2, cardWidth, progress)
        val bgHeight = lerp(pillHeight, cardHeight(), progress)
        val left = centerX - bgWidth / 2
        if (progress > 0f) {
            val radius = lerp(pillHeight / 2, 22 * dp, progress)
            val rect = RectF(left, top, left + bgWidth, top + bgHeight)
            fill.alpha = (170 * progress).toInt()
            outline.alpha = (40 * progress).toInt()
            canvas.drawRoundRect(rect, radius, radius, fill)
            canvas.drawRoundRect(rect, radius, radius, outline)
        }

        // The pet: just right of the camera hole while peeking; larger at the card's top-left.
        val size = lerp(petSize, cardPet, progress)
        val petLeft = lerp(centerX + petGap, left + cardPad, progress)
        val petTop = lerp((pillHeight - petSize) / 2, top + cardPad, progress) - hop
        petRect.set(petLeft - 6 * dp, petTop - 6 * dp, petLeft + size + 6 * dp, petTop + size + 6 * dp)
        canvas.save()
        val tilt = curious && !asleep && emotion != PetEmotion.SAD && emotion != PetEmotion.SLEEPY
        if (tilt) canvas.rotate(-10f * (1 - progress), petLeft + size / 2, petTop + size / 2)
        Sprites.draw(canvas, p.pet, frame, p.accessory, petLeft, petTop, size)
        canvas.restore()
        if (asleep) canvas.drawText("z", petLeft + size - dp, petTop + 3 * dp, zPaint)

        // The zodiac sign only appears in the card.
        if (progress > 0f) {
            signPaint.color = p.pet.accent
            signPaint.alpha = (255 * progress).toInt()
            signPaint.textSize = 18 * dp
            canvas.drawText(p.sign.symbol, left + bgWidth - cardPad - 10 * dp, top + cardPad + 18 * dp, signPaint)
        }

        if (progress > 0.4f) {
            canvas.save()
            canvas.translate(0f, top)
            drawCard(canvas, p, emotion, left, ((progress - 0.4f) / 0.6f).coerceIn(0f, 1f))
            canvas.restore()
        }
    }

    private fun drawCard(canvas: Canvas, p: Profile, emotion: PetEmotion, left: Float, fade: Float) {
        val alpha = (fade * 255).toInt()
        // Mood next to the pet.
        titlePaint.color = p.pet.accent
        titlePaint.alpha = alpha
        canvas.drawText(context.getString(emotion.lineRes, p.name), left + cardPad + cardPet + 10 * dp, cardPad + cardPet / 2 + 5 * dp, titlePaint)

        var y = cardPad + cardPet + 10 * dp
        bodyPaint.alpha = (alpha * 0.92f).toInt()
        canvas.save()
        canvas.translate(left + cardPad, y)
        layout().draw(canvas)
        canvas.restore()
        y += layout().height + 14 * dp

        // Food, Fun and Energy.
        val c = care.at()
        val gap = 8 * dp
        val barWidth = (cardWidth - 2 * cardPad - 2 * gap) / 3
        listOf(c.food to rgb(255, 159, 10), c.fun_ to rgb(10, 132, 255), c.energy to rgb(191, 90, 242)).forEachIndexed { i, (value, color) ->
            val x = left + cardPad + i * (barWidth + gap)
            barPaint.color = Color.argb((50 * fade).toInt(), 255, 255, 255)
            canvas.drawRoundRect(RectF(x, y, x + barWidth, y + 5 * dp), 3 * dp, 3 * dp, barPaint)
            barPaint.color = if (value < PetCare.LOW) rgb(255, 69, 58) else color
            barPaint.alpha = alpha
            canvas.drawRoundRect(RectF(x, y, x + barWidth * value.toFloat(), y + 5 * dp), 3 * dp, 3 * dp, barPaint)
        }
    }

    private fun lerp(a: Float, b: Float, t: Float) = a + (b - a) * t

    companion object {
        private val EASE = PathInterpolator(0.2f, 0f, 0f, 1f) // Material "emphasized" easing
    }
}

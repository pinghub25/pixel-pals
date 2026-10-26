package com.matsavin.pixelpals

import android.app.AppOpsManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.graphics.PixelFormat
import android.graphics.Rect
import android.hardware.display.DisplayManager
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.Process
import android.provider.Settings
import android.view.Display
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.launch

/** Keeps the pal beside the front camera, over every app. */
class IslandService : Service() {
    private lateinit var windowManager: WindowManager
    private var host: WindowManager? = null // whichever window manager the pal was added with
    private var view: IslandView? = null
    private var hole = Rect()
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
    private val handler = Handler(Looper.getMainLooper())

    override fun onBind(intent: Intent?): IBinder? = null

    /**
     * App overlays sit under the status bar, which takes every touch in that strip, so without
     * [TapService] the pal can't be tapped there. The notification's Peek and Pet buttons always work.
     */
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_PEEK -> peek()
            ACTION_PET -> Pals.perform(this, PetAction.PAT)
            // Started again (e.g. right after notifications were allowed): post the notification
            // again, since one posted while they were blocked never shows up.
            null -> startAsForeground()
            ACTION_REATTACH -> {
                removePill()
                addPill()
            }
        }
        return START_STICKY
    }

    private val collapse = Runnable { view?.takeIf { it.expanded }?.setExpanded(false) }

    private fun peek() {
        val v = view ?: return
        if (hidden) return // fullscreen or landscape
        v.setExpanded(true)
        handler.removeCallbacks(collapse)
        handler.postDelayed(collapse, 5_000)
    }

    override fun onCreate() {
        super.onCreate()
        Pals.load(this)
        startAsForeground()
        windowManager = getSystemService(WindowManager::class.java)
        hole = cameraHole()
        addProbe()
        addPill()
        registerComponentCallbacks(rotation)
        registerReceiver(screenReceiver, IntentFilter().apply {
            addAction(Intent.ACTION_SCREEN_OFF)
            addAction(Intent.ACTION_USER_PRESENT)
        })
        scope.launch {
            combine(Pals.profile, Pals.care, Pals.reaction, Pals.revision) { p, c, r, _ -> Triple(p, c, r) }.collect { (p, c, r) ->
                val v = view ?: return@collect
                v.profile = p
                v.care = c
                v.reaction = r
                v.message = p?.let { Messages.today(this@IslandService, it) } ?: ""
                v.invalidate()
            }
        }
        handler.post(appWatcher)
    }

    override fun onDestroy() {
        handler.removeCallbacksAndMessages(null)
        runCatching { unregisterReceiver(screenReceiver) }
        runCatching { unregisterComponentCallbacks(rotation) }
        removePill()
        probe?.let { runCatching { windowManager.removeView(it) } }
        scope.cancel()
        super.onDestroy()
    }

    /** The front camera's punch hole, from the display cutout; a centred guess if there is none. */
    private fun cameraHole(): Rect {
        val display = getSystemService(DisplayManager::class.java).getDisplay(Display.DEFAULT_DISPLAY)
        val rect = display?.cutout?.boundingRects?.firstOrNull { it.top < 300 && it.width() < 400 }
        if (rect != null) return rect
        val dp = resources.displayMetrics.density
        val width = resources.displayMetrics.widthPixels
        val size = (26 * dp).toInt()
        return Rect(width / 2 - size / 2, (10 * dp).toInt(), width / 2 + size / 2, (10 * dp).toInt() + size)
    }

    private fun addPill() {
        val v = IslandView(this, hole.width().toFloat()) { layoutPill() }
        view = v
        // Above the status bar (and so tappable) when TapService is on; under it otherwise.
        val tapHost = TapService.windowManager()
        v.tappable = tapHost != null
        v.onOpen = { if (v.expanded) v.setExpanded(false) else peek() }
        v.onPat = {
            Pals.perform(this, PetAction.PAT)
            peek() // keeps the card open a little longer
        }
        val statusBar = resources.getIdentifier("status_bar_height", "dimen", "android").let { if (it != 0) resources.getDimensionPixelSize(it) else 0 }
        v.cardShift = maxOf(statusBar - pillTop(v), 0) + 6 * resources.displayMetrics.density
        Pals.profile.value?.let { p ->
            v.profile = p
            v.care = Pals.care.value
            v.message = Messages.today(this, p)
            v.reaction = Pals.reaction.value
        }
        host = tapHost ?: windowManager
        host!!.addView(v, pillParams(v))
        updateVisibility(v)
    }

    private var probe: View? = null

    /**
     * Hide in fullscreen apps (videos, games): the status bar is gone there, and so is the pal.
     * An invisible 1 px app overlay watches for that, since the pal's own window may sit above
     * the status bar and never see it in its insets.
     */
    private fun addProbe() {
        val p = View(this)
        p.setOnApplyWindowInsetsListener { _, insets ->
            fullscreen = !insets.isVisible(android.view.WindowInsets.Type.statusBars())
            view?.let { updateVisibility(it) }
            insets
        }
        windowManager.addView(p, WindowManager.LayoutParams(
            1, 1,
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE,
            PixelFormat.TRANSPARENT,
        ).apply { gravity = Gravity.TOP or Gravity.START })
        probe = p
    }

    private fun removePill() {
        handler.removeCallbacks(collapse)
        view?.let { v -> runCatching { host?.removeView(v) } }
        view = null
        host = null
    }

    private fun pillTop(v: IslandView) = hole.centerY() - (v.pillHeight / 2).toInt()

    private var fullscreen = false
    private var hidden = false

    /** Only shown in portrait with the status bar visible; the camera moves to the side in landscape. */
    private fun updateVisibility(v: IslandView) {
        val portrait = resources.configuration.orientation != android.content.res.Configuration.ORIENTATION_LANDSCAPE
        val show = portrait && !fullscreen
        v.animate().alpha(if (show) 1f else 0f).setDuration(180).start()
        if (!show && v.expanded) v.setExpanded(false)
        if (hidden == show) {
            hidden = !show
            layoutPill() // a hidden pal takes no taps
        }
    }

    private val rotation = object : android.content.ComponentCallbacks {
        override fun onConfigurationChanged(newConfig: android.content.res.Configuration) {
            view?.let { updateVisibility(it) }
        }

        @Deprecated("Deprecated in Java")
        override fun onLowMemory() = Unit
    }

    private fun pillParams(v: IslandView) = WindowManager.LayoutParams(
        v.currentWidth.toInt(),
        v.currentHeight.toInt(),
        if (v.tappable) WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY else WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
        WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
            WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
            WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS or
            WindowManager.LayoutParams.FLAG_WATCH_OUTSIDE_TOUCH or
            // Under the status bar the pet can't be tapped anyway, so it never blocks anything.
            (if (!hidden && (v.expanded || v.tappable)) 0 else WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE),
        PixelFormat.TRANSLUCENT,
    ).apply {
        gravity = Gravity.TOP or Gravity.START
        // Peeking, the window starts at the hole's centre; the open card is centred on the hole.
        x = if (v.expanded) hole.centerX() - (v.cardWidth / 2).toInt() else hole.centerX()
        y = pillTop(v)
        layoutInDisplayCutoutMode = if (Build.VERSION.SDK_INT >= 30) {
            WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_ALWAYS
        } else {
            WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
        }
        title = "Pixel Zodiac"
    }

    private fun layoutPill() {
        val v = view ?: return
        runCatching { host?.updateViewLayout(v, pillParams(v)) }
    }

    /** Asleep with the screen off; wakes up happy when the phone is unlocked. */
    private val screenReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            val v = view ?: return
            when (intent.action) {
                Intent.ACTION_SCREEN_OFF -> {
                    v.asleep = true
                    if (v.expanded) v.setExpanded(false)
                }
                Intent.ACTION_USER_PRESENT -> {
                    v.asleep = false
                    // Wakes up with a happy face; the card stays closed until you ask for it.
                    Pals.react(PetEmotion.HAPPY)
                    handler.removeCallbacks(appWatcher)
                    handler.post(appWatcher)
                }
            }
        }
    }

    /**
     * Optional: calm on the home screen, curious in other apps. Needs Usage access; checks every
     * 3 s only while the screen is on. Without it the pal is simply curious while the phone is in use.
     */
    private val appWatcher = object : Runnable {
        override fun run() {
            val v = view ?: return
            if (v.asleep) return
            v.curious = if (PetStore.flag(this@IslandService, PetStore.APP_AWARE) && hasUsageAccess(this@IslandService)) {
                foregroundApp()?.let { it != homeApp() } ?: true
            } else {
                true
            }
            handler.postDelayed(this, 3_000)
        }
    }

    private fun foregroundApp(): String? {
        val usage = getSystemService(UsageStatsManager::class.java)
        val now = System.currentTimeMillis()
        val events = usage.queryEvents(now - 60_000, now)
        val event = UsageEvents.Event()
        var last: String? = null
        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            if (event.eventType == UsageEvents.Event.ACTIVITY_RESUMED) last = event.packageName
        }
        return last
    }

    private fun homeApp(): String? = packageManager.resolveActivity(
        Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME),
        PackageManager.MATCH_DEFAULT_ONLY,
    )?.activityInfo?.packageName

    private fun startAsForeground() {
        val manager = getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(
            NotificationChannel(CHANNEL, getString(R.string.channel_pill), NotificationManager.IMPORTANCE_MIN),
        )
        val open = PendingIntent.getActivity(this, 0, Intent(this, MainActivity::class.java), PendingIntent.FLAG_IMMUTABLE)
        val notification = Notification.Builder(this, CHANNEL)
            .setSmallIcon(R.drawable.ic_pal)
            .setContentTitle(getString(R.string.pill_notification))
            .setContentIntent(open)
            .setOngoing(true)
            .addAction(action(ACTION_PEEK, R.string.action_peek))
            .addAction(action(ACTION_PET, R.string.action_pet))
            .build()
        if (Build.VERSION.SDK_INT >= 34) {
            startForeground(1, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
        } else {
            startForeground(1, notification)
        }
    }

    private fun action(name: String, label: Int): Notification.Action {
        // Through PeekActivity so the shade closes and the card is visible.
        val intent = PendingIntent.getActivity(
            this, name.hashCode(),
            Intent(this, PeekActivity::class.java).setAction(name).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_NO_ANIMATION),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        return Notification.Action.Builder(null, getString(label), intent).build()
    }

    companion object {
        private const val CHANNEL = "pill"
        const val ACTION_PEEK = "com.matsavin.pixelpals.PEEK"
        const val ACTION_PET = "com.matsavin.pixelpals.PET"
        private const val ACTION_REATTACH = "com.matsavin.pixelpals.REATTACH"

        fun canDraw(context: Context) = Settings.canDrawOverlays(context)

        fun start(context: Context) {
            if (canDraw(context)) context.startForegroundService(Intent(context, IslandService::class.java))
        }

        /** Moves the pal above or below the status bar when TapService connects or goes away. */
        fun reattach(context: Context) {
            if (PetStore.flag(context, PetStore.OVERLAY) && canDraw(context)) {
                runCatching { context.startService(Intent(context, IslandService::class.java).setAction(ACTION_REATTACH)) }
            }
        }

        fun stop(context: Context) {
            context.stopService(Intent(context, IslandService::class.java))
        }

        fun hasUsageAccess(context: Context): Boolean {
            val ops = context.getSystemService(AppOpsManager::class.java)
            val mode = ops.unsafeCheckOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), context.packageName)
            return mode == AppOpsManager.MODE_ALLOWED
        }
    }
}

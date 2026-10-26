package com.matsavin.pixelpals

import android.accessibilityservice.AccessibilityService
import android.content.Intent
import android.view.WindowManager
import android.view.accessibility.AccessibilityEvent
import kotlinx.coroutines.flow.MutableStateFlow

/**
 * Optional: Android keeps every app's overlay under the status bar, which swallows taps in that
 * strip. An accessibility overlay sits above it, so with this on the pal itself can be tapped.
 * It reads nothing on screen and gets no events; it only lends its window to [IslandService].
 */
class TapService : AccessibilityService() {
    override fun onServiceConnected() {
        instance = this
        connected.value = true
        IslandService.reattach(this)
    }

    override fun onUnbind(intent: Intent?): Boolean {
        instance = null
        connected.value = false
        IslandService.reattach(this)
        return super.onUnbind(intent)
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) = Unit
    override fun onInterrupt() = Unit

    companion object {
        @Volatile private var instance: TapService? = null
        val connected = MutableStateFlow(false)

        /** The window manager to add the pal with, if tapping is on. */
        fun windowManager(): WindowManager? = instance?.getSystemService(WindowManager::class.java)
    }
}

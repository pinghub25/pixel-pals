package com.matsavin.pixelpals

import android.app.Activity
import android.content.Intent
import android.os.Bundle

/**
 * Invisible, closes at once. The notification's Peek and Pet buttons open this instead of the
 * service directly, because only opening an activity makes Android close the notification shade,
 * so the card (or the reaction) is actually visible.
 */
class PeekActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val action = intent.action ?: IslandService.ACTION_PEEK
        startService(Intent(this, IslandService::class.java).setAction(action))
        finish()
        overridePendingTransition(0, 0)
    }
}

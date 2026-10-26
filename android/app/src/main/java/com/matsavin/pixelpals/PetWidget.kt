package com.matsavin.pixelpals

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews

/**
 * Home-screen widget: the pal with its current mood and accessory, plus today's message (or what
 * it needs). Android refreshes it every 30 minutes; the app also refreshes it on every change.
 */
class PetWidget : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        Pals.load(context)
        ids.forEach { manager.updateAppWidget(it, views(context)) }
    }

    companion object {
        fun updateAll(c: Context) {
            val manager = AppWidgetManager.getInstance(c)
            val ids = manager.getAppWidgetIds(ComponentName(c, PetWidget::class.java))
            if (ids.isNotEmpty()) ids.forEach { manager.updateAppWidget(it, views(c)) }
        }

        private fun views(c: Context): RemoteViews {
            val v = RemoteViews(c.packageName, R.layout.widget_pet)
            val open = PendingIntent.getActivity(c, 0, Intent(c, MainActivity::class.java), PendingIntent.FLAG_IMMUTABLE)
            v.setOnClickPendingIntent(R.id.widget_root, open)
            val profile = Pals.profile.value
            if (profile == null) {
                v.setImageViewBitmap(R.id.widget_pet, Sprites.bitmap(PetKind.CAT, 1, null))
                v.setTextViewText(R.id.widget_title, c.getString(R.string.app_name))
                v.setTextViewText(R.id.widget_message, c.getString(R.string.widget_adopt))
                return v
            }
            val care = Pals.care.value.at()
            v.setImageViewBitmap(R.id.widget_pet, Sprites.bitmap(profile.pet, care.emotion.frame, profile.accessory))
            v.setTextViewText(R.id.widget_title, "${profile.name} · ${profile.sign.symbol} ${c.getString(profile.sign.nameRes)}")
            v.setTextColor(R.id.widget_title, profile.pet.accent)
            val text = care.need?.let { c.getString(it.lineRes, profile.name) }
                ?: Messages.today(c, profile).substringBefore('\n')
            v.setTextViewText(R.id.widget_message, text)
            return v
        }
    }
}

package com.matsavin.pixelpals

import android.Manifest
import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.ZoneId

/**
 * The daily message and the "needs care" nudge. Unlike iOS, Android builds the notification
 * when the alarm fires, so the daily one always carries that day's message.
 */
object Reminders {
    private const val CHANNEL = "daily"
    private const val DAILY = 1
    private const val CARE = 2

    fun schedule(c: Context) {
        val alarms = c.getSystemService(AlarmManager::class.java)
        val daily = pending(c, DAILY)
        if (PetStore.flag(c, PetStore.REMINDER) && Pals.profile.value != null) {
            val minutes = PetStore.reminderMinutes(c)
            var next = LocalDate.now().atTime(minutes / 60, minutes % 60)
            if (next.isBefore(LocalDateTime.now())) next = next.plusDays(1)
            alarms.setInexactRepeating(AlarmManager.RTC_WAKEUP, millis(next), AlarmManager.INTERVAL_DAY, daily)
        } else {
            alarms.cancel(daily)
        }
        scheduleCareAlert(c)
    }

    /** One alarm for when the first care level runs low; replaced on every care change. */
    fun scheduleCareAlert(c: Context) {
        val alarms = c.getSystemService(AlarmManager::class.java)
        val care = pending(c, CARE)
        val next = Pals.care.value.nextNeed
        if (PetStore.flag(c, PetStore.CARE_ALERTS) && next != null) {
            alarms.set(AlarmManager.RTC, next.second, care)
        } else {
            alarms.cancel(care)
        }
    }

    fun sendNow(c: Context) = post(c, DAILY)

    fun post(c: Context, kind: Int) {
        Pals.load(c)
        val profile = Pals.profile.value ?: return
        if (Build.VERSION.SDK_INT >= 33 &&
            c.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
        ) return
        val manager = c.getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(NotificationChannel(CHANNEL, c.getString(R.string.channel_daily), NotificationManager.IMPORTANCE_DEFAULT))
        val (title, text) = if (kind == CARE) {
            val need = Pals.care.value.at().need ?: return
            c.getString(R.string.needs_you, profile.name) to c.getString(need.lineRes, profile.name)
        } else {
            "${profile.name} · ${profile.sign.symbol} ${c.getString(profile.sign.nameRes)}" to Messages.today(c, profile)
        }
        val open = PendingIntent.getActivity(c, 0, Intent(c, MainActivity::class.java), PendingIntent.FLAG_IMMUTABLE)
        val pet = Sprites.bitmap(profile.pet, 2, profile.accessory, 8)
        val notification = Notification.Builder(c, CHANNEL)
            .setSmallIcon(R.drawable.ic_pal)
            .setLargeIcon(pet)
            .setContentTitle(title)
            .setContentText(text)
            .setStyle(Notification.BigTextStyle().bigText(text))
            .setContentIntent(open)
            .setAutoCancel(true)
            .build()
        manager.notify(kind, notification)
    }

    private fun pending(c: Context, kind: Int) = PendingIntent.getBroadcast(
        c, kind, Intent(c, ReminderReceiver::class.java).putExtra("kind", kind),
        PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
    )

    private fun millis(time: LocalDateTime) = time.atZone(ZoneId.systemDefault()).toInstant().toEpochMilli()
}

class ReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        Reminders.post(context, intent.getIntExtra("kind", 1))
        PetWidget.updateAll(context)
    }
}

/** Restores alarms and the camera pill after a restart. */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_BOOT_COMPLETED) return
        Pals.load(context)
        Reminders.schedule(context)
        if (PetStore.flag(context, PetStore.OVERLAY)) IslandService.start(context)
    }
}

package com.matsavin.pixelpals

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject
import java.time.LocalDate
import java.time.MonthDay
import java.time.format.DateTimeFormatter
import java.time.format.FormatStyle
import java.time.temporal.ChronoUnit
import java.util.Locale

enum class ZodiacSign(val glyph: String, val nameRes: Int, val elementRes: Int, val elementSignRes: Int, val start: MonthDay, val end: MonthDay) {
    ARIES("♈", R.string.sign_aries, R.string.element_fire, R.string.element_fire_sign, MonthDay.of(3, 21), MonthDay.of(4, 19)),
    TAURUS("♉", R.string.sign_taurus, R.string.element_earth, R.string.element_earth_sign, MonthDay.of(4, 20), MonthDay.of(5, 20)),
    GEMINI("♊", R.string.sign_gemini, R.string.element_air, R.string.element_air_sign, MonthDay.of(5, 21), MonthDay.of(6, 20)),
    CANCER("♋", R.string.sign_cancer, R.string.element_water, R.string.element_water_sign, MonthDay.of(6, 21), MonthDay.of(7, 22)),
    LEO("♌", R.string.sign_leo, R.string.element_fire, R.string.element_fire_sign, MonthDay.of(7, 23), MonthDay.of(8, 22)),
    VIRGO("♍", R.string.sign_virgo, R.string.element_earth, R.string.element_earth_sign, MonthDay.of(8, 23), MonthDay.of(9, 22)),
    LIBRA("♎", R.string.sign_libra, R.string.element_air, R.string.element_air_sign, MonthDay.of(9, 23), MonthDay.of(10, 22)),
    SCORPIO("♏", R.string.sign_scorpio, R.string.element_water, R.string.element_water_sign, MonthDay.of(10, 23), MonthDay.of(11, 21)),
    SAGITTARIUS("♐", R.string.sign_sagittarius, R.string.element_fire, R.string.element_fire_sign, MonthDay.of(11, 22), MonthDay.of(12, 21)),
    CAPRICORN("♑", R.string.sign_capricorn, R.string.element_earth, R.string.element_earth_sign, MonthDay.of(12, 22), MonthDay.of(1, 19)),
    AQUARIUS("♒", R.string.sign_aquarius, R.string.element_air, R.string.element_air_sign, MonthDay.of(1, 20), MonthDay.of(2, 18)),
    PISCES("♓", R.string.sign_pisces, R.string.element_water, R.string.element_water_sign, MonthDay.of(2, 19), MonthDay.of(3, 20));

    /** Glyph forced to text style (U+FE0E), like the iOS app. */
    val symbol get() = glyph + "︎"

    val key get() = name.lowercase()

    fun dates(locale: Locale): String {
        val f = DateTimeFormatter.ofPattern("d MMM", locale)
        return "${start.atYear(2001).format(f)} – ${end.atYear(2001).format(f)}"
    }

    companion object {
        fun of(birthday: LocalDate): ZodiacSign {
            val md = birthday.monthValue * 100 + birthday.dayOfMonth
            return when (md) {
                in 321..419 -> ARIES
                in 420..520 -> TAURUS
                in 521..620 -> GEMINI
                in 621..722 -> CANCER
                in 723..822 -> LEO
                in 823..922 -> VIRGO
                in 923..1022 -> LIBRA
                in 1023..1121 -> SCORPIO
                in 1122..1221 -> SAGITTARIUS
                in 120..218 -> AQUARIUS
                in 219..320 -> PISCES
                else -> CAPRICORN
            }
        }
    }
}

/** What the daily message is: sign message, quote, horoscope, your own messages, or a daily mix. */
enum class DailyContent(val titleRes: Int) {
    SIGN(R.string.content_sign), QUOTE(R.string.content_quote), HOROSCOPE(R.string.content_horoscope),
    MINE(R.string.content_mine), MIX(R.string.content_mix);

    fun resolved(day: LocalDate, hasOwn: Boolean): DailyContent {
        if (this != MIX) return this
        val rotation = if (hasOwn) listOf(SIGN, QUOTE, HOROSCOPE, MINE) else listOf(SIGN, QUOTE, HOROSCOPE)
        return rotation[(dayNumber(day) % rotation.size).toInt()]
    }
}

/** Days since 0001-01-01, matching the iOS ordinality so both apps pick the same line on the same day. */
fun dayNumber(day: LocalDate): Long = ChronoUnit.DAYS.between(LocalDate.of(1, 1, 1), day) + 1

/** The message, quote and horoscope databases, loaded per language from assets/<lang>/. */
object Messages {
    private val cache = mutableMapOf<String, JSONObject>()
    private val quoteCache = mutableMapOf<String, JSONArray>()

    fun language(context: Context): String =
        if (context.resources.configuration.locales[0].language == "ru") "ru" else "en"

    private fun obj(context: Context, file: String): JSONObject {
        val lang = language(context)
        return cache.getOrPut("$lang/$file") { JSONObject(context.assets.open("$lang/$file").bufferedReader().readText()) }
    }

    fun signLines(context: Context, sign: ZodiacSign): List<String> =
        obj(context, "motivations.json").getJSONArray(sign.key).let { a -> List(a.length()) { a.getString(it) } }

    fun signMessage(context: Context, profile: Profile, day: LocalDate): String {
        val lines = signLines(context, profile.sign)
        if (lines.isEmpty()) return context.getString(R.string.fallback_message)
        val birthDay = profile.birthday.dayOfYear
        return lines[((dayNumber(day) + birthDay) % lines.size).toInt()]
    }

    fun quote(context: Context, profile: Profile, day: LocalDate): String? {
        val lang = language(context)
        val all = quoteCache.getOrPut(lang) { JSONArray(context.assets.open("$lang/quotes.json").bufferedReader().readText()) }
        if (all.length() == 0) return null
        val q = all.getJSONObject(((dayNumber(day) + profile.birthday.dayOfYear * 7) % all.length()).toInt())
        return "“${q.getString("text")}” — ${q.getString("author")}"
    }

    fun horoscope(context: Context, sign: ZodiacSign, day: LocalDate): String {
        val parts = obj(context, "horoscope.json")
        fun list(name: String) = parts.getJSONArray(name).let { a -> List(a.length()) { a.getString(it) } }
        val forecasts = list("forecasts")
        val advice = list("advice")
        val colors = list("colors")
        val d = dayNumber(day)
        val s = sign.ordinal
        val color = colors[((d * 5 + s * 7) % colors.size).toInt()]
        val number = ((d * 13 + s * 17) % 99 + 1).toString()
        val lucky = parts.getString("lucky").replaceFirst("%@", color).replaceFirst("%@", number)
        return "${forecasts[((d * 7 + s * 5) % forecasts.size).toInt()]} ${advice[((d * 11 + s * 3 + 4) % advice.size).toInt()]}\n$lucky"
    }

    /** Today's message in whichever form the user chose. */
    fun today(context: Context, profile: Profile, day: LocalDate = LocalDate.now()): String {
        val own = PetStore.customMessages(context)
        return when (PetStore.dailyContent(context).resolved(day, own.isNotEmpty())) {
            DailyContent.QUOTE -> quote(context, profile, day)
            DailyContent.HOROSCOPE -> horoscope(context, profile.sign, day)
            DailyContent.MINE -> own.takeIf { it.isNotEmpty() }?.let { it[(dayNumber(day) % it.size).toInt()] }
            else -> null
        } ?: signMessage(context, profile, day)
    }

    fun shortDate(context: Context, day: LocalDate = LocalDate.now()): String =
        day.format(DateTimeFormatter.ofLocalizedDate(FormatStyle.FULL).withLocale(context.resources.configuration.locales[0]))
}

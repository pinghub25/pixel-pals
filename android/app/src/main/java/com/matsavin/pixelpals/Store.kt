package com.matsavin.pixelpals

import android.content.Context
import android.content.SharedPreferences
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import org.json.JSONArray
import org.json.JSONObject
import java.time.LocalDate

data class Profile(val pet: PetKind, val name: String, val birthday: LocalDate, val accessory: Accessory? = null) {
    val sign get() = ZodiacSign.of(birthday)

    companion object {
        val sample = Profile(PetKind.CAT, PetKind.CAT.defaultName, LocalDate.of(2000, 8, 1))
    }
}

/** Everything is stored on the device, in one SharedPreferences file. */
object PetStore {
    private fun prefs(c: Context): SharedPreferences = c.getSharedPreferences("pixel_pals", Context.MODE_PRIVATE)

    fun profile(c: Context): Profile? = prefs(c).getString("profile", null)?.let {
        val o = JSONObject(it)
        Profile(
            PetKind.valueOf(o.getString("pet")),
            o.getString("name"),
            LocalDate.parse(o.getString("birthday")),
            o.optString("accessory").takeIf { a -> a.isNotEmpty() }?.let { a -> Accessory.valueOf(a) },
        )
    }

    fun saveProfile(c: Context, p: Profile) = prefs(c).edit().putString(
        "profile",
        JSONObject().put("pet", p.pet.name).put("name", p.name).put("birthday", p.birthday.toString())
            .put("accessory", p.accessory?.name ?: "").toString(),
    ).apply()

    fun care(c: Context): PetCare = prefs(c).getString("care", null)?.let {
        val o = JSONObject(it)
        PetCare(
            o.getDouble("food"), o.getDouble("fun"), o.getDouble("energy"), o.getLong("updated"),
            o.getInt("love"), o.getInt("streak"), o.getLong("lastVisitDay"), o.optLong("lastPatHeart"),
        )
    } ?: PetCare()

    fun saveCare(c: Context, care: PetCare) = prefs(c).edit().putString(
        "care",
        JSONObject().put("food", care.food).put("fun", care.fun_).put("energy", care.energy).put("updated", care.updated)
            .put("love", care.love).put("streak", care.streak).put("lastVisitDay", care.lastVisitDay)
            .put("lastPatHeart", care.lastPatHeart).toString(),
    ).apply()

    fun customMessages(c: Context): List<String> =
        prefs(c).getString("custom", null)?.let { JSONArray(it) }?.let { a -> List(a.length()) { a.getString(it) } } ?: emptyList()

    fun saveCustomMessages(c: Context, list: List<String>) = prefs(c).edit().putString("custom", JSONArray(list).toString()).apply()

    fun dailyContent(c: Context) = runCatching { DailyContent.valueOf(prefs(c).getString("content", "SIGN")!!) }.getOrDefault(DailyContent.SIGN)
    fun setDailyContent(c: Context, v: DailyContent) = prefs(c).edit().putString("content", v.name).apply()

    fun flag(c: Context, key: String, default: Boolean = false) = prefs(c).getBoolean(key, default)
    fun setFlag(c: Context, key: String, v: Boolean) = prefs(c).edit().putBoolean(key, v).apply()

    fun reminderMinutes(c: Context) = prefs(c).getInt("reminderMinutes", 9 * 60)
    fun setReminderMinutes(c: Context, v: Int) = prefs(c).edit().putInt("reminderMinutes", v).apply()

    const val OVERLAY = "overlayOn"
    const val REMINDER = "reminderOn"
    const val CARE_ALERTS = "careAlertsOn"
    const val APP_AWARE = "appAware"
}

/**
 * App-wide state. The screen, the camera pill and the widget all read it, and every change goes
 * through here so they stay in sync (the iOS PetModel's job).
 */
object Pals {
    private val _profile = MutableStateFlow<Profile?>(null)
    val profile: StateFlow<Profile?> = _profile.asStateFlow()

    private val _care = MutableStateFlow(PetCare())
    val care: StateFlow<PetCare> = _care.asStateFlow()

    /** A short reaction (love, excited…) the pill shows for a few seconds, with when it started. */
    private val _reaction = MutableStateFlow<Pair<PetEmotion, Long>?>(null)
    val reaction: StateFlow<Pair<PetEmotion, Long>?> = _reaction.asStateFlow()

    /** Bumped when settings that change what is shown (language, content, messages) change. */
    private val _revision = MutableStateFlow(0)
    val revision: StateFlow<Int> = _revision.asStateFlow()

    private var loaded = false

    fun load(c: Context) {
        if (loaded) return
        Sprites.load(c)
        _profile.value = PetStore.profile(c)
        _care.value = PetStore.care(c)
        loaded = true
    }

    fun save(c: Context, p: Profile) {
        if (_profile.value == null) setCare(c, PetCare())
        _profile.value = p
        PetStore.saveProfile(c, p)
        refresh(c)
    }

    fun wear(c: Context, accessory: Accessory?) {
        val p = _profile.value ?: return
        if (accessory != null && _care.value.love < accessory.hearts) return
        save(c, p.copy(accessory = accessory))
    }

    /** On launch and whenever the app comes back: new day, new message, streak, reminders. */
    fun refresh(c: Context) {
        setCare(c, _care.value.at().checkIn())
        _revision.value++
        Reminders.schedule(c)
        PetWidget.updateAll(c)
    }

    fun perform(c: Context, action: PetAction) {
        setCare(c, _care.value.at().apply(action))
        _reaction.value = action.reaction to System.currentTimeMillis()
        if (action != PetAction.PAT) PetWidget.updateAll(c)
        Reminders.scheduleCareAlert(c)
    }

    fun react(emotion: PetEmotion) {
        _reaction.value = emotion to System.currentTimeMillis()
    }

    fun settingsChanged(c: Context) {
        _revision.value++
        Reminders.schedule(c)
        PetWidget.updateAll(c)
    }

    private fun setCare(c: Context, care: PetCare) {
        _care.value = care
        PetStore.saveCare(c, care)
    }
}

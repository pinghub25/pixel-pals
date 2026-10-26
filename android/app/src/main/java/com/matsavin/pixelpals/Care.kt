package com.matsavin.pixelpals

import java.time.LocalDate
import kotlin.math.max
import kotlin.math.min

/**
 * Tamagotchi-style needs, as in the iOS PetCare. Each level is 0..1 and drains per hour,
 * so the state can be projected to any moment.
 */
data class PetCare(
    val food: Double = 0.8,
    val fun_: Double = 0.8,
    val energy: Double = 0.8,
    val updated: Long = System.currentTimeMillis(),
    val love: Int = 0,
    val streak: Int = 0,
    val lastVisitDay: Long = 0,
    val lastPatHeart: Long = 0,
) {
    fun at(time: Long = System.currentTimeMillis()): PetCare {
        val hours = max(0.0, (time - updated) / 3_600_000.0)
        return copy(
            food = max(0.0, food - hours * DRAIN_FOOD),
            fun_ = max(0.0, fun_ - hours * DRAIN_FUN),
            energy = max(0.0, energy - hours * DRAIN_ENERGY),
            updated = time,
        )
    }

    val need: PetNeed?
        get() = listOf(PetNeed.FOOD to food, PetNeed.PLAY to fun_, PetNeed.REST to energy)
            .minBy { it.second }.takeIf { it.second < LOW }?.first

    val emotion: PetEmotion
        get() {
            val levels = listOf(food, fun_, energy)
            if (levels.count { it < LOW } >= 2 || levels.min() < 0.1) return PetEmotion.SAD
            return when (need) {
                PetNeed.FOOD -> PetEmotion.HUNGRY
                PetNeed.PLAY -> PetEmotion.BORED
                PetNeed.REST -> PetEmotion.SLEEPY
                null -> if (levels.min() > 0.6) PetEmotion.HAPPY else PetEmotion.CONTENT
            }
        }

    /** When the first level drops below the low mark, for the "needs care" reminder. */
    val nextNeed: Pair<PetNeed, Long>?
        get() = listOf(Triple(PetNeed.FOOD, food, DRAIN_FOOD), Triple(PetNeed.PLAY, fun_, DRAIN_FUN), Triple(PetNeed.REST, energy, DRAIN_ENERGY))
            .filter { it.second > LOW }
            .map { it.first to updated + ((it.second - LOW) / it.third * 3_600_000).toLong() }
            .minByOrNull { it.second }

    fun apply(action: PetAction, now: Long = System.currentTimeMillis()): PetCare = when (action) {
        PetAction.FEED -> copy(food = min(1.0, food + 0.35), love = love + 1)
        PetAction.PLAY -> copy(fun_ = min(1.0, fun_ + 0.35), energy = max(0.0, energy - 0.1), food = max(0.0, food - 0.05), love = love + 2)
        PetAction.NAP -> copy(energy = min(1.0, energy + 0.45))
        // Pats give a heart at most every few seconds, so the crown can't be farmed by tapping.
        PetAction.PAT -> if (now - lastPatHeart > 5_000) copy(fun_ = min(1.0, fun_ + 0.03), love = love + 1, lastPatHeart = now)
        else copy(fun_ = min(1.0, fun_ + 0.03))
    }

    /** Counts consecutive days the app was opened. */
    fun checkIn(day: LocalDate = LocalDate.now()): PetCare {
        val today = dayNumber(day)
        if (lastVisitDay == today) return this
        return copy(streak = if (lastVisitDay == today - 1) streak + 1 else 1, lastVisitDay = today)
    }

    companion object {
        const val LOW = 0.3
        private const val DRAIN_FOOD = 0.04
        private const val DRAIN_FUN = 0.05
        private const val DRAIN_ENERGY = 0.03
    }
}

enum class PetNeed(val lineRes: Int) {
    FOOD(R.string.need_food), PLAY(R.string.need_play), REST(R.string.need_rest)
}

/** Moods from care levels, plus short reactions. Frames: 0 idle, 1 eyes closed, 2 big smile, 3 sad. */
enum class PetEmotion(val frame: Int, val lineRes: Int) {
    HAPPY(2, R.string.mood_happy),
    CONTENT(0, R.string.mood_content),
    HUNGRY(0, R.string.need_food),
    BORED(0, R.string.need_play),
    SLEEPY(1, R.string.need_rest),
    SAD(3, R.string.mood_sad),
    LOVE(2, R.string.mood_love),
    EXCITED(2, R.string.mood_excited),
}

enum class PetAction(val reaction: PetEmotion) {
    FEED(PetEmotion.LOVE), PLAY(PetEmotion.EXCITED), NAP(PetEmotion.SLEEPY), PAT(PetEmotion.LOVE)
}

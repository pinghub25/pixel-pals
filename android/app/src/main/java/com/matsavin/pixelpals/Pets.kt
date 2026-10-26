package com.matsavin.pixelpals

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import org.json.JSONObject

/** The eight pals. Sprites come from assets/pets.json, exported from the iOS app's Pets.swift. */
enum class PetKind(
    val defaultName: String,
    val speciesRes: Int,
    /** Accent colour used around the UI (the body colour, except the penguin's lighter blue). */
    val accent: Int,
    private val body: Int,
    private val shade: Int,
    private val belly: Int,
    private val extra: Int = rgb(255, 158, 51),
) {
    CAT("Mochi", R.string.species_cat, rgb(255, 184, 107), rgb(255, 184, 107), rgb(217, 128, 64), rgb(255, 237, 209)),
    DOG("Kuma", R.string.species_dog, rgb(237, 158, 82), rgb(237, 158, 82), rgb(191, 107, 51), rgb(255, 242, 219)),
    BUNNY("Puff", R.string.species_bunny, rgb(247, 245, 250), rgb(247, 245, 250), rgb(204, 199, 217), rgb(255, 224, 235)),
    FROG("Pip", R.string.species_frog, rgb(115, 209, 107), rgb(115, 209, 107), rgb(71, 148, 69), rgb(204, 242, 153)),
    GHOST("Boo", R.string.species_ghost, rgb(240, 237, 255), rgb(240, 237, 255), rgb(184, 179, 224), rgb(255, 255, 255)),
    PENGUIN("Waddle", R.string.species_penguin, rgb(115, 153, 242), rgb(56, 69, 107), rgb(38, 46, 77), rgb(255, 255, 255)),
    AXOLOTL("Lolo", R.string.species_axolotl, rgb(255, 184, 209), rgb(255, 184, 209), rgb(230, 128, 166), rgb(255, 224, 235), rgb(242, 97, 148)),
    DINO("Rexie", R.string.species_dino, rgb(128, 204, 115), rgb(128, 204, 115), rgb(247, 148, 77), rgb(224, 245, 158));

    fun color(code: Char): Int? = when (code) {
        'K', 'E' -> rgb(20, 20, 31)
        'W' -> Color.WHITE
        'P' -> rgb(255, 140, 166)
        'R' -> rgb(242, 89, 107)
        'T' -> rgb(115, 191, 255)
        'M' -> rgb(242, 89, 153)
        'Y' -> rgb(255, 209, 51)
        'V' -> rgb(89, 140, 255)
        'B' -> body
        'D' -> shade
        'L' -> belly
        'O', 'G' -> extra
        else -> null
    }

    val key get() = name.lowercase()
}

/** Unlocked with friendship hearts; worn everywhere the pal is drawn. */
enum class Accessory(val hearts: Int, val titleRes: Int) {
    BOW(10, R.string.accessory_bow),
    SUNGLASSES(25, R.string.accessory_sunglasses),
    PARTY_HAT(50, R.string.accessory_party_hat),
    CROWN(100, R.string.accessory_crown),
}

/** Frames: 0 idle, 1 eyes closed, 2 happy, 3 sad — the same rules as the iOS app. */
object Sprites {
    private class Art(val base: List<String>, val blink: Map<Int, String>, val happy: Map<Int, String>)

    private var art: Map<PetKind, Art> = emptyMap()

    fun load(context: Context) {
        if (art.isNotEmpty()) return
        val json = JSONObject(context.assets.open("pets.json").bufferedReader().readText())
        art = PetKind.entries.associateWith { kind ->
            val pet = json.getJSONObject(kind.key)
            val base = pet.getJSONArray("base").let { rows -> List(rows.length()) { rows.getString(it) } }
            fun overrides(name: String) = pet.getJSONObject(name).let { o -> o.keys().asSequence().associate { it.toInt() to o.getString(it) } }
            Art(base, overrides("blink"), overrides("happy"))
        }
    }

    // Where each pet's smile and eyes are: (smile top row, corners, bottom row, middle, tear row/col).
    private val faces = mapOf(
        PetKind.CAT to Face(9, listOf(6, 9), 10, listOf(7, 8), 9 to 4),
        PetKind.DOG to Face(10, listOf(6, 9), 11, listOf(7, 8), 9 to 3),
        PetKind.BUNNY to Face(11, listOf(6, 9), 12, listOf(7, 8), 10 to 4),
        PetKind.FROG to Face(9, listOf(3, 12), 10, (4..11).toList(), 5 to 2),
        PetKind.GHOST to Face(8, listOf(6, 9), 9, listOf(7, 8), 7 to 4),
        PetKind.PENGUIN to Face(0, emptyList(), 0, emptyList(), 6 to 5),
        PetKind.AXOLOTL to Face(9, listOf(6, 9), 10, listOf(7, 8), 9 to 4),
        PetKind.DINO to Face(8, listOf(5, 10), 9, (6..9).toList(), 7 to 4),
    )

    // Top of the head and the eyes (row, left pupil, right pupil), for accessories.
    private val anchors = mapOf(
        PetKind.CAT to Anchor(4, 7, 4, 10), PetKind.DOG to Anchor(4, 7, 3, 11),
        PetKind.BUNNY to Anchor(5, 8, 4, 10), PetKind.FROG to Anchor(4, 3, 3, 11),
        PetKind.GHOST to Anchor(0, 5, 4, 10), PetKind.PENGUIN to Anchor(1, 4, 5, 10),
        PetKind.AXOLOTL to Anchor(3, 7, 4, 10), PetKind.DINO to Anchor(2, 5, 4, 10),
    )

    private data class Face(val top: Int, val corners: List<Int>, val bottom: Int, val middle: List<Int>, val tear: Pair<Int, Int>)
    private data class Anchor(val headTop: Int, val eyeRow: Int, val leftEye: Int, val rightEye: Int)

    fun rows(kind: PetKind, frame: Int, accessory: Accessory? = null): Array<CharArray> {
        val a = art.getValue(kind)
        val grid = Array(16) { a.base[it].toCharArray() }
        val overrides = when (frame) {
            1 -> a.blink
            2 -> a.happy
            else -> emptyMap()
        }
        for ((row, line) in overrides) grid[row] = line.toCharArray()
        if (frame == 3) makeSad(kind, grid)
        if (accessory != null) wear(kind, accessory, grid)
        return grid
    }

    private fun makeSad(kind: PetKind, g: Array<CharArray>) {
        val f = faces.getValue(kind)
        fun fill(r: Int, c: Int) = if (g[r][c - 1] != 'K') g[r][c - 1] else g[r][c + 1]
        if (f.corners.isNotEmpty()) {
            for (c in f.corners) g[f.top][c] = fill(f.top, c)
            for (c in f.middle) g[f.bottom][c] = fill(f.bottom, c)
            for (c in f.middle) g[f.top][c] = 'K'
            for (c in f.corners) g[f.bottom][c] = 'K'
        }
        g[f.tear.first][f.tear.second] = 'T'
    }

    private fun wear(kind: PetKind, accessory: Accessory, g: Array<CharArray>) {
        val a = anchors.getValue(kind)
        fun stamp(sprite: List<String>, row: Int, col: Int) {
            sprite.forEachIndexed { dy, line ->
                line.forEachIndexed { dx, code ->
                    val y = row + dy
                    val x = col + dx
                    if (code != '.' && y in 0..15 && x in 0..15) g[y][x] = code
                }
            }
        }
        when (accessory) {
            Accessory.BOW -> stamp(listOf("MM.MM", ".MRM.", "MM.MM"), maxOf(0, a.headTop - 2), 10)
            Accessory.PARTY_HAT -> stamp(listOf("..W..", "..V..", ".VYV.", "VYVYV"), maxOf(0, a.headTop - 3), 5)
            Accessory.CROWN -> stamp(listOf("Y.YY.Y", "YYYYYY", "YRYYRY"), maxOf(0, a.headTop - 2), 5)
            Accessory.SUNGLASSES -> {
                for (eye in listOf(a.leftEye, a.rightEye)) {
                    stamp(listOf("KKKK", "KKKK"), a.eyeRow, eye - 1)
                    g[a.eyeRow][eye] = 'W'
                }
                for (c in (a.leftEye + 3) until (a.rightEye - 1)) g[a.eyeRow][c] = 'K'
            }
        }
    }

    private val paint = Paint().apply { isAntiAlias = false }

    /** Draws a pal as crisp pixels into a square of [size] at ([left], [top]). */
    fun draw(canvas: Canvas, kind: PetKind, frame: Int, accessory: Accessory?, left: Float, top: Float, size: Float) {
        val px = size / 16f
        rows(kind, frame, accessory).forEachIndexed { y, row ->
            row.forEachIndexed { x, code ->
                val color = kind.color(code) ?: return@forEachIndexed
                paint.color = color
                canvas.drawRect(left + x * px, top + y * px, left + (x + 1) * px + 0.5f, top + (y + 1) * px + 0.5f, paint)
            }
        }
    }

    fun bitmap(kind: PetKind, frame: Int, accessory: Accessory?, scale: Int = 12): Bitmap {
        val bmp = Bitmap.createBitmap(16 * scale, 16 * scale, Bitmap.Config.ARGB_8888)
        draw(Canvas(bmp), kind, frame, accessory, 0f, 0f, 16f * scale)
        return bmp
    }
}

fun rgb(r: Int, g: Int, b: Int) = Color.rgb(r, g, b)

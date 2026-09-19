package com.adenzia.layla

/**
 * The nine colour sets, as the widgets draw them.
 *
 * Generated from `ios/NoorWidgets/NoorTheme.swift`, which is the same table
 * `lib/features/widgets/domain/widget_theme.dart` mirrors, so a stone tapped
 * on either phone produces the same widget. The ids must match those two.
 *
 * Android cannot build a rounded, outlined shape at runtime into a
 * RemoteViews, so each set ships as three tiny drawables — the ground, a
 * resting cell, and the lit one — and the painter chooses by name.
 */
internal data class Palette(
    val background: Int,
    val cell: Int,
    val cellNext: Int,
    val gold: Int,
    val goldDim: Int,
    val cream: Int,
) {
    /**
     * Secondary and tertiary text: the ink itself, thinned, exactly as iOS
     * draws it (`Layl.mist` is `cream.opacity(0.7)`).
     *
     * This was a stored colour for a while, taken from the set's hairline,
     * and on the eight dark sets it passed for merely dim. Sand is the set
     * that inverts — bone ground, dark brown ink — and its hairline is a pale
     * beige, so every prayer name, the city, the footer and the countdown
     * itself were light-on-light and simply gone. Derived from the ink, a set
     * that inverts inverts its quiet text along with it.
     */
    val mist: Int get() = thinned(0xB3)
    val mistFaint: Int get() = thinned(0x73)

    private fun thinned(alpha: Int): Int =
        (alpha shl 24) or (cream and 0x00FFFFFF)
}

internal object WidgetPalettes {
    private val byName: Map<String, Palette> = mapOf(
        "midnight" to Palette(
            background = R.drawable.widget_bg_midnight,
            cell = R.drawable.widget_cell_midnight,
            cellNext = R.drawable.widget_cell_next_midnight,
            gold = 0xFFE2B96A.toInt(),
            goldDim = 0xFF937845.toInt(),
            cream = 0xFFF6F1E7.toInt(),
        ),
        "emerald" to Palette(
            background = R.drawable.widget_bg_emerald,
            cell = R.drawable.widget_cell_emerald,
            cellNext = R.drawable.widget_cell_next_emerald,
            gold = 0xFF8CF0C4.toInt(),
            goldDim = 0xFF5B9C80.toInt(),
            cream = 0xFFEFFAF4.toInt(),
        ),
        "rose" to Palette(
            background = R.drawable.widget_bg_rose,
            cell = R.drawable.widget_cell_rose,
            cellNext = R.drawable.widget_cell_next_rose,
            gold = 0xFFFF9CC6.toInt(),
            goldDim = 0xFFA66581.toInt(),
            cream = 0xFFFFF0F6.toInt(),
        ),
        "ember" to Palette(
            background = R.drawable.widget_bg_ember,
            cell = R.drawable.widget_cell_ember,
            cellNext = R.drawable.widget_cell_next_ember,
            gold = 0xFFFFB37A.toInt(),
            goldDim = 0xFFA6744F.toInt(),
            cream = 0xFFFFF3EA.toInt(),
        ),
        "violet" to Palette(
            background = R.drawable.widget_bg_violet,
            cell = R.drawable.widget_cell_violet,
            cellNext = R.drawable.widget_cell_next_violet,
            gold = 0xFFC9B4FF.toInt(),
            goldDim = 0xFF8375A6.toInt(),
            cream = 0xFFF5F1FF.toInt(),
        ),
        "ocean" to Palette(
            background = R.drawable.widget_bg_ocean,
            cell = R.drawable.widget_cell_ocean,
            cellNext = R.drawable.widget_cell_next_ocean,
            gold = 0xFF7FE3FF.toInt(),
            goldDim = 0xFF5394A6.toInt(),
            cream = 0xFFEEF9FD.toInt(),
        ),
        "sapphire" to Palette(
            background = R.drawable.widget_bg_sapphire,
            cell = R.drawable.widget_cell_sapphire,
            cellNext = R.drawable.widget_cell_next_sapphire,
            gold = 0xFFA9C8FF.toInt(),
            goldDim = 0xFF6E82A6.toInt(),
            cream = 0xFFF1F5FF.toInt(),
        ),
        "slate" to Palette(
            background = R.drawable.widget_bg_slate,
            cell = R.drawable.widget_cell_slate,
            cellNext = R.drawable.widget_cell_next_slate,
            gold = 0xFFE3E6EE.toInt(),
            goldDim = 0xFF94959B.toInt(),
            cream = 0xFFF6F6F8.toInt(),
        ),
        "sand" to Palette(
            background = R.drawable.widget_bg_sand,
            cell = R.drawable.widget_cell_sand,
            cellNext = R.drawable.widget_cell_next_sand,
            gold = 0xFF8C5A1E.toInt(),
            goldDim = 0xFFB4946D.toInt(),
            cream = 0xFF2A1B0A.toInt(),
        ),
    )

    /** Falls back to Midnight, which is the app's own colours. */
    fun named(id: String?): Palette =
        byName[id?.lowercase()] ?: byName.getValue("midnight")
}

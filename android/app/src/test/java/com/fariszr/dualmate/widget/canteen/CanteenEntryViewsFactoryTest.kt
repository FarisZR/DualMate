package com.fariszr.dualmate.widget.canteen

import com.fariszr.dualmate.model.CanteenEntry
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import org.threeten.bp.LocalDate

class CanteenEntryViewsFactoryTest {
    @Test
    fun deduplicateEntries_removesExactDuplicates_preservesOrder() {
        val date = LocalDate.of(2026, 1, 27)
        val first = CanteenEntry(1, date, "Pasta", "Main", 4.5, listOf("vegetarian"))
        val duplicate = CanteenEntry(2, date, "Pasta ", " main", 4.5, listOf("vegetarian"))
        val second = CanteenEntry(3, date, "Salad", "Side", 3.0, listOf("healthy"))

        val deduped = CanteenEntryViewsFactory.deduplicateEntries(listOf(first, duplicate, second))

        assertEquals(2, deduped.size)
        assertEquals(first.name, deduped[0].name)
        assertEquals(second.name, deduped[1].name)
    }

    @Test
    fun isMainMeal_acceptsLegacyAndDhbwAppMainCategories() {
        val date = LocalDate.of(2026, 8, 19)

        assertTrue(CanteenEntryViewsFactory.isMainMeal(entry(date, "Wahlessen 1")))
        assertTrue(CanteenEntryViewsFactory.isMainMeal(entry(date, "Wahlessen 2")))
        assertTrue(CanteenEntryViewsFactory.isMainMeal(entry(date, "main")))
        assertTrue(CanteenEntryViewsFactory.isMainMeal(entry(date, "Hauptgericht")))
        assertFalse(CanteenEntryViewsFactory.isMainMeal(entry(date, "side")))
    }

    private fun entry(date: LocalDate, category: String) =
        CanteenEntry(1, date, "Meal", category, 4.5, emptyList())
}

package com.fariszr.dualmate.widget.canteen

import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import com.fariszr.dualmate.R
import com.fariszr.dualmate.database.CanteenProvider
import com.fariszr.dualmate.model.CanteenEntry
import com.fariszr.dualmate.widget.MultiDayViewsFactory
import com.fariszr.dualmate.widget.MultiDayWidgetHelper
import com.fariszr.dualmate.widget.WidgetItemState
import com.fariszr.dualmate.widget.WidgetNavigationExtras
import org.threeten.bp.LocalDate
import org.threeten.bp.LocalDateTime
import org.threeten.bp.OffsetDateTime
import org.threeten.bp.format.DateTimeFormatter
import java.text.NumberFormat
import java.util.Currency
import java.util.Locale

class CanteenEntryViewsFactory(
    context: Context,
    appWidgetId: Int
) : MultiDayViewsFactory<CanteenEntry>(context, appWidgetId, ROW_METRICS) {

    private val dayFormatter = DateTimeFormatter.ofPattern("EEE", Locale.getDefault())
    private val dateFormatter = DateTimeFormatter.ofPattern("d MMM", Locale.getDefault())
    private val zoneOffset = OffsetDateTime.now().offset
    private val priceFormatter = NumberFormat.getCurrencyInstance(Locale.GERMANY).apply {
        currency = Currency.getInstance("EUR")
        maximumFractionDigits = 2
        minimumFractionDigits = 2
    }

    override fun getRowLayoutId(): Int {
        return R.layout.widget_day_row
    }

    override fun getRowItemsContainerId(): Int {
        return R.id.day_items_container
    }

    override fun bindDayHeader(views: RemoteViews, date: LocalDate, isToday: Boolean) {
        views.setTextViewText(R.id.day_label, dayFormatter.format(date))
        views.setTextViewText(R.id.date_label, dateFormatter.format(date))
        val dayStartMillis = date.atStartOfDay().toEpochSecond(zoneOffset) * 1000
        val dayIntent = Intent().putExtra(WidgetNavigationExtras.canteenDayStart, dayStartMillis)
        views.setOnClickFillInIntent(R.id.day_header_container, dayIntent)
        views.setOnClickFillInIntent(R.id.day_items_container, dayIntent)
    }

    override fun buildItemView(item: CanteenEntry, state: WidgetItemState): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_canteen_day_item)

        views.setTextViewText(R.id.text_view_meal_title, item.name)
        views.setTextViewText(R.id.text_view_meal_price, priceFormatter.format(item.price))
        views.setTextViewText(R.id.text_view_meal_emoji, mapEmojis(item.mealTypes))

        return views
    }

    override fun buildOverflowView(date: LocalDate, overflowCount: Int): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_day_message_item)
        views.setTextViewText(
            R.id.day_message_text,
            context.getString(R.string.widget_canteen_overflow, overflowCount)
        )
        val dayStartMillis = date.atStartOfDay().toEpochSecond(zoneOffset) * 1000
        views.setOnClickFillInIntent(
            R.id.day_message_text,
            Intent().putExtra(WidgetNavigationExtras.canteenDayStart, dayStartMillis)
        )
        return views
    }

    override fun buildEmptyView(isToday: Boolean, isDataUnavailable: Boolean): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_day_message_item)
        views.setTextViewText(R.id.day_message_text, context.getString(R.string.widget_canteen_empty_state))
        return views
    }

    override fun getItemState(item: CanteenEntry, now: LocalDateTime): WidgetItemState {
        return WidgetItemState.FUTURE
    }

    override fun loadItemsForWeek(
        startDate: LocalDate,
        endDate: LocalDate
    ): MultiDayWidgetHelper.LoadResult<CanteenEntry> {
        val entries = CanteenProvider(context).queryMealsForWeek(startDate, endDate)
        val distinctEntries = deduplicateEntries(entries)

        return MultiDayWidgetHelper.LoadResult(
            distinctEntries.groupBy { entry -> entry.date },
            true
        )
    }

    override fun prepareVisibleItems(
        items: List<CanteenEntry>
    ): MultiDayWidgetHelper.VisibleItems<CanteenEntry> {
        val mainMeals = items.filter { entry -> isMainMeal(entry) }
        val hiddenCount = items.size - mainMeals.size
        return MultiDayWidgetHelper.VisibleItems(mainMeals, hiddenCount)
    }

    private fun isMainMeal(entry: CanteenEntry): Boolean {
        val normalized = entry.category.trim().lowercase(Locale.getDefault())
        val match = Regex("wahl?essen\\s*(\\d)").find(normalized)
        val choice = match?.groupValues?.getOrNull(1)
        return choice == "1" || choice == "2"
    }

    private fun mapEmojis(mealTypes: List<String>): String {
        val emojis = mealTypes.mapNotNull { type ->
            when (type) {
                "vegan" -> "🌱"
                "vegetarian" -> "🥬"
                "pork" -> "🐷"
                "beef" -> "🐄"
                "poultry" -> "🍗"
                "fish" -> "🐟"
                "healthy" -> "💪"
                else -> null
            }
        }

        val emojiText = emojis.distinct().joinToString(" ")
        return if (emojiText.isBlank()) "🍽️" else emojiText
    }

    companion object {
        private val ROW_METRICS = MultiDayWidgetHelper.RowMetrics(
            headerHeightDp = 0,
            rowVerticalPaddingDp = 12,
            dateColumnMinHeightDp = 36,
            itemHeightDp = 20,
            maxItemsPerRow = 4
        )

        internal fun deduplicateEntries(entries: List<CanteenEntry>): List<CanteenEntry> {
            return entries.distinctBy { entry ->
                listOf(
                    entry.date,
                    entry.category.trim().lowercase(Locale.getDefault()),
                    entry.name.trim().lowercase(Locale.getDefault()),
                    entry.price
                )
            }
        }
    }
}

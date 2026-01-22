package de.bennik2000.dhbwstudentapp.widget.canteen

import android.content.Context
import android.widget.AdapterView
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import de.bennik2000.dhbwstudentapp.R
import de.bennik2000.dhbwstudentapp.database.CanteenProvider
import de.bennik2000.dhbwstudentapp.model.CanteenEntry
import org.threeten.bp.LocalDate
import java.text.NumberFormat
import java.util.Currency
import java.util.Locale

class CanteenEntryViewsFactory(private val context: Context) : RemoteViewsService.RemoteViewsFactory {

    private var entries: ArrayList<CanteenEntry> = ArrayList()
    private val priceFormatter = NumberFormat.getCurrencyInstance(Locale.GERMANY).apply {
        currency = Currency.getInstance("EUR")
        maximumFractionDigits = 2
        minimumFractionDigits = 2
    }

    override fun onCreate() {
        loadMealsForToday()
    }

    override fun getLoadingView(): RemoteViews? {
        return null
    }

    override fun getItemId(position: Int): Long {
        return entries[position].id.toLong()
    }

    override fun onDataSetChanged() {
        loadMealsForToday()
    }

    override fun hasStableIds(): Boolean {
        return true
    }

    override fun getViewAt(position: Int): RemoteViews? {
        if (position == AdapterView.INVALID_POSITION || position >= entries.size) {
            return null
        }

        val entry = entries[position]
        val rv = RemoteViews(context.packageName, R.layout.widget_canteen_entry_list_item)

        rv.setTextViewText(R.id.text_view_meal_title, entry.name)
        rv.setTextViewText(R.id.text_view_meal_category, entry.category)
        rv.setTextViewText(R.id.text_view_meal_price, priceFormatter.format(entry.price))
        rv.setTextViewText(R.id.text_view_meal_emoji, mapEmojis(entry.mealTypes))

        return rv
    }

    override fun getCount(): Int {
        return entries.size
    }

    override fun getViewTypeCount(): Int {
        return 1
    }

    override fun onDestroy() {
    }

    private fun loadMealsForToday() {
        entries = CanteenProvider(context).queryMealsForDay(LocalDate.now())
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
}

package com.fariszr.dualmate.database

import android.content.Context
import android.database.Cursor
import android.database.sqlite.SQLiteDatabase
import android.util.Log
import com.fariszr.dualmate.model.CanteenEntry
import io.flutter.util.PathUtils
import org.threeten.bp.LocalDate
import org.threeten.bp.LocalDateTime
import org.threeten.bp.OffsetDateTime
import java.io.File

class CanteenProvider(private val context: Context) {

    private val zoneOffset = OffsetDateTime.now().offset

    data class QueryResult(
        val entries: ArrayList<CanteenEntry>,
        val successful: Boolean
    )

    fun hasMealsForDay(date: LocalDate): Boolean {
        val start = date.atStartOfDay()
        val end = date.plusDays(1).atStartOfDay()

        return hasMealsBetween(start.toEpochSecond(zoneOffset) * 1000, end.toEpochSecond(zoneOffset) * 1000)
    }

    fun queryMealsForDay(date: LocalDate): ArrayList<CanteenEntry> {
        val startMillis = date.atStartOfDay().toEpochSecond(zoneOffset) * 1000
        val endMillis = date.plusDays(1).atStartOfDay().toEpochSecond(zoneOffset) * 1000

        return queryMealsBetween(startMillis, endMillis).entries
    }

    fun queryMealsForWeek(startDate: LocalDate, endDate: LocalDate): QueryResult {
        val startMillis = startDate.atStartOfDay().toEpochSecond(zoneOffset) * 1000
        val endMillis = endDate.plusDays(1).atStartOfDay().toEpochSecond(zoneOffset) * 1000

        return queryMealsBetween(startMillis, endMillis)
    }

    private fun hasMealsBetween(startMillis: Long, endMillis: Long): Boolean {
        try {
            openDatabase()?.use { database ->
                database.rawQuery(
                    CANTEEN_ENTRIES_BETWEEN_SQL,
                    arrayOf(startMillis.toString(), endMillis.toString())
                ).use { result ->
                    return result.count > 0
                }
            }
        } catch (ex: Exception) {
        }

        return false
    }

    private fun queryMealsBetween(startMillis: Long, endMillis: Long): QueryResult {
        try {
            openDatabase()?.use { database ->
                database.rawQuery(
                    CANTEEN_ENTRIES_BETWEEN_SQL,
                    arrayOf(startMillis.toString(), endMillis.toString())
                ).use { result ->
                    return QueryResult(readMeals(result), true)
                }
            }
        } catch (ex: Exception) {
            Log.w("CanteenProvider", "queryMealsBetween failed", ex)
        }

        return QueryResult(ArrayList(), false)
    }

    private fun openDatabase(): SQLiteDatabase? {
        val dataDir = PathUtils.getDataDirectory(context)
        val candidatePaths = listOf(
            "$dataDir/app_flutter/Database.db",
            "$dataDir/Database.db",
            "$dataDir/databases/Database.db"
        )

        for (path in candidatePaths) {
            if (!File(path).exists()) {
                continue
            }

            try {
                return SQLiteDatabase
                    .openDatabase(path, null, SQLiteDatabase.OPEN_READONLY)
            } catch (e: Exception) {
            }
        }

        return null
    }

    private fun readMeals(result: Cursor): ArrayList<CanteenEntry> {
        val entries: ArrayList<CanteenEntry> = ArrayList()

        while (result.moveToNext()) {
            entries.add(readMeal(result))
        }

        return entries
    }

    private fun readMeal(result: Cursor): CanteenEntry {
        val dateMillis = result.getLong(result.getColumnIndex("date"))
        val date = LocalDateTime.ofEpochSecond(dateMillis / 1000, 0, zoneOffset).toLocalDate()
        val types = result.getString(result.getColumnIndex("meal_types"))
        val mealTypes = types
            ?.split(",")
            ?.map { it.trim() }
            ?.filter { it.isNotEmpty() }
            ?: emptyList()

        return CanteenEntry(
            result.getInt(result.getColumnIndex("id")),
            date,
            result.getString(result.getColumnIndex("name")),
            result.getString(result.getColumnIndex("category")),
            result.getDouble(result.getColumnIndex("price")),
            mealTypes
        )
    }

    companion object {
        private const val CANTEEN_ENTRIES_BETWEEN_SQL =
            "SELECT  \n" +
                "canteen_meals.id,\n" +
                "canteen_meals.date,\n" +
                "canteen_meals.name,\n" +
                "canteen_meals.category,\n" +
                "canteen_meals.price,\n" +
                "canteen_meals.meal_types\n" +
                "FROM \n" +
                "    canteen_meals\n" +
                "WHERE date >= ? AND date < ?\n" +
                "ORDER BY date ASC, category ASC, name ASC;\n"
    }
}

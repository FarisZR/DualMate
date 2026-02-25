package com.fariszr.dualmate.database

import android.content.Context
import android.database.Cursor
import android.database.sqlite.SQLiteDatabase
import android.util.Log
import com.fariszr.dualmate.model.ScheduleEntry
import io.flutter.util.PathUtils
import org.threeten.bp.LocalDate
import org.threeten.bp.LocalDateTime
import org.threeten.bp.OffsetDateTime
import java.io.File


class ScheduleProvider(private val context: Context) {

    private val zoneOffset = OffsetDateTime.now().offset

    data class QueryResult(
        val entries: ArrayList<ScheduleEntry>,
        val successful: Boolean
    )

    
    fun hasScheduleEntriesForDay(date: LocalDate): Boolean {
        val start = date.atStartOfDay()
        val end = date.plusDays(1).atStartOfDay()
        
        return hasScheduleEntriesBetween(start, end)
    }

    fun hasScheduleEntriesBetween(start: LocalDateTime, end: LocalDateTime): Boolean {
        try {
            openDatabase()?.use { database ->
                val startMillis = start.toEpochSecond(zoneOffset) * 1000
                val endMillis = end.toEpochSecond(zoneOffset) * 1000

                database.rawQuery(
                        SCHEDULE_ENTRIES_BETWEEN_SQL,
                        arrayOf(startMillis.toString(), endMillis.toString())).use { result ->
                    return result.count > 0
                }
            }
        } catch (ex: Exception) {
        }
        return false
    }

    fun queryScheduleEntriesForDay(date: LocalDate): ArrayList<ScheduleEntry> {
        try {
            openDatabase()?.use { database ->
                val startMillis = date.atStartOfDay().toEpochSecond(zoneOffset) * 1000
                val endMillis = date.plusDays(1).atStartOfDay().toEpochSecond(zoneOffset) * 1000

                database.rawQuery(
                        SCHEDULE_ENTRIES_BETWEEN_SQL,
                        arrayOf(startMillis.toString(), endMillis.toString())).use { result ->
                    return readScheduleEntries(result)
                }
            }
        }
        catch(ex: Exception) {
        }
        return ArrayList()
    }

    fun queryPendingForDay(now: LocalDateTime): List<ScheduleEntry> {
        val midnight = LocalDate
                .now()
                .plusDays(1)
                .atStartOfDay()

        return ScheduleProvider(context)
                .queryScheduleEntriesBetween(now, midnight)
    }
    
    fun queryScheduleEntriesBetween(start: LocalDateTime, end: LocalDateTime): ArrayList<ScheduleEntry> {
        return queryScheduleEntriesBetweenWithStatus(start, end).entries
    }

    fun queryScheduleEntriesBetweenWithStatus(start: LocalDateTime, end: LocalDateTime): QueryResult {
        try {
            openDatabase()?.use { database ->
                val startMillis = start.toEpochSecond(zoneOffset) * 1000
                val endMillis = end.toEpochSecond(zoneOffset) * 1000

                database.rawQuery(
                        SCHEDULE_ENTRIES_BETWEEN_SQL,
                        arrayOf(startMillis.toString(), endMillis.toString())).use { result ->
                    return QueryResult(readScheduleEntries(result), true)
                }
            }
        }
        catch (ex: Exception) {
            Log.w("ScheduleProvider", "queryScheduleEntriesBetweenWithStatus failed", ex)
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
                        .openDatabase(path,
                                null,
                                SQLiteDatabase.OPEN_READONLY)
            } catch (e: Exception) {
            }
        }
        return null
    }

    private fun readScheduleEntries(result: Cursor): ArrayList<ScheduleEntry> {
        val entries: ArrayList<ScheduleEntry> = ArrayList()

        while (result.moveToNext()) {
            val entry = readScheduleEntry(result)
            entries.add(entry)
        }

        return entries
    }

    private fun readScheduleEntry(result: Cursor): ScheduleEntry {
        val startMillis = result.getLong(result.getColumnIndex("start"))
        val endMillis = result.getLong(result.getColumnIndex("end"))

        val start = LocalDateTime.ofEpochSecond(
                startMillis / 1000,
                0,
                zoneOffset)

        val end = LocalDateTime.ofEpochSecond(
                endMillis / 1000,
                0,
                zoneOffset)

        return ScheduleEntry(
                result.getInt(result.getColumnIndex("id")),
                result.getString(result.getColumnIndex("title")),
                result.getString(result.getColumnIndex("details")),
                result.getString(result.getColumnIndex("professor")),
                result.getString(result.getColumnIndex("room")),
                result.getInt(result.getColumnIndex("type")),
                start,
                end)
    }

    companion object {
        private const val SCHEDULE_ENTRIES_BETWEEN_SQL =
                "SELECT  \n" +
                "ScheduleEntries.id,\n" +
                "ScheduleEntries.start,\n" +
                "ScheduleEntries.end,\n" +
                "ScheduleEntries.title,\n" +
                "ScheduleEntries.details,\n" +
                "ScheduleEntries.professor,\n" +
                "ScheduleEntries.room,\n" +
                "ScheduleEntries.type\n" +
                "FROM \n" +
                "    ScheduleEntries\n" +
                "    LEFT JOIN ScheduleEntryFilters\n" +
                "        ON ScheduleEntries.title = ScheduleEntryFilters.title\n" +
                "    WHERE end >= ? AND start <= ?\n" +
                "        AND ScheduleEntryFilters.title IS NULL\n" +
                "ORDER BY ScheduleEntries.start ASC;\n"
    }
}

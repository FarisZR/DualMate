package com.fariszr.dualmate.model

import org.threeten.bp.LocalDate

class CanteenEntry(
    val id: Int,
    val date: LocalDate,
    val name: String,
    val category: String,
    val price: Double,
    val mealTypes: List<String>
)

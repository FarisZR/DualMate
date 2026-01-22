package de.bennik2000.dhbwstudentapp.model

class CanteenEntry(
    val id: Int,
    val name: String,
    val category: String,
    val price: Double,
    val mealTypes: List<String>
)

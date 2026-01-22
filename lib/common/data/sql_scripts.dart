import 'dart:core';

class SqlScripts {
  static final databaseMigrationScripts = [
    // Version 1 - init database
    [
      '''
CREATE TABLE IF NOT EXISTS ScheduleEntries
(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  start INTEGER,
  end INTEGER,
  title TEXT,
  details TEXT,
  professor TEXT,
  room TEXT,
  type INTEGER
);

''',
      '''
CREATE TABLE IF NOT EXISTS ScheduleQueryInformation
(
  start INTEGER,
  end INTEGER,
  queryTime INTEGER,
  PRIMARY KEY (start, end)
);
'''
    ],

    // Version 2 - Add DateEntries table
    [
      '''
CREATE TABLE IF NOT EXISTS DateEntries
(
  date INTEGER,
  comment TEXT,
  description TEXT,
  year TEXT,
  databaseName TEXT
);
'''
    ],

    // Version 3 - Add Schedule Entry filter table
    [
      '''
CREATE TABLE IF NOT EXISTS ScheduleEntryFilters
(
  title TEXT
);
'''
    ],

    // Version 4 - Add Canteen meals table
    [
      '''
CREATE TABLE IF NOT EXISTS canteen_meals
(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  date INTEGER,
  name TEXT,
  category TEXT,
  price REAL,
  notes TEXT,
  meal_types TEXT
);
'''
    ],
  ];
}

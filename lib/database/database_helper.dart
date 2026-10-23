import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Stockage SQLite local pour DP Scolaire.
/// Les données de l'application sont enregistrées dans une table clé/valeur
/// afin de migrer sans casser les modèles déjà utilisés par l'interface.
class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  Database? _database;

  Future<void> initialize() async {
    if (!kIsWeb && Platform.isWindows) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
    await database;
  }

  Future<Database> get database async {
    if (_database != null) return _database!;
    final directory = await getApplicationDocumentsDirectory();
    final dbPath = p.join(directory.path, 'dp_scolaire.db');
    _database = await openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute("CREATE TABLE app_data (data_key TEXT PRIMARY KEY, data_value TEXT NOT NULL)");
      },
    );
    return _database!;
  }

  Future<bool> isEmpty() async {
    final db = await database;
    final rows = await db.rawQuery('SELECT COUNT(*) AS total FROM app_data');
    return ((rows.first['total'] as int?) ?? 0) == 0;
  }

  Future<Map<String, String>> getAll() async {
    final db = await database;
    final rows = await db.query('app_data', columns: ['data_key', 'data_value']);
    return {
      for (final row in rows)
        row['data_key'] as String: row['data_value'] as String,
    };
  }

  Future<String?> getString(String key) async {
    final db = await database;
    final rows = await db.query(
      'app_data',
      columns: ['data_value'],
      where: 'data_key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['data_value'] as String;
  }

  Future<void> setString(String key, String value) async => setMany({key: value});

  Future<void> setMany(Map<String, String> values) async {
    if (values.isEmpty) return;
    final db = await database;
    await db.transaction((txn) async {
      final batch = txn.batch();
      for (final entry in values.entries) {
        batch.insert(
          'app_data',
          {'data_key': entry.key, 'data_value': entry.value},
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    });
  }

  Future<void> deleteKey(String key) async {
    final db = await database;
    await db.delete('app_data', where: 'data_key = ?', whereArgs: [key]);
  }

  Future<void> clearAll() async {
    final db = await database;
    await db.delete('app_data');
  }
}

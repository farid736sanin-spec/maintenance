import 'dart:io';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../config/database_paths.dart';
import 'record_values.dart';

/// Form used for fields defined in Settings and for new records.
const customMaintenanceFormName = 'Custom Maintenance';

class AppDatabase {
  AppDatabase._(this._db);

  final Database _db;

  Database get raw => _db;

  static AppDatabase? _instance;

  static Future<AppDatabase> open() async {
    if (_instance != null) return _instance!;
    sqfliteFfiInit();
    final factory = databaseFactoryFfi;
    final path = await resolveDatabaseFilePath();
    final db = await factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 3,
        onCreate: (db, version) async {
          await _createSchema(db);
          await _createAiAnswerSchema(db);
          await _seedDemoData(db);
          await _ensureCustomMaintenanceForm(db);
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) {
            await db.execute(
              'ALTER TABLE form_fields ADD COLUMN default_value TEXT',
            );
            await _ensureCustomMaintenanceForm(db);
          }
          if (oldVersion < 3) {
            await _createAiAnswerSchema(db);
          }
        },
      ),
    );
    _instance = AppDatabase._(db);
    return _instance!;
  }

  static Future<void> _createSchema(Database db) async {
    await db.execute('''
CREATE TABLE maintenance_forms (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL UNIQUE,
  display_order INTEGER NOT NULL DEFAULT 0
);
''');
    await db.execute('''
CREATE TABLE form_fields (
  id TEXT NOT NULL,
  form_id INTEGER NOT NULL,
  label TEXT NOT NULL,
  field_type TEXT NOT NULL,
  options_json TEXT,
  default_value TEXT,
  display_order INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (form_id, id),
  FOREIGN KEY (form_id) REFERENCES maintenance_forms(id) ON DELETE CASCADE
);
''');
    await db.execute('''
CREATE TABLE maintenance_records (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  form_id INTEGER NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  FOREIGN KEY (form_id) REFERENCES maintenance_forms(id)
);
''');
    await db.execute(
      'CREATE INDEX idx_records_form ON maintenance_records(form_id);',
    );
    await db.execute(
      'CREATE INDEX idx_records_created ON maintenance_records(created_at);',
    );
    await db.execute('''
CREATE TABLE record_field_values (
  record_id INTEGER NOT NULL,
  field_id TEXT NOT NULL,
  value_text TEXT,
  value_real REAL,
  value_int INTEGER,
  value_date_iso TEXT,
  PRIMARY KEY (record_id, field_id),
  FOREIGN KEY (record_id) REFERENCES maintenance_records(id) ON DELETE CASCADE
);
''');
    await db.execute(
      'CREATE INDEX idx_rfv_field_text ON record_field_values(field_id, value_text);',
    );
    await db.execute(
      'CREATE INDEX idx_rfv_field_real ON record_field_values(field_id, value_real);',
    );
    await db.execute(
      'CREATE INDEX idx_rfv_field_int ON record_field_values(field_id, value_int);',
    );
    await db.execute(
      'CREATE INDEX idx_rfv_field_date ON record_field_values(field_id, value_date_iso);',
    );
    await db.execute(
      'CREATE INDEX idx_rfv_record ON record_field_values(record_id);',
    );
  }

  static Future<void> _createAiAnswerSchema(Database db) async {
    await db.execute('''
CREATE TABLE IF NOT EXISTS record_ai_answers (
  record_id INTEGER PRIMARY KEY,
  answer_text TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  FOREIGN KEY (record_id) REFERENCES maintenance_records(id) ON DELETE CASCADE
);
''');
  }

  static Future<int> _ensureCustomMaintenanceForm(Database db) async {
    final rows = await db.query(
      'maintenance_forms',
      where: 'name = ?',
      whereArgs: [customMaintenanceFormName],
      limit: 1,
    );
    if (rows.isNotEmpty) {
      return rows.first['id'] as int;
    }
    return db.insert('maintenance_forms', {
      'name': customMaintenanceFormName,
      'display_order': 0,
    });
  }

  static Future<void> _seedDemoData(Database db) async {
    if (!Platform.environment.containsKey('FLUTTER_TEST')) {
      // Always seed on first create for a usable home screen.
    }
    final electricalId = await db.insert('maintenance_forms', {
      'name': 'Electrical',
      'display_order': 1,
    });
    final mechanicalId = await db.insert('maintenance_forms', {
      'name': 'Mechanical',
      'display_order': 2,
    });

    Future<void> fields(int formId, List<Map<String, Object?>> defs) async {
      for (final f in defs) {
        await db.insert('form_fields', {
          'form_id': formId,
          'id': f['id'],
          'label': f['label'],
          'field_type': f['field_type'],
          'display_order': f['display_order'],
          'options_json': f['options_json'],
        });
      }
    }

    await fields(electricalId, <Map<String, Object?>>[
      {
        'label': 'Problem',
        'field_type': 'text',
        'display_order': 1,
        'options_json': null,
      },
      {
        'label': 'Solution',
        'field_type': 'text',
        'display_order': 2,
        'options_json': null,
      },
      {
        'id': 'machine',
        'label': 'Machine',
        'field_type': 'dropdown',
        'display_order': 3,
        'options_json': '["M-100","M-205","CNC-04"]',
      },
      {
        'id': 'technician',
        'label': 'Technician',
        'field_type': 'dropdown',
        'display_order': 4,
        'options_json': '["Ahmed","Ali","Sara"]',
      },
      {
        'id': 'priority',
        'label': 'Priority',
        'field_type': 'dropdown',
        'display_order': 5,
        'options_json': '["Low","Medium","High","Critical"]',
      },
    ].map((m) {
      m.putIfAbsent('id', () => m['label'].toString().toLowerCase());
      return m;
    }).toList());

    await fields(mechanicalId, <Map<String, Object?>>[
      {
        'label': 'Problem',
        'field_type': 'text',
        'display_order': 1,
        'options_json': null,
      },
      {
        'label': 'Solution',
        'field_type': 'text',
        'display_order': 2,
        'options_json': null,
      },
      {
        'id': 'machine',
        'label': 'Machine',
        'field_type': 'dropdown',
        'display_order': 3,
        'options_json': '["M-100","M-205","CNC-04"]',
      },
      {
        'id': 'technician',
        'label': 'Technician',
        'field_type': 'dropdown',
        'display_order': 4,
        'options_json': '["Ahmed","Ali","Sara"]',
      },
      {
        'id': 'priority',
        'label': 'Priority',
        'field_type': 'dropdown',
        'display_order': 5,
        'options_json': '["Low","Medium","High","Critical"]',
      },
      {
        'id': 'root_cause',
        'label': 'Root Cause',
        'field_type': 'text',
        'display_order': 6,
        'options_json': null,
      },
    ].map((m) {
      m.putIfAbsent('id', () => m['label'].toString().toLowerCase());
      return m;
    }).toList());

    Future<void> insertRecord(
      int formId,
      DateTime created,
      Map<String, dynamic> values,
    ) async {
      final recordId = await db.insert('maintenance_records', {
        'form_id': formId,
        'created_at': created.toUtc().toIso8601String(),
        'updated_at': created.toUtc().toIso8601String(),
      });
      for (final entry in values.entries) {
        await db.insert('record_field_values', {
          'record_id': recordId,
          'field_id': entry.key,
          ...recordValueColumns(entry.value),
        });
      }
    }

    await insertRecord(electricalId, DateTime(2026, 9, 30, 10), {
      'problem': 'Motor stopped',
      'solution': 'Replaced fuse',
      'machine': 'M-100',
      'technician': 'Ahmed',
      'priority': 'High',
    });
    await insertRecord(mechanicalId, DateTime(2026, 9, 29, 14), {
      'problem': 'Abnormal noise',
      'solution': 'Bearing replaced',
      'machine': 'M-205',
      'technician': 'Ali',
      'priority': 'Medium',
      'root_cause': 'Worn bearing',
    });
    await insertRecord(electricalId, DateTime(2026, 9, 28, 9), {
      'problem': 'Motor overheating',
      'solution': 'Cleaned vents',
      'machine': 'CNC-04',
      'technician': 'Ahmed',
      'priority': 'High',
    });
    await insertRecord(mechanicalId, DateTime(2026, 9, 27, 11), {
      'problem': 'Motor vibration',
      'solution': 'Aligned shaft',
      'machine': 'M-100',
      'technician': 'Sara',
      'priority': 'Low',
    });
  }

  Future<void> close() => _db.close();
}

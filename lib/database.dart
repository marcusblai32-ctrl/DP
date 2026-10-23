import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class LocalDb {
  LocalDb._();
  static final LocalDb instance = LocalDb._();
  Database? _db;

  Future<Database> get db async {
    if (_db != null) return _db!;
    final root = await getDatabasesPath();
    _db = await openDatabase(
      p.join(root, 'dimension_production.db'),
      version: 1,
      onCreate: (d, version) async {
        await d.execute('''CREATE TABLE students (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          dimension TEXT NOT NULL DEFAULT 'Dimension 2',
          subgroup TEXT NOT NULL DEFAULT 'A',
          notes TEXT NOT NULL DEFAULT '',
          created_at TEXT NOT NULL
        )''');
        await d.execute('''CREATE TABLE assignments (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          title TEXT NOT NULL,
          chapter TEXT NOT NULL DEFAULT '',
          due_date TEXT NOT NULL DEFAULT '',
          details TEXT NOT NULL DEFAULT '',
          created_at TEXT NOT NULL
        )''');
        await d.execute('''CREATE TABLE homework_status (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          student_id INTEGER NOT NULL,
          assignment_id INTEGER NOT NULL,
          status TEXT NOT NULL DEFAULT 'AF',
          score REAL,
          comment TEXT NOT NULL DEFAULT '',
          updated_at TEXT NOT NULL,
          UNIQUE(student_id, assignment_id),
          FOREIGN KEY(student_id) REFERENCES students(id) ON DELETE CASCADE,
          FOREIGN KEY(assignment_id) REFERENCES assignments(id) ON DELETE CASCADE
        )''');
        await d.execute('''CREATE TABLE assessments (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          student_id INTEGER NOT NULL,
          chapter TEXT NOT NULL,
          practical REAL NOT NULL DEFAULT 0,
          theory REAL NOT NULL DEFAULT 0,
          discipline REAL NOT NULL DEFAULT 0,
          date TEXT NOT NULL,
          notes TEXT NOT NULL DEFAULT '',
          FOREIGN KEY(student_id) REFERENCES students(id) ON DELETE CASCADE
        )''');
      },
    );
    return _db!;
  }

  Future<List<Map<String, Object?>>> students() async => (await db).query('students', orderBy: 'name COLLATE NOCASE');
  Future<int> addStudent(String name, String dimension, String subgroup) async => (await db).insert('students', {
    'name': name.trim(), 'dimension': dimension, 'subgroup': subgroup, 'created_at': DateTime.now().toIso8601String(),
  });
  Future<int> deleteStudent(int id) async => (await db).delete('students', where: 'id=?', whereArgs: [id]);
  Future<List<Map<String, Object?>>> assignments() async => (await db).query('assignments', orderBy: 'id DESC');
  Future<int> addAssignment(String title, String chapter, String dueDate, String details) async => (await db).insert('assignments', {
    'title': title.trim(), 'chapter': chapter.trim(), 'due_date': dueDate.trim(), 'details': details.trim(), 'created_at': DateTime.now().toIso8601String(),
  });
  Future<List<Map<String, Object?>>> statusRows() async => (await db).rawQuery('''
    SELECT s.name AS student, s.dimension, a.title AS assignment, a.chapter, a.due_date,
           COALESCE(h.status, 'AF') AS status, h.score, COALESCE(h.comment, '') AS comment
    FROM students s CROSS JOIN assignments a
    LEFT JOIN homework_status h ON h.student_id=s.id AND h.assignment_id=a.id
    ORDER BY s.name, a.id DESC
  ''');
  Future<void> setStatus(int studentId, int assignmentId, String status) async {
    await (await db).insert('homework_status', {
      'student_id': studentId, 'assignment_id': assignmentId, 'status': status,
      'updated_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }
  Future<void> addAssessment({required int studentId, required String chapter, required double practical,
    required double theory, required double discipline, required String notes}) async {
    await (await db).insert('assessments', {
      'student_id': studentId, 'chapter': chapter, 'practical': practical, 'theory': theory,
      'discipline': discipline, 'date': DateTime.now().toIso8601String(), 'notes': notes,
    });
  }
  Future<List<Map<String, Object?>>> assessments() async => (await db).rawQuery('''
    SELECT s.name AS student, a.chapter, a.practical, a.theory, a.discipline,
    (a.practical+a.theory+a.discipline) AS total, a.date, a.notes
    FROM assessments a JOIN students s ON s.id=a.student_id ORDER BY a.date DESC
  ''');
  Future<List<Map<String, Object?>>> allStudentsForExport() => students();
}

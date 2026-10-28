import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';

import 'models/assessment.dart';
import 'models/attendance_record.dart';
import 'models/exam_question.dart';
import 'models/grade_record.dart';
import 'models/student.dart';
import 'services/file_name_service.dart';
import 'services/grade_service.dart';
import 'services/notification_service.dart';
import 'services/pdf_service.dart';
import 'theme/app_theme.dart';
import 'widgets/app_card.dart';
import 'widgets/dashboard_widgets.dart';
import 'widgets/dialogs.dart';
import 'widgets/empty_state.dart';
import 'widgets/page_header.dart';
import 'widgets/page_scroll.dart';
import 'widgets/section_title.dart';
import 'widgets/trend_chart.dart';

void main() => runApp(const SchoolApp());

class SchoolApp extends StatelessWidget {
  const SchoolApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DP',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const SchoolHome(),
    );
  }
}

/// Entrée de navigation (index de page, libellé, icônes).
class _NavItem {
  const _NavItem(this.index, this.label, this.icon, this.selectedIcon);
  final int index;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

const List<_NavItem> _navItems = [
  _NavItem(0, 'Accueil', Icons.dashboard_outlined, Icons.dashboard),
  _NavItem(1, 'Élèves', Icons.people_outline, Icons.people),
  _NavItem(2, 'Niveaux et groupes', Icons.school_outlined, Icons.school),
  _NavItem(3, 'Présences', Icons.fact_check_outlined, Icons.fact_check),
  _NavItem(4, 'Évaluations et notes', Icons.grade_outlined, Icons.grade),
  _NavItem(5, 'Examens', Icons.quiz_outlined, Icons.quiz),
  _NavItem(6, 'Rapports et classement', Icons.emoji_events_outlined, Icons.emoji_events),
  _NavItem(7, 'Calendrier des cours', Icons.calendar_month_outlined, Icons.calendar_month),
  _NavItem(8, 'Préparation des cours', Icons.menu_book_outlined, Icons.menu_book),
];

/// Avance du rappel (libellé → minutes).
const Map<String, int> _leadOptions = {
  'À l’heure': 0,
  '10 minutes avant': 10,
  '30 minutes avant': 30,
  '1 heure avant': 60,
  '1 jour avant': 1440,
};

String _defaultSchoolYear() {
  final now = DateTime.now();
  final start = now.month >= 8 ? now.year : now.year - 1;
  return '$start-${start + 1}';
}

T? _findOrNull<T>(Iterable<T> items, bool Function(T) test) {
  for (final item in items) {
    if (test(item)) return item;
  }
  return null;
}

class SchoolHome extends StatefulWidget {
  const SchoolHome({super.key});
  @override
  State<SchoolHome> createState() => _SchoolHomeState();
}

class _SchoolHomeState extends State<SchoolHome> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _studentSearch = TextEditingController();
  String _studentQuery = '';
  String _docsPath = '';
  Timer? _reminderTimer;
  final Set<String> _alerted = {};
  bool _alertOpen = false;
  final Map<String, String> schoolInfo = {
    'name': 'Dimension Production',
    'year': _defaultSchoolYear(),
    'teacher': '',
  };

  int tab = 0;
  bool loading = true;
  List<String> levels = ['Niveau 1'];
  List<String> groups = ['Groupe A'];
  List<Student> students = [];
  List<Assessment> assessments = [];
  List<AttendanceRecord> attendance = [];
  List<GradeRecord> grades = [];
  List<ExamQuestion> questionBank = [];
  List<Map<String, dynamic>> courseSessions = [];
  List<Map<String, dynamic>> coursePreparations = [];
  List<Map<String, dynamic>> reminders = [];
  final remarks = <String, String>{
    'excellent': 'Excellent travail. Continuez vos efforts.',
    'good': 'Bon travail. Poursuivez vos efforts.',
    'average': 'Résultats satisfaisants, mais des progrès sont nécessaires.',
    'weak': 'Des efforts supplémentaires sont nécessaires.',
    'poor': 'Un accompagnement régulier est recommandé.',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _reminderTimer?.cancel();
    _studentSearch.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Données (logique inchangée : SharedPreferences, mêmes clés)
  // ---------------------------------------------------------------------------

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    var loadFailed = false;
    try {
      _docsPath = (await getApplicationDocumentsDirectory()).path;
    } catch (_) {}
    try {
      levels = List<String>.from(jsonDecode(p.getString('levels') ?? '["Niveau 1"]'));
      groups = List<String>.from(jsonDecode(p.getString('groups') ?? '["Groupe A"]'));
      students = (jsonDecode(p.getString('students') ?? '[]') as List).map((e) => Student.fromJson(e)).toList();
      assessments = (jsonDecode(p.getString('assessments') ?? '[]') as List).map((e) => Assessment.fromJson(e)).toList();
      attendance = (jsonDecode(p.getString('attendance') ?? '[]') as List).map((e) => AttendanceRecord.fromJson(e)).toList();
      grades = (jsonDecode(p.getString('grades') ?? '[]') as List).map((e) => GradeRecord.fromJson(e)).toList();
      questionBank = (jsonDecode(p.getString('questions') ?? '[]') as List).map((e) => ExamQuestion.fromJson(Map<String, dynamic>.from(e as Map))).toList();
      schoolInfo.addAll((jsonDecode(p.getString('schoolInfo') ?? '{}') as Map).map((k, v) => MapEntry('$k', '$v')));
      remarks.addAll(Map<String, String>.from(jsonDecode(p.getString('remarks') ?? '{}')));
      courseSessions = List<Map<String, dynamic>>.from((jsonDecode(p.getString('courseSessions') ?? '[]') as List).map((e) => Map<String, dynamic>.from(e)));
      coursePreparations = List<Map<String, dynamic>>.from((jsonDecode(p.getString('coursePreparations') ?? '[]') as List).map((e) => Map<String, dynamic>.from(e)));
      reminders = List<Map<String, dynamic>>.from((jsonDecode(p.getString('reminders') ?? '[]') as List).map((e) => Map<String, dynamic>.from(e)));
    } catch (_) {
      loadFailed = true;
    }
    if (!mounted) return;
    setState(() => loading = false);
    _startReminderEngine();
    if (loadFailed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _msg('Certaines données enregistrées n’ont pas pu être lues.', error: true);
      });
    }
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('levels', jsonEncode(levels));
    await p.setString('groups', jsonEncode(groups));
    await p.setString('students', jsonEncode(students.map((e) => e.toJson()).toList()));
    await p.setString('assessments', jsonEncode(assessments.map((e) => e.toJson()).toList()));
    await p.setString('attendance', jsonEncode(attendance.map((e) => e.toJson()).toList()));
    await p.setString('grades', jsonEncode(grades.map((e) => e.toJson()).toList()));
    await p.setString('questions', jsonEncode(questionBank.map((e) => e.toJson()).toList()));
    await p.setString('remarks', jsonEncode(remarks));
    await p.setString('courseSessions', jsonEncode(courseSessions));
    await p.setString('coursePreparations', jsonEncode(coursePreparations));
    await p.setString('reminders', jsonEncode(reminders));
    await p.setString('schoolInfo', jsonEncode(schoolInfo));
  }

  // ---------------------------------------------------------------------------
  // Utilitaires
  // ---------------------------------------------------------------------------

  String _id() => DateTime.now().microsecondsSinceEpoch.toString();

  void _msg(String s, {bool error = false}) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(
      content: Row(children: [
        Icon(error ? Icons.error_outline : Icons.check_circle_outline,
            color: error ? AppColors.danger : AppColors.success),
        const SizedBox(width: 12),
        Expanded(child: Text(s)),
      ]),
    ));
  }

  Student? _student(String id) => _findOrNull(students, (s) => s.id == id);
  Assessment? _assessment(String id) => _findOrNull(assessments, (a) => a.id == id);

  double _average(Student s) => GradeService.average(s, grades, assessments);

  String _remark(double avg) {
    if (avg >= 90) return remarks['excellent']!;
    if (avg >= 80) return remarks['good']!;
    if (avg >= 60) return remarks['average']!;
    if (avg >= 40) return remarks['weak']!;
    return remarks['poor']!;
  }

  String _letterGrade(double avg) => GradeService.letterGrade(avg);

  double? _parseNumber(String text) => double.tryParse(text.trim().replaceAll(',', '.'));

  String _fmtNum(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  String _todayIso() => DateTime.now().toIso8601String().substring(0, 10);

  /// Affiche une date ISO (aaaa-mm-jj) au format jj/mm/aaaa.
  String _fmtDate(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  String _isoFromDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    String first(String s) => String.fromCharCode(s.runes.first).toUpperCase();
    if (parts.length == 1) return first(parts.first);
    return first(parts.first) + first(parts.last);
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'Retard':
        return 'En retard';
      case 'Excusé':
        return 'Absence excusée';
      default:
        return status;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Présent':
        return AppColors.success;
      case 'Absent':
        return AppColors.danger;
      case 'Retard':
        return AppColors.warning;
      case 'Excusé':
        return AppColors.info;
      default:
        return AppColors.muted;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'Présent':
        return Icons.check_circle_outline;
      case 'Absent':
        return Icons.cancel_outlined;
      case 'Retard':
        return Icons.schedule;
      case 'Excusé':
        return Icons.info_outline;
      default:
        return Icons.help_outline;
    }
  }

  Widget _dropdown(String label, String value, List<String> items, ValueChanged<String> onChanged) {
    return DropdownButtonFormField<String>(
      value: items.contains(value) ? value : null,
      isExpanded: true,
      items: [for (final x in items) DropdownMenuItem(value: x, child: Text(x, overflow: TextOverflow.ellipsis))],
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
      decoration: InputDecoration(labelText: label),
    );
  }

  List<(Student, int)> _rankedStudents() {
    final avgs = {for (final s in students) s.id: _average(s)};
    final sorted = students.toList()..sort((a, b) => (avgs[b.id] ?? 0).compareTo(avgs[a.id] ?? 0));
    return [for (var i = 0; i < sorted.length; i++) (sorted[i], i + 1)];
  }

  List<Map<String, dynamic>> _sortedSessions() {
    final list = List<Map<String, dynamic>>.from(courseSessions);
    list.sort((a, b) => ('${a['date']} ${a['time']}').compareTo('${b['date']} ${b['time']}'));
    return list;
  }

  List<Map<String, dynamic>> _upcomingSessions() {
    final today = _todayIso();
    return _sortedSessions().where((e) => (e['date'] ?? '').toString().compareTo(today) >= 0).toList();
  }

  List<Map<String, dynamic>> _pastSessions() {
    final today = _todayIso();
    return _sortedSessions().where((e) => (e['date'] ?? '').toString().compareTo(today) < 0).toList().reversed.toList();
  }

  // ---------------------------------------------------------------------------
  // Dialogues de saisie
  // ---------------------------------------------------------------------------

  Future<void> _textDialog(String title, String hint, Future<String?> Function(String) onSave) async {
    final c = TextEditingController();
    String? error;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text(title),
          content: DialogBody(
            child: TextField(
              controller: c,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: hint, errorText: error),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
            FilledButton(
              onPressed: () async {
                final v = c.text.trim();
                if (v.isEmpty) {
                  setD(() => error = 'Ce champ est obligatoire.');
                  return;
                }
                final problem = await onSave(v);
                if (problem != null) {
                  setD(() => error = problem);
                  return;
                }
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addStudent() async {
    final name = TextEditingController();
    String level = levels.first, group = groups.first;
    String? nameError;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('Ajouter un élève'),
          content: DialogBody(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                controller: name,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(labelText: 'Nom complet', errorText: nameError),
              ),
              const SizedBox(height: 14),
              _dropdown('Niveau', level, levels, (v) => setD(() => level = v)),
              const SizedBox(height: 14),
              _dropdown('Groupe', group, groups, (v) => setD(() => group = v)),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
            FilledButton(
              onPressed: () async {
                if (name.text.trim().isEmpty) {
                  setD(() => nameError = 'Saisissez le nom de l’élève.');
                  return;
                }
                setState(() => students.add(Student(_id(), name.text.trim(), level, group)));
                await _save();
                if (ctx.mounted) Navigator.pop(ctx);
                _msg('Élève ajouté.');
              },
              child: const Text('Ajouter'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addAssessment({String category = 'Devoir'}) async {
    final title = TextEditingController();
    final max = TextEditingController(text: '100');
    String level = levels.first, group = groups.first;
    String? titleError, maxError;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text('Créer une évaluation : $category'),
          content: DialogBody(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                controller: title,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(labelText: 'Titre', errorText: titleError),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: max,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: 'Note maximale', errorText: maxError),
              ),
              const SizedBox(height: 14),
              _dropdown('Niveau', level, levels, (v) => setD(() => level = v)),
              const SizedBox(height: 14),
              _dropdown('Groupe', group, groups, (v) => setD(() => group = v)),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
            FilledButton(
              onPressed: () async {
                final n = _parseNumber(max.text) ?? 100;
                final titleOk = title.text.trim().isNotEmpty;
                final maxOk = n > 0;
                if (!titleOk || !maxOk) {
                  setD(() {
                    titleError = titleOk ? null : 'Saisissez un titre.';
                    maxError = maxOk ? null : 'La note maximale doit être supérieure à 0.';
                  });
                  return;
                }
                setState(() => assessments.add(Assessment(_id(), title.text.trim(), category, level, group, _todayIso(), 'Manuel', n)));
                await _save();
                if (ctx.mounted) Navigator.pop(ctx);
                _msg('Évaluation créée.');
              },
              child: const Text('Créer'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteAssessment(Assessment a) async {
    final ok = await confirmDialog(
      context,
      title: 'Supprimer cette évaluation ?',
      message: '« ${a.title} » et les notes saisies pour cette évaluation seront supprimées.',
      confirmLabel: 'Supprimer',
      destructive: true,
    );
    if (!ok) return;
    setState(() {
      assessments.removeWhere((x) => x.id == a.id);
      grades.removeWhere((g) => g.assessmentId == a.id);
    });
    await _save();
    _msg('Évaluation supprimée.');
  }

  Future<void> _enterGrades(Assessment a) async {
    final matching = students.where((s) => s.level == a.level && s.group == a.group).toList();
    if (matching.isEmpty) {
      _msg('Aucun élève dans ce niveau/groupe.', error: true);
      return;
    }
    final controllers = <String, TextEditingController>{};
    for (final s in matching) {
      final old = _findOrNull(grades, (g) => g.studentId == s.id && g.assessmentId == a.id);
      controllers[s.id] = TextEditingController(text: old == null ? '' : _fmtNum(old.score));
    }
    String? formError;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text('Saisir les notes : ${a.title}'),
          content: SizedBox(
            width: 480,
            height: dialogListHeight(ctx),
            child: Column(children: [
              FormErrorText(formError),
              Expanded(
                child: ListView.separated(
                  itemCount: matching.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final s = matching[i];
                    return Row(children: [
                      Expanded(child: Text(s.name, maxLines: 2, overflow: TextOverflow.ellipsis)),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 128,
                        child: TextField(
                          controller: controllers[s.id],
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(labelText: 'Note', suffixText: '/ ${_fmtNum(a.maxScore)}'),
                        ),
                      ),
                    ]);
                  },
                ),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
            FilledButton(
              onPressed: () async {
                // Validation complète avant toute modification des notes.
                final updates = <String, double>{};
                for (final s in matching) {
                  final text = controllers[s.id]!.text.trim();
                  if (text.isEmpty) continue;
                  final val = _parseNumber(text);
                  if (val == null || val < 0 || val > a.maxScore) {
                    setD(() => formError = 'Note invalide pour ${s.name} : entrez un nombre entre 0 et ${_fmtNum(a.maxScore)}.');
                    return;
                  }
                  updates[s.id] = val;
                }
                for (final entry in updates.entries) {
                  grades.removeWhere((g) => g.studentId == entry.key && g.assessmentId == a.id);
                  grades.add(GradeRecord(entry.key, a.id, entry.value, ''));
                }
                await _save();
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) setState(() {});
                _msg('Notes enregistrées.');
              },
              child: const Text('Enregistrer les notes'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _markAttendance() async {
    final date = _todayIso();
    final active = List<Student>.from(students)
      ..sort((a, b) {
        final levelCompare = a.level.compareTo(b.level);
        return levelCompare != 0 ? levelCompare : a.name.compareTo(b.name);
      });
    if (active.isEmpty) {
      _msg('Ajoutez d’abord des élèves.', error: true);
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text('Présence du ${_fmtDate(date)}'),
          content: SizedBox(
            width: 480,
            height: dialogListHeight(ctx),
            child: ListView.separated(
              itemCount: active.length,
              separatorBuilder: (_, __) => const Divider(),
              itemBuilder: (_, i) {
                final s = active[i];
                final record = _findOrNull(attendance, (a) => a.studentId == s.id && a.date == date);
                final status = record?.status ?? '';
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(s.name, maxLines: 2, overflow: TextOverflow.ellipsis),
                  subtitle: Text('${s.level} · ${s.group}', style: const TextStyle(color: AppColors.muted)),
                  trailing: PopupMenuButton<String>(
                    tooltip: 'Changer le statut de ${s.name}',
                    onSelected: (v) async {
                      attendance.removeWhere((a) => a.studentId == s.id && a.date == date);
                      attendance.add(AttendanceRecord(s.id, date, v, ''));
                      await _save();
                      setD(() {});
                      if (mounted) setState(() {});
                    },
                    itemBuilder: (_) => [
                      for (final v in const ['Présent', 'Absent', 'Retard', 'Excusé'])
                        PopupMenuItem(value: v, child: Text(_statusLabel(v))),
                    ],
                    child: StatusPill(
                      label: status.isEmpty ? 'À saisir' : _statusLabel(status),
                      color: _statusColor(status),
                      icon: _statusIcon(status),
                      trailing: Icons.arrow_drop_down,
                    ),
                  ),
                );
              },
            ),
          ),
          actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Terminé'))],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Banque de questions : images, choix dynamiques, examen
  // ---------------------------------------------------------------------------

  static const List<String> _questionCategories = ['QCU', 'QCM', 'Compléter', 'Définition', 'Subjectif'];

  String _imagePath(String name) => '$_docsPath${Platform.pathSeparator}dp_images${Platform.pathSeparator}$name';

  String _choiceLabel(int i) => i < 26 ? String.fromCharCode(65 + i) : '${i + 1}';

  Widget _questionImage(String name, {double height = 120}) {
    if (name.isEmpty || _docsPath.isEmpty) return const SizedBox.shrink();
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Image.file(
        File(_imagePath(name)),
        height: height,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      ),
    );
  }

  Future<String?> _pickQuestionImage() async {
    if (_docsPath.isEmpty) {
      _msg('Le dossier de stockage est indisponible sur cet appareil.', error: true);
      return null;
    }
    final picked = await FilePicker.platform.pickFiles(
      dialogTitle: 'Choisir une image',
      type: FileType.custom,
      allowedExtensions: ['png', 'jpg', 'jpeg'],
      withData: true,
    );
    if (picked == null || picked.files.isEmpty) return null;
    final file = picked.files.single;
    final Uint8List? bytes = file.bytes;
    if (bytes == null) {
      _msg('Impossible de lire cette image.', error: true);
      return null;
    }
    if (bytes.length > 5 * 1024 * 1024) {
      _msg('Image trop volumineuse (5 Mo maximum).', error: true);
      return null;
    }
    try {
      await decodeImageFromList(bytes);
    } catch (_) {
      _msg('Ce fichier n’est pas une image PNG ou JPEG valide.', error: true);
      return null;
    }
    final ext = (file.extension ?? 'png').toLowerCase() == 'png' ? 'png' : 'jpg';
    final name = 'q_${_id()}.$ext';
    try {
      final dir = Directory('$_docsPath${Platform.pathSeparator}dp_images');
      if (!await dir.exists()) await dir.create(recursive: true);
      await File(_imagePath(name)).writeAsBytes(bytes);
      return name;
    } catch (e) {
      _msg('Impossible d’enregistrer l’image : $e', error: true);
      return null;
    }
  }

  Future<void> _deleteImageFile(String name) async {
    if (name.isEmpty || _docsPath.isEmpty) return;
    try {
      final f = File(_imagePath(name));
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }

  Future<void> _addQuestion() => _editQuestion();

  Future<void> _editQuestion({ExamQuestion? existing}) async {
    final prompt = TextEditingController(text: existing?.prompt ?? '');
    final answer = TextEditingController(text: (existing != null && !existing.hasChoices) ? existing.answer : '');
    final points = TextEditingController(text: _fmtNum(existing?.points ?? 1));
    String category = existing?.category ?? 'QCU';
    String imageFile = existing?.imageFile ?? '';
    final originalImage = imageFile;
    final pickedNew = <String>[];
    final choiceCtrls = <TextEditingController>[];
    final correct = <bool>[];
    if (existing != null && existing.hasChoices && existing.choices.isNotEmpty) {
      final ci = existing.correctIndexes;
      for (var i = 0; i < existing.choices.length; i++) {
        choiceCtrls.add(TextEditingController(text: existing.choices[i]));
        correct.add(ci.contains(i));
      }
    }
    final minInitial = existing == null ? 4 : 2;
    while (choiceCtrls.length < minInitial) {
      choiceCtrls.add(TextEditingController());
      correct.add(false);
    }
    String? promptError, choicesError, pointsError;
    var saved = false;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) {
          final isChoice = category == 'QCU' || category == 'QCM';
          final isMulti = category == 'QCM';
          return AlertDialog(
            title: Text(existing == null ? 'Ajouter une question' : 'Modifier la question'),
            content: DialogBody(
              maxWidth: 580,
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                _dropdown('Catégorie', category, _questionCategories, (v) {
                  setD(() {
                    category = v;
                    if (v == 'QCU') {
                      final first = correct.indexOf(true);
                      for (var j = 0; j < correct.length; j++) {
                        correct[j] = j == first;
                      }
                    }
                  });
                }),
                const SizedBox(height: 14),
                TextField(
                  controller: prompt,
                  maxLines: 5,
                  minLines: 2,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(labelText: 'Énoncé de la question', errorText: promptError),
                ),
                const SizedBox(height: 12),
                Wrap(spacing: 10, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  OutlinedButton.icon(
                    onPressed: () async {
                      final name = await _pickQuestionImage();
                      if (name != null) {
                        pickedNew.add(name);
                        setD(() => imageFile = name);
                      }
                    },
                    icon: const Icon(Icons.image_outlined),
                    label: Text(imageFile.isEmpty ? 'Ajouter une image' : 'Changer l’image'),
                  ),
                  if (imageFile.isNotEmpty)
                    TextButton.icon(
                      onPressed: () => setD(() => imageFile = ''),
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Retirer'),
                    ),
                ]),
                if (imageFile.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Center(child: _questionImage(imageFile, height: 140)),
                  ),
                const SizedBox(height: 16),
                if (isChoice) ...[
                  Text(
                    isMulti ? 'Choix de réponse (cochez toutes les bonnes réponses)' : 'Choix de réponse (sélectionnez la bonne réponse)',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  for (var i = 0; i < choiceCtrls.length; i++)
                    Padding(
                      key: ObjectKey(choiceCtrls[i]),
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(children: [
                        IconButton(
                          tooltip: 'Bonne réponse',
                          onPressed: () => setD(() {
                            if (isMulti) {
                              correct[i] = !correct[i];
                            } else {
                              for (var j = 0; j < correct.length; j++) {
                                correct[j] = j == i;
                              }
                            }
                          }),
                          icon: Icon(
                            isMulti
                                ? (correct[i] ? Icons.check_box : Icons.check_box_outline_blank)
                                : (correct[i] ? Icons.radio_button_checked : Icons.radio_button_unchecked),
                            color: correct[i] ? AppColors.success : AppColors.muted,
                          ),
                        ),
                        Expanded(
                          child: TextField(
                            controller: choiceCtrls[i],
                            decoration: InputDecoration(labelText: 'Choix ${_choiceLabel(i)}'),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Supprimer ce choix',
                          onPressed: choiceCtrls.length <= 2
                              ? null
                              : () => setD(() {
                                    choiceCtrls.removeAt(i);
                                    correct.removeAt(i);
                                  }),
                          icon: const Icon(Icons.remove_circle_outline),
                        ),
                      ]),
                    ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: () => setD(() {
                        choiceCtrls.add(TextEditingController());
                        correct.add(false);
                      }),
                      icon: const Icon(Icons.add),
                      label: const Text('Ajouter un choix'),
                    ),
                  ),
                  if (choicesError != null) ...[
                    const SizedBox(height: 10),
                    FormErrorText(choicesError),
                  ],
                ] else
                  TextField(
                    controller: answer,
                    maxLines: 4,
                    minLines: 1,
                    decoration: const InputDecoration(labelText: 'Réponse attendue / corrigé'),
                  ),
                const SizedBox(height: 14),
                TextField(
                  controller: points,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(labelText: 'Points', errorText: pointsError),
                ),
              ]),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
              FilledButton(
                onPressed: () async {
                  final text = prompt.text.trim();
                  final pts = points.text.trim().isEmpty ? 1.0 : _parseNumber(points.text);
                  String? pe, ce, pte;
                  if (text.isEmpty) pe = 'Saisissez l’énoncé de la question.';
                  if (pts == null || pts <= 0) pte = 'Les points doivent être un nombre supérieur à 0.';
                  final newChoices = <String>[];
                  final newCorrect = <String>[];
                  if (isChoice) {
                    for (var i = 0; i < choiceCtrls.length; i++) {
                      final t = choiceCtrls[i].text.trim().replaceAll('|', '/');
                      if (t.isEmpty) continue;
                      newChoices.add(t);
                      if (correct[i]) newCorrect.add(t);
                    }
                    if (newChoices.length < 2) {
                      ce = 'Saisissez au moins deux choix.';
                    } else if (newChoices.toSet().length != newChoices.length) {
                      ce = 'Deux choix sont identiques.';
                    } else if (newCorrect.isEmpty) {
                      ce = 'Indiquez au moins une bonne réponse.';
                    } else if (category == 'QCU' && newCorrect.length != 1) {
                      ce = 'Un QCU doit avoir une seule bonne réponse.';
                    }
                  }
                  if (pe != null || ce != null || pte != null) {
                    setD(() {
                      promptError = pe;
                      choicesError = ce;
                      pointsError = pte;
                    });
                    return;
                  }
                  final q = existing ?? ExamQuestion('', category, [], '', 1);
                  q.prompt = text;
                  q.category = category;
                  q.points = pts!;
                  q.imageFile = imageFile;
                  if (isChoice) {
                    q.choices = newChoices;
                    q.answer = newCorrect.join(' | ');
                  } else {
                    q.answer = answer.text.trim();
                  }
                  if (existing == null) questionBank.add(q);
                  saved = true;
                  await _save();
                  if (originalImage.isNotEmpty && originalImage != imageFile) await _deleteImageFile(originalImage);
                  for (final f in pickedNew) {
                    if (f != imageFile) await _deleteImageFile(f);
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) setState(() {});
                  _msg(existing == null ? 'Question ajoutée à la banque.' : 'Question modifiée.');
                },
                child: Text(existing == null ? 'Ajouter' : 'Enregistrer'),
              ),
            ],
          );
        },
      ),
    );
    if (!saved) {
      for (final f in pickedNew) {
        await _deleteImageFile(f);
      }
    }
  }

  Future<void> _deleteQuestion(ExamQuestion q) async {
    final ok = await confirmDialog(
      context,
      title: 'Supprimer cette question ?',
      message: q.prompt,
      confirmLabel: 'Supprimer',
      destructive: true,
    );
    if (!ok) return;
    setState(() => questionBank.remove(q));
    await _save();
    await _deleteImageFile(q.imageFile);
  }

  Future<void> _generateExam() async {
    if (questionBank.isEmpty) {
      _msg('Ajoutez des questions à la banque avant de générer.', error: true);
      return;
    }
    final count = TextEditingController(text: questionBank.length < 10 ? '${questionBank.length}' : '10');
    String category = 'Toutes';
    final keyword = TextEditingController();
    String? error;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('Générer un examen'),
          content: DialogBody(
            maxWidth: 420,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              _dropdown('Catégorie', category, const ['Toutes', ..._questionCategories], (v) => setD(() => category = v)),
              const SizedBox(height: 14),
              TextField(
                controller: keyword,
                decoration: const InputDecoration(labelText: 'Mot-clé dans la question (ex. Rythme, Chap. 3)'),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: count,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: 'Nombre de questions', errorText: error),
              ),
              const SizedBox(height: 12),
              const Text(
                'Le générateur choisit des questions existantes au hasard. Vous pourrez retirer des questions avant d’imprimer.',
                style: TextStyle(color: AppColors.muted),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
            FilledButton(
              onPressed: () async {
                final key = keyword.text.trim().toLowerCase();
                final pool = questionBank
                    .where((q) => (category == 'Toutes' || q.category == category) && (key.isEmpty || q.prompt.toLowerCase().contains(key)))
                    .toList()
                  ..shuffle();
                final n = int.tryParse(count.text.trim()) ?? 0;
                if (n < 1 || n > pool.length) {
                  setD(() => error = 'Nombre invalide. Questions disponibles : ${pool.length}.');
                  return;
                }
                final chosen = pool.take(n).toList();
                if (ctx.mounted) Navigator.pop(ctx);
                await _showExamPreview(chosen, category);
              },
              child: const Text('Générer'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _printExam(ExamPdfOptions options, List<ExamQuestion> qs) async {
    try {
      final items = <ExamPdfQuestion>[];
      for (final q in qs) {
        Uint8List? image;
        if (q.imageFile.isNotEmpty && _docsPath.isNotEmpty) {
          try {
            final f = File(_imagePath(q.imageFile));
            if (await f.exists()) image = await f.readAsBytes();
          } catch (_) {}
        }
        items.add(ExamPdfQuestion(
          prompt: q.prompt,
          category: q.category,
          choices: q.hasChoices ? q.choices : const [],
          correct: q.correctIndexes,
          answer: q.answer,
          points: q.points,
          image: image,
        ));
      }
      final bytes = await PdfService.buildExam(options, items);
      final base = options.subject.isEmpty ? options.title : options.subject;
      final name = FileNameService.safe('${options.answerKey ? 'Corrige' : 'Examen'}_${base}_${options.date}');
      await Printing.layoutPdf(name: name, onLayout: (_) async => bytes);
    } catch (e) {
      _msg('Impossible de générer le PDF : $e', error: true);
    }
  }

  Future<void> _showExamPreview(List<ExamQuestion> questions, String category) async {
    if (!mounted) return;
    final selected = List<ExamQuestion>.from(questions);
    final school = TextEditingController(text: schoolInfo['name'] ?? '');
    final year = TextEditingController(text: schoolInfo['year'] ?? '');
    final title = TextEditingController(text: 'Examen');
    final subject = TextEditingController();
    final duration = TextEditingController(text: '1 heure');
    final instructions = TextEditingController(
      text: 'Lisez attentivement chaque question. Répondez directement sur cette feuille. Les téléphones sont interdits.',
    );
    const none = 'Non précisé';
    String level = none, group = none;
    DateTime date = DateTime.now();
    bool answerKey = false;
    String? error;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) {
          final total = selected.fold<double>(0, (sum, q) => sum + q.points);
          return AlertDialog(
            title: const Text('Préparer l’examen'),
            content: DialogBody(
              maxWidth: 620,
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text('${selected.length} question(s) · ${_fmtNum(total)} point(s) · catégorie : $category', style: const TextStyle(color: AppColors.muted)),
                const SizedBox(height: 14),
                TextField(controller: school, decoration: const InputDecoration(labelText: 'Établissement (en-tête)')),
                const SizedBox(height: 12),
                TextField(controller: year, decoration: const InputDecoration(labelText: 'Année scolaire')),
                const SizedBox(height: 12),
                TextField(controller: title, decoration: const InputDecoration(labelText: 'Titre du document')),
                const SizedBox(height: 12),
                TextField(controller: subject, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(labelText: 'Matière')),
                const SizedBox(height: 12),
                _dropdown('Classe / niveau', level, [none, ...levels], (v) => setD(() => level = v)),
                const SizedBox(height: 12),
                _dropdown('Groupe', group, [none, ...groups], (v) => setD(() => group = v)),
                const SizedBox(height: 4),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_month, color: AppColors.redSoft),
                  title: Text('Date : ${_fmtDate(_isoFromDate(date))}'),
                  subtitle: const Text('Appuyez pour modifier', style: TextStyle(color: AppColors.muted)),
                  onTap: () async {
                    final selectedDate = await showDatePicker(context: ctx, initialDate: date, firstDate: DateTime(2020), lastDate: DateTime(2100));
                    if (selectedDate != null) setD(() => date = selectedDate);
                  },
                ),
                TextField(controller: duration, decoration: const InputDecoration(labelText: 'Durée (ex. 1 heure 30)')),
                const SizedBox(height: 12),
                TextField(controller: instructions, maxLines: 4, minLines: 2, decoration: const InputDecoration(labelText: 'Consignes')),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: answerKey,
                  onChanged: (v) => setD(() => answerKey = v),
                  title: const Text('Version corrigé (enseignant)'),
                  subtitle: const Text('Marque les bonnes réponses et affiche les corrigés.', style: TextStyle(color: AppColors.muted)),
                ),
                const Divider(height: 24),
                const Text('Questions retenues', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                for (var i = 0; i < selected.length; i++)
                  Padding(
                    key: ObjectKey(selected[i]),
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(children: [
                      Expanded(
                        child: Text('${i + 1}. ${selected[i].prompt}', maxLines: 2, overflow: TextOverflow.ellipsis),
                      ),
                      if (selected[i].imageFile.isNotEmpty) const Padding(padding: EdgeInsets.only(left: 6), child: Icon(Icons.image_outlined, size: 18, color: AppColors.muted)),
                      IconButton(
                        tooltip: 'Retirer cette question',
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: () => setD(() => selected.removeAt(i)),
                      ),
                    ]),
                  ),
                if (selected.isEmpty) const Text('Aucune question : fermez et régénérez l’examen.', style: TextStyle(color: AppColors.danger)),
                if (error != null) ...[
                  const SizedBox(height: 10),
                  FormErrorText(error),
                ],
              ]),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fermer')),
              FilledButton.icon(
                onPressed: selected.isEmpty
                    ? null
                    : () async {
                        if (school.text.trim().isEmpty) {
                          setD(() => error = 'Indiquez le nom de l’établissement.');
                          return;
                        }
                        setD(() => error = null);
                        schoolInfo['name'] = school.text.trim();
                        schoolInfo['year'] = year.text.trim();
                        await _save();
                        await _printExam(
                          ExamPdfOptions(
                            schoolName: school.text.trim(),
                            schoolYear: year.text.trim(),
                            title: title.text.trim().isEmpty ? 'Examen' : title.text.trim(),
                            subject: subject.text.trim(),
                            level: level == none ? '' : level,
                            group: group == none ? '' : group,
                            date: _fmtDate(_isoFromDate(date)),
                            duration: duration.text.trim(),
                            instructions: instructions.text.trim(),
                            answerKey: answerKey,
                          ),
                          selected,
                        );
                      },
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text('Aperçu / PDF'),
              ),
            ],
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Historique, export / import, bulletins
  // ---------------------------------------------------------------------------

  Future<void> _clearHistory() async {
    final ok = await confirmDialog(
      context,
      title: 'Effacer l’historique',
      message: 'Cette action effacera les présences, les notes, les évaluations, les questions, les séances, les rappels et les préparations. '
          'Les élèves, niveaux et groupes seront conservés. Exportez une sauvegarde avant de continuer.',
      confirmLabel: 'Effacer l’historique',
      destructive: true,
    );
    if (!ok) return;
    final orphanImages = questionBank.map((q) => q.imageFile).where((f) => f.isNotEmpty).toList();
    setState(() {
      attendance.clear();
      grades.clear();
      assessments.clear();
      questionBank.clear();
      courseSessions.clear();
      coursePreparations.clear();
      reminders.clear();
    });
    await _save();
    await NotificationService.cancelAll();
    for (final f in orphanImages) {
      await _deleteImageFile(f);
    }
    _msg('Historique effacé. Les élèves, niveaux et groupes sont conservés.');
  }

  Future<void> _exportCsv() async {
    final rows = <List<String>>[
      ['Nom', 'Niveau', 'Groupe', 'Moyenne /100', 'Rang'],
    ];
    for (final entry in _rankedStudents()) {
      final s = entry.$1;
      rows.add([s.name, s.level, s.group, _average(s).toStringAsFixed(2), '${entry.$2}']);
    }
    final csv = rows.map((r) => r.map((x) => '"${x.replaceAll('"', '""')}"').join(';')).join('\n');
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}${Platform.pathSeparator}educadim_palmares.csv');
      // BOM UTF-8 : permet à Excel d’afficher correctement les accents.
      await file.writeAsString('\uFEFF$csv');
      _msg('Fichier créé : ${file.path}');
      if (Platform.isAndroid) {
        // Sur Android le dossier est privé : proposer le partage pour récupérer le fichier.
        try {
          await Share.shareXFiles(
            [XFile(file.path, mimeType: 'text/csv')],
            subject: 'Palmarès DP',
          );
        } catch (_) {}
      }
    } catch (e) {
      _msg('Impossible de créer le fichier CSV : $e', error: true);
    }
  }

  Future<void> _exportBackup() async {
    final questionsJson = <Map<String, dynamic>>[];
    for (final q in questionBank) {
      final m = q.toJson();
      if (q.imageFile.isNotEmpty && _docsPath.isNotEmpty) {
        try {
          final f = File(_imagePath(q.imageFile));
          if (await f.exists()) m['imageData'] = base64Encode(await f.readAsBytes());
        } catch (_) {}
      }
      questionsJson.add(m);
    }
    final data = {
      'format': 'dp_scolaire_backup',
      'version': 1,
      'createdAt': DateTime.now().toIso8601String(),
      'levels': levels,
      'groups': groups,
      'students': students.map((e) => e.toJson()).toList(),
      'assessments': assessments.map((e) => e.toJson()).toList(),
      'attendance': attendance.map((e) => e.toJson()).toList(),
      'grades': grades.map((e) => e.toJson()).toList(),
      'questions': questionsJson,
      'schoolInfo': schoolInfo,
      'remarks': remarks,
      'courseSessions': courseSessions,
      'coursePreparations': coursePreparations,
      'reminders': reminders,
    };
    final bytes = utf8.encode(const JsonEncoder.withIndent('  ').convert(data));
    final result = await FilePicker.platform.saveFile(
      dialogTitle: 'Exporter une sauvegarde DP Scolaire',
      fileName: 'DP_Scolaire_Backup_${_todayIso()}.json',
      type: FileType.custom,
      allowedExtensions: ['json'],
      bytes: bytes,
    );
    if (result == null) return;
    try {
      // Le partage utilise le fichier sauvegardé afin que l’utilisateur choisisse
      // Bluetooth, Quick Share, e-mail, USB ou une autre application compatible.
      await Share.shareXFiles(
        [XFile(result, mimeType: 'application/json', name: 'DP_Scolaire_Backup.json')],
        subject: 'Sauvegarde DP Scolaire',
        text: 'Sauvegarde des données DP Scolaire. Conservez ce fichier en sécurité.',
      );
    } catch (_) {
      _msg('Sauvegarde enregistrée : $result');
    }
  }

  Future<void> _importBackup() async {
    final picked = await FilePicker.platform.pickFiles(
      dialogTitle: 'Choisir une sauvegarde DP Scolaire',
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );
    if (picked == null || picked.files.isEmpty) return;
    final file = picked.files.single;
    final raw = file.bytes;
    if (raw == null) {
      _msg('Impossible de lire ce fichier. Choisissez un fichier JSON accessible.', error: true);
      return;
    }
    Map<String, dynamic> data;
    try {
      data = Map<String, dynamic>.from(jsonDecode(utf8.decode(raw)) as Map);
      if (data['format'] != 'dp_scolaire_backup' || data['version'] != 1) {
        _msg('Ce fichier n’est pas une sauvegarde DP Scolaire reconnue.', error: true);
        return;
      }
      if (data['levels'] is! List || data['groups'] is! List || data['students'] is! List) {
        _msg('Le fichier de sauvegarde est incomplet ou invalide.', error: true);
        return;
      }
    } catch (_) {
      _msg('Le fichier JSON est invalide ou endommagé.', error: true);
      return;
    }
    if (!mounted) return;
    final confirmed = await confirmDialog(
      context,
      title: 'Remplacer les données actuelles ?',
      message: 'L’importation remplacera les données actuellement affichées dans DP Scolaire. Exportez une sauvegarde avant de continuer.',
      confirmLabel: 'Importer',
      destructive: true,
    );
    if (!confirmed) return;
    try {
      levels = List<String>.from(data['levels'] as List);
      groups = List<String>.from(data['groups'] as List);
      students = (data['students'] as List).map((e) => Student.fromJson(Map<String, dynamic>.from(e as Map))).toList();
      assessments = ((data['assessments'] as List?) ?? []).map((e) => Assessment.fromJson(Map<String, dynamic>.from(e as Map))).toList();
      attendance = ((data['attendance'] as List?) ?? []).map((e) => AttendanceRecord.fromJson(Map<String, dynamic>.from(e as Map))).toList();
      grades = ((data['grades'] as List?) ?? []).map((e) => GradeRecord.fromJson(Map<String, dynamic>.from(e as Map))).toList();
      final importedQuestions = <ExamQuestion>[];
      for (final e in ((data['questions'] as List?) ?? [])) {
        final q = Map<String, dynamic>.from(e as Map);
        final imageData = q['imageData'];
        var imageFile = (q['imageFile'] ?? '').toString().replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
        if (imageData is String && imageData.isNotEmpty && imageFile.isNotEmpty && _docsPath.isNotEmpty) {
          try {
            final dir = Directory('$_docsPath${Platform.pathSeparator}dp_images');
            if (!await dir.exists()) await dir.create(recursive: true);
            await File(_imagePath(imageFile)).writeAsBytes(base64Decode(imageData));
          } catch (_) {
            imageFile = '';
          }
        }
        q['imageFile'] = imageFile;
        q.remove('imageData');
        importedQuestions.add(ExamQuestion.fromJson(q));
      }
      questionBank = importedQuestions;
      if (data['schoolInfo'] is Map) {
        schoolInfo.addAll((data['schoolInfo'] as Map).map((k, v) => MapEntry('$k', '$v')));
      }
      remarks.addAll(Map<String, String>.from(data['remarks'] ?? {}));
      courseSessions = ((data['courseSessions'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      coursePreparations = ((data['coursePreparations'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      reminders = ((data['reminders'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      await _save();
      await NotificationService.syncAll(reminders);
      if (mounted) {
        setState(() {});
        _msg('Sauvegarde importée avec succès.');
      }
    } catch (e) {
      _msg('Erreur pendant l’importation : $e', error: true);
    }
  }

  Future<void> _editRemarks() async {
    final labels = ['excellent', 'good', 'average', 'weak', 'poor'];
    final titles = ['Moyenne 90–100', 'Moyenne 80–89', 'Moyenne 60–79', 'Moyenne 40–59', 'Moyenne 0–39'];
    final ctrls = {for (final k in labels) k: TextEditingController(text: remarks[k])};
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Modifier les appréciations automatiques'),
        content: DialogBody(
          maxWidth: 560,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            for (var i = 0; i < labels.length; i++) ...[
              if (i > 0) const SizedBox(height: 14),
              TextField(controller: ctrls[labels[i]], maxLines: 2, minLines: 1, decoration: InputDecoration(labelText: titles[i])),
            ],
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          FilledButton(
            onPressed: () async {
              for (final k in labels) {
                remarks[k] = ctrls[k]!.text.trim();
              }
              await _save();
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) setState(() {});
              _msg('Appréciations enregistrées.');
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }

  // --- Bulletins scolaires -----------------------------------------------------

  List<GradeRecord> _reportGrades(Student s) {
    final byId = {for (final a in assessments) a.id: a};
    final list = grades.where((g) {
      final a = byId[g.assessmentId];
      return g.studentId == s.id && a != null && a.level == s.level && a.group == s.group;
    }).toList();
    list.sort((x, y) {
      final ax = byId[x.assessmentId]!;
      final ay = byId[y.assessmentId]!;
      final c = ax.date.compareTo(ay.date);
      return c != 0 ? c : ax.title.compareTo(ay.title);
    });
    return list;
  }

  /// Rang de l'élève dans son niveau et son groupe, et effectif de ce groupe.
  (int, int) _classRank(Student s) {
    final mates = students.where((x) => x.level == s.level && x.group == s.group).toList();
    final mine = _average(s);
    var rank = 1;
    for (final m in mates) {
      if (m.id != s.id && _average(m) > mine) rank++;
    }
    return (rank, mates.length);
  }

  /// Absences, retards et absences excusées de l'élève.
  (int, int, int) _attendanceCounts(Student s) {
    var absent = 0, late = 0, excused = 0;
    for (final r in attendance) {
      if (r.studentId != s.id) continue;
      if (r.status == 'Absent') {
        absent++;
      } else if (r.status == 'Retard') {
        late++;
      } else if (r.status == 'Excusé') {
        excused++;
      }
    }
    return (absent, late, excused);
  }

  ReportCardData _defaultReportData(
    Student s, {
    required String school,
    required String year,
    required String period,
    required String teacher,
    required String date,
  }) {
    final avg = _average(s);
    final rk = _classRank(s);
    final att = _attendanceCounts(s);
    final lines = <ReportLine>[];
    for (final g in _reportGrades(s)) {
      final a = _assessment(g.assessmentId);
      if (a == null) continue;
      lines.add(ReportLine(title: a.title, category: a.category, date: a.date, score: g.score, max: a.maxScore));
    }
    return ReportCardData(
      schoolName: school,
      schoolYear: year,
      period: period,
      teacher: teacher,
      studentName: s.name,
      level: s.level,
      group: s.group,
      lines: lines,
      average: avg,
      letter: _letterGrade(avg),
      rank: rk.$1,
      classSize: rk.$2,
      absences: att.$1,
      lates: att.$2,
      excused: att.$3,
      appreciation: _remark(avg),
      observation: '',
      date: date,
    );
  }

  Future<void> _printReports(List<ReportCardData> cards, String baseName) async {
    try {
      final bytes = await PdfService.buildReportCards(cards);
      await Printing.layoutPdf(name: FileNameService.safe(baseName), onLayout: (_) async => bytes);
    } catch (e) {
      _msg('Impossible de générer le PDF : $e', error: true);
    }
  }

  /// Bulletin d'un élève : tous les champs sont modifiables avant l'impression.
  Future<void> _showReport(Student s) async {
    final school = TextEditingController(text: schoolInfo['name'] ?? '');
    final year = TextEditingController(text: schoolInfo['year'] ?? '');
    final period = TextEditingController(text: 'Bilan général');
    final teacher = TextEditingController(text: schoolInfo['teacher'] ?? '');
    final base = _defaultReportData(s, school: '', year: '', period: '', teacher: '', date: _todayIso());
    final appreciation = TextEditingController(text: base.appreciation);
    final observation = TextEditingController();
    final absences = TextEditingController(text: '${base.absences}');
    final lates = TextEditingController(text: '${base.lates}');
    final excusedCtrl = TextEditingController(text: '${base.excused}');
    final relevant = _reportGrades(s);
    final scoreCtrls = {for (final g in relevant) g.assessmentId: TextEditingController(text: _fmtNum(g.score))};
    final excluded = <String>{};
    DateTime date = DateTime.now();
    String? error;

    double liveAverage() {
      var total = 0.0;
      var n = 0;
      for (final g in relevant) {
        if (excluded.contains(g.assessmentId)) continue;
        final a = _assessment(g.assessmentId);
        final v = _parseNumber(scoreCtrls[g.assessmentId]!.text);
        if (a == null || v == null) continue;
        if (a.maxScore > 0) total += v / a.maxScore * 100;
        n++;
      }
      return n == 0 ? 0 : total / n;
    }

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) {
          final avg = liveAverage();
          return AlertDialog(
            title: Text('Bulletin : ${s.name}'),
            content: DialogBody(
              maxWidth: 620,
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text('${s.level} · ${s.group}', style: const TextStyle(color: AppColors.muted)),
                const SizedBox(height: 14),
                TextField(controller: school, decoration: const InputDecoration(labelText: 'Établissement (en-tête)')),
                const SizedBox(height: 12),
                TextField(controller: year, decoration: const InputDecoration(labelText: 'Année scolaire')),
                const SizedBox(height: 12),
                TextField(controller: period, decoration: const InputDecoration(labelText: 'Période (ex. 1er trimestre)')),
                const SizedBox(height: 12),
                TextField(controller: teacher, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Titulaire / enseignant(e)')),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_month, color: AppColors.redSoft),
                  title: Text('Date du bulletin : ${_fmtDate(_isoFromDate(date))}'),
                  subtitle: const Text('Appuyez pour modifier', style: TextStyle(color: AppColors.muted)),
                  onTap: () async {
                    final picked = await showDatePicker(context: ctx, initialDate: date, firstDate: DateTime(2020), lastDate: DateTime(2100));
                    if (picked != null) setD(() => date = picked);
                  },
                ),
                const Divider(height: 24),
                const Text('Notes à afficher', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                const Text(
                  'Vous pouvez corriger une note ou décocher une évaluation : cela ne modifie que ce bulletin.',
                  style: TextStyle(color: AppColors.muted, fontSize: 13),
                ),
                const SizedBox(height: 8),
                if (relevant.isEmpty)
                  const Text('Aucune note enregistrée pour cet élève.', style: TextStyle(color: AppColors.muted))
                else
                  for (final g in relevant)
                    Builder(builder: (_) {
                      final a = _assessment(g.assessmentId)!;
                      final included = !excluded.contains(g.assessmentId);
                      return Row(children: [
                        Checkbox(
                          value: included,
                          onChanged: (v) => setD(() {
                            if (v == true) {
                              excluded.remove(g.assessmentId);
                            } else {
                              excluded.add(g.assessmentId);
                            }
                          }),
                        ),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(a.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                            Text(a.category, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                          ]),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 112,
                          child: TextField(
                            controller: scoreCtrls[g.assessmentId],
                            enabled: included,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            onChanged: (_) => setD(() {}),
                            decoration: InputDecoration(labelText: 'Note', suffixText: '/ ${_fmtNum(a.maxScore)}'),
                          ),
                        ),
                      ]);
                    }),
                const SizedBox(height: 12),
                AppCard(
                  margin: EdgeInsets.zero,
                  highlight: true,
                  child: Text(
                    'Moyenne : ${avg.toStringAsFixed(2)} / 100 · ${(avg / 5).toStringAsFixed(2)} / 20 · Lettre ${_letterGrade(avg)}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(child: TextField(controller: absences, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Absences'))),
                  const SizedBox(width: 8),
                  Expanded(child: TextField(controller: lates, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Retards'))),
                  const SizedBox(width: 8),
                  Expanded(child: TextField(controller: excusedCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Excusées'))),
                ]),
                const SizedBox(height: 14),
                TextField(
                  controller: appreciation,
                  maxLines: 4,
                  minLines: 2,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(labelText: 'Appréciation générale'),
                ),
                TextButton.icon(
                  onPressed: () => setD(() => appreciation.text = _remark(avg)),
                  icon: const Icon(Icons.auto_fix_high),
                  label: const Text('Proposer selon la moyenne'),
                ),
                TextField(
                  controller: observation,
                  maxLines: 3,
                  minLines: 1,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(labelText: 'Observations (facultatif)'),
                ),
                if (error != null) ...[
                  const SizedBox(height: 10),
                  FormErrorText(error),
                ],
              ]),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fermer')),
              FilledButton.icon(
                onPressed: () async {
                  if (school.text.trim().isEmpty) {
                    setD(() => error = 'Indiquez le nom de l’établissement.');
                    return;
                  }
                  final lines = <ReportLine>[];
                  for (final g in relevant) {
                    if (excluded.contains(g.assessmentId)) continue;
                    final a = _assessment(g.assessmentId)!;
                    final v = _parseNumber(scoreCtrls[g.assessmentId]!.text);
                    if (v == null || v < 0 || v > a.maxScore) {
                      setD(() => error = 'Note invalide pour « ${a.title} » : entrez un nombre entre 0 et ${_fmtNum(a.maxScore)}.');
                      return;
                    }
                    lines.add(ReportLine(title: a.title, category: a.category, date: a.date, score: v, max: a.maxScore));
                  }
                  var total = 0.0;
                  for (final l in lines) {
                    if (l.max > 0) total += l.score / l.max * 100;
                  }
                  final finalAvg = lines.isEmpty ? 0.0 : total / lines.length;
                  final rk = _classRank(s);
                  setD(() => error = null);
                  schoolInfo['name'] = school.text.trim();
                  schoolInfo['year'] = year.text.trim();
                  schoolInfo['teacher'] = teacher.text.trim();
                  await _save();
                  await _printReports([
                    ReportCardData(
                      schoolName: school.text.trim(),
                      schoolYear: year.text.trim(),
                      period: period.text.trim().isEmpty ? 'Bilan général' : period.text.trim(),
                      teacher: teacher.text.trim(),
                      studentName: s.name,
                      level: s.level,
                      group: s.group,
                      lines: lines,
                      average: finalAvg,
                      letter: _letterGrade(finalAvg),
                      rank: rk.$1,
                      classSize: rk.$2,
                      absences: int.tryParse(absences.text.trim()) ?? 0,
                      lates: int.tryParse(lates.text.trim()) ?? 0,
                      excused: int.tryParse(excusedCtrl.text.trim()) ?? 0,
                      appreciation: appreciation.text.trim(),
                      observation: observation.text.trim(),
                      date: _isoFromDate(date),
                    ),
                  ], 'Bulletin_${s.name}');
                },
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text('Aperçu / PDF'),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Un seul PDF avec le bulletin de chaque élève d'un niveau et d'un groupe.
  Future<void> _showClassReports() async {
    if (students.isEmpty) {
      _msg('Ajoutez d’abord des élèves.', error: true);
      return;
    }
    final school = TextEditingController(text: schoolInfo['name'] ?? '');
    final year = TextEditingController(text: schoolInfo['year'] ?? '');
    final period = TextEditingController(text: 'Bilan général');
    final teacher = TextEditingController(text: schoolInfo['teacher'] ?? '');
    String level = levels.first, group = groups.first;
    DateTime date = DateTime.now();
    String? error;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) {
          final targets = students.where((x) => x.level == level && x.group == group).toList()
            ..sort((a, b) => a.name.compareTo(b.name));
          return AlertDialog(
            title: const Text('Bulletins de la classe'),
            content: DialogBody(
              maxWidth: 520,
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                _dropdown('Niveau', level, levels, (v) => setD(() => level = v)),
                const SizedBox(height: 12),
                _dropdown('Groupe', group, groups, (v) => setD(() => group = v)),
                const SizedBox(height: 8),
                Text('${targets.length} bulletin(s) à générer', style: const TextStyle(color: AppColors.muted)),
                const SizedBox(height: 12),
                TextField(controller: school, decoration: const InputDecoration(labelText: 'Établissement (en-tête)')),
                const SizedBox(height: 12),
                TextField(controller: year, decoration: const InputDecoration(labelText: 'Année scolaire')),
                const SizedBox(height: 12),
                TextField(controller: period, decoration: const InputDecoration(labelText: 'Période (ex. 1er trimestre)')),
                const SizedBox(height: 12),
                TextField(controller: teacher, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Titulaire / enseignant(e)')),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_month, color: AppColors.redSoft),
                  title: Text('Date des bulletins : ${_fmtDate(_isoFromDate(date))}'),
                  onTap: () async {
                    final picked = await showDatePicker(context: ctx, initialDate: date, firstDate: DateTime(2020), lastDate: DateTime(2100));
                    if (picked != null) setD(() => date = picked);
                  },
                ),
                if (error != null) FormErrorText(error),
              ]),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fermer')),
              FilledButton.icon(
                onPressed: targets.isEmpty
                    ? null
                    : () async {
                        if (school.text.trim().isEmpty) {
                          setD(() => error = 'Indiquez le nom de l’établissement.');
                          return;
                        }
                        setD(() => error = null);
                        schoolInfo['name'] = school.text.trim();
                        schoolInfo['year'] = year.text.trim();
                        schoolInfo['teacher'] = teacher.text.trim();
                        await _save();
                        final cards = [
                          for (final st in targets)
                            _defaultReportData(
                              st,
                              school: school.text.trim(),
                              year: year.text.trim(),
                              period: period.text.trim().isEmpty ? 'Bilan général' : period.text.trim(),
                              teacher: teacher.text.trim(),
                              date: _isoFromDate(date),
                            ),
                        ];
                        await _printReports(cards, 'Bulletins_${level}_$group');
                      },
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text('Aperçu / PDF'),
              ),
            ],
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Cours et préparations
  // ---------------------------------------------------------------------------

  Future<void> _addCourseSession() async {
    final title = TextEditingController();
    final place = TextEditingController();
    final note = TextEditingController();
    DateTime date = DateTime.now().add(const Duration(days: 1));
    TimeOfDay time = const TimeOfDay(hour: 9, minute: 0);
    bool reminder = true;
    String lead = _leadOptions.keys.first;
    String? titleError;

    String fmtTime(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('Planifier un cours'),
          content: DialogBody(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                controller: title,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(labelText: 'Titre / matière', errorText: titleError),
              ),
              const SizedBox(height: 14),
              TextField(controller: place, decoration: const InputDecoration(labelText: 'Salle / lieu')),
              const SizedBox(height: 14),
              TextField(controller: note, maxLines: 2, minLines: 1, decoration: const InputDecoration(labelText: 'Objectif ou note')),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_month, color: AppColors.redSoft),
                title: Text('Date : ${_fmtDate(_isoFromDate(date))}'),
                subtitle: const Text('Appuyez pour modifier', style: TextStyle(color: AppColors.muted)),
                onTap: () async {
                  final selected = await showDatePicker(
                    context: ctx,
                    initialDate: date,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                  );
                  if (selected != null) setD(() => date = selected);
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.schedule, color: AppColors.redSoft),
                title: Text('Heure : ${fmtTime(time)}'),
                subtitle: const Text('Appuyez pour modifier', style: TextStyle(color: AppColors.muted)),
                onTap: () async {
                  final selected = await showTimePicker(context: ctx, initialTime: time);
                  if (selected != null) setD(() => time = selected);
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: reminder,
                onChanged: (value) => setD(() => reminder = value),
                title: const Text('Créer un rappel avec notification sonore'),
              ),
              if (reminder) _dropdown('Me rappeler', lead, _leadOptions.keys.toList(), (v) => setD(() => lead = v)),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
            FilledButton(
              onPressed: () async {
                if (title.text.trim().isEmpty) {
                  setD(() => titleError = 'Saisissez le titre du cours.');
                  return;
                }
                final dateText = _isoFromDate(date);
                final timeText = fmtTime(time);
                final item = <String, dynamic>{
                  'id': _id(),
                  'title': title.text.trim(),
                  'place': place.text.trim(),
                  'time': timeText,
                  'note': note.text.trim(),
                  'date': dateText,
                  'reminder': reminder,
                  'done': false,
                };
                final newReminder = <String, dynamic>{
                  'id': _id(),
                  'title': 'Rappel : ${item['title']}',
                  'date': dateText,
                  'time': timeText,
                  'done': false,
                  'lead': _leadOptions[lead] ?? 0,
                };
                setState(() {
                  courseSessions.add(item);
                  if (reminder) reminders.add(newReminder);
                });
                await _save();
                if (reminder) {
                  await NotificationService.requestPermission();
                  await NotificationService.schedule(newReminder);
                }
                if (ctx.mounted) Navigator.pop(ctx);
                _msg('Cours ajouté au calendrier.');
              },
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }

  /// Importe un pack de contenu (questions + préparations de cours) sans remplacer les données :
  /// les éléments déjà présents (même énoncé / même titre) sont ignorés.
  Future<void> _importPack() async {
    final picked = await FilePicker.platform.pickFiles(
      dialogTitle: 'Choisir un pack DP (.json)',
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );
    if (picked == null || picked.files.isEmpty) return;
    final raw = picked.files.single.bytes;
    if (raw == null) {
      _msg('Impossible de lire ce fichier.', error: true);
      return;
    }
    Map<String, dynamic> data;
    try {
      data = Map<String, dynamic>.from(jsonDecode(utf8.decode(raw)) as Map);
    } catch (_) {
      _msg('Le fichier JSON est invalide ou endommagé.', error: true);
      return;
    }
    if (data['format'] != 'dp_pack') {
      _msg('Ce fichier n’est pas un pack DP (format « dp_pack » attendu).', error: true);
      return;
    }
    var addedQuestions = 0, addedPreparations = 0;
    try {
      for (final e in ((data['questions'] as List?) ?? [])) {
        final q = ExamQuestion.fromJson(Map<String, dynamic>.from(e as Map));
        if (q.prompt.trim().isEmpty) continue;
        if (questionBank.any((x) => x.prompt == q.prompt && x.category == q.category)) continue;
        q.imageFile = '';
        questionBank.add(q);
        addedQuestions++;
      }
      for (final e in ((data['preparations'] as List?) ?? [])) {
        final prep = Map<String, dynamic>.from(e as Map);
        final title = '${prep['title'] ?? ''}'.trim();
        if (title.isEmpty) continue;
        if (coursePreparations.any((x) => '${x['title']}' == title)) continue;
        prep['id'] = '${_id()}_$addedPreparations';
        prep['checks'] = [false, false, false, false];
        prep['created'] = DateTime.now().toIso8601String();
        coursePreparations.add(prep);
        addedPreparations++;
      }
    } catch (e) {
      _msg('Pack invalide : $e', error: true);
      return;
    }
    await _save();
    if (mounted) setState(() {});
    _msg('Pack importé : $addedQuestions question(s) et $addedPreparations préparation(s) ajoutée(s).');
  }

  // --- Rappels : notifications, son, alerte dans l'application -----------------

  Future<void> _startReminderEngine() async {
    try {
      await NotificationService.syncAll(reminders);
    } catch (_) {}
    // Pas de minuteur pendant les tests automatisés.
    if (Platform.environment.containsKey('FLUTTER_TEST')) return;
    _reminderTimer?.cancel();
    _reminderTimer = Timer.periodic(const Duration(seconds: 20), (_) => _checkDueReminders());
    _checkDueReminders();
  }

  /// Affiche une alerte (avec bip hors Android) quand un rappel arrive à échéance.
  Future<void> _checkDueReminders() async {
    if (!mounted || _alertOpen || loading) return;
    final now = DateTime.now();
    for (final r in reminders) {
      if (r['done'] == true) continue;
      final id = '${r['id']}';
      if (_alerted.contains(id)) continue;
      final due = NotificationService.dueTime(r);
      if (due == null || now.isBefore(due)) continue;
      _alerted.add(id);
      // Rappel trop ancien : on ne le rejoue pas, il reste visible dans la liste.
      if (now.difference(due) > const Duration(minutes: 10)) continue;
      _alertOpen = true;
      if (!NotificationService.supported) {
        await SystemSound.play(SystemSoundType.alert);
      }
      if (!mounted) return;
      final finished = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(children: [
            Icon(Icons.notifications_active, color: AppColors.redSoft),
            SizedBox(width: 10),
            Expanded(child: Text('Rappel')),
          ]),
          content: Text('${r['title'] ?? 'Rappel'}\n${_fmtDate('${r['date'] ?? ''}')} · ${r['time'] ?? ''}'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Plus tard')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Terminé')),
          ],
        ),
      );
      _alertOpen = false;
      if (finished == true) {
        setState(() => r['done'] = true);
        await _save();
        await NotificationService.cancel(r);
      }
      return;
    }
  }

  Future<void> _testReminderSound() async {
    if (NotificationService.supported) {
      final ok = await NotificationService.requestPermission();
      if (!ok) {
        _msg('Autorisez les notifications pour DP dans les paramètres Android.', error: true);
        return;
      }
      await NotificationService.showNow('Rappel DP', 'Test : vous devez entendre un son et sentir une vibration.');
      _msg('Notification de test envoyée. Si vous n’entendez rien, vérifiez le volume des notifications et le mode Ne pas déranger.');
    } else {
      await SystemSound.play(SystemSoundType.alert);
      _msg('Bip de test joué. Sur Windows, les rappels s’affichent dans DP lorsque l’application est ouverte.');
    }
  }

  Future<void> _addReminder() async {
    final title = TextEditingController();
    DateTime date = DateTime.now();
    TimeOfDay time = TimeOfDay.fromDateTime(DateTime.now().add(const Duration(hours: 1)));
    String lead = _leadOptions.keys.first;
    String? titleError;
    String fmtTime(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('Nouveau rappel'),
          content: DialogBody(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                controller: title,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(labelText: 'Rappel', errorText: titleError),
              ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_month, color: AppColors.redSoft),
                title: Text('Date : ${_fmtDate(_isoFromDate(date))}'),
                onTap: () async {
                  final picked = await showDatePicker(context: ctx, initialDate: date, firstDate: DateTime(2020), lastDate: DateTime(2100));
                  if (picked != null) setD(() => date = picked);
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.schedule, color: AppColors.redSoft),
                title: Text('Heure : ${fmtTime(time)}'),
                onTap: () async {
                  final picked = await showTimePicker(context: ctx, initialTime: time);
                  if (picked != null) setD(() => time = picked);
                },
              ),
              const SizedBox(height: 6),
              _dropdown('Me rappeler', lead, _leadOptions.keys.toList(), (v) => setD(() => lead = v)),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
            FilledButton(
              onPressed: () async {
                if (title.text.trim().isEmpty) {
                  setD(() => titleError = 'Saisissez le texte du rappel.');
                  return;
                }
                final reminder = <String, dynamic>{
                  'id': _id(),
                  'title': title.text.trim(),
                  'date': _isoFromDate(date),
                  'time': fmtTime(time),
                  'done': false,
                  'lead': _leadOptions[lead] ?? 0,
                };
                setState(() => reminders.add(reminder));
                await _save();
                await NotificationService.requestPermission();
                await NotificationService.schedule(reminder);
                if (ctx.mounted) Navigator.pop(ctx);
                _msg('Rappel enregistré.');
              },
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addPreparation() async {
    final title = TextEditingController();
    final objective = TextEditingController();
    final materials = TextEditingController();
    final steps = TextEditingController();
    String? titleError;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('Préparer un cours'),
          content: DialogBody(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                controller: title,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(labelText: 'Titre du cours', errorText: titleError),
              ),
              const SizedBox(height: 14),
              TextField(controller: objective, decoration: const InputDecoration(labelText: 'Objectif pédagogique')),
              const SizedBox(height: 14),
              TextField(controller: materials, decoration: const InputDecoration(labelText: 'Matériel requis')),
              const SizedBox(height: 14),
              TextField(controller: steps, maxLines: 3, minLines: 2, decoration: const InputDecoration(labelText: 'Étapes / déroulement')),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
            FilledButton(
              onPressed: () async {
                if (title.text.trim().isEmpty) {
                  setD(() => titleError = 'Saisissez le titre du cours.');
                  return;
                }
                setState(() => coursePreparations.add({
                      'id': _id(),
                      'title': title.text.trim(),
                      'objective': objective.text.trim(),
                      'materials': materials.text.trim(),
                      'steps': steps.text.trim(),
                      'checks': [false, false, false, false],
                      'created': DateTime.now().toIso8601String(),
                    }));
                await _save();
                if (ctx.mounted) Navigator.pop(ctx);
                _msg('Préparation créée.');
              },
              child: const Text('Créer la préparation'),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Pages
  // ---------------------------------------------------------------------------

  Widget _page() {
    if (loading) {
      return const Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Chargement des données…', style: TextStyle(color: AppColors.muted)),
        ]),
      );
    }
    switch (tab) {
      case 0:
        return _dashboard();
      case 1:
        return _studentsPage();
      case 2:
        return _levelsPage();
      case 3:
        return _attendancePage();
      case 4:
        return _assessmentsPage();
      case 5:
        return _examsPage();
      case 6:
        return _reportsPage();
      case 7:
        return _courseCalendarPage();
      case 8:
        return _coursePreparationPage();
      default:
        return _dashboard();
    }
  }

  Widget _dashboard() {
    final ranked = _rankedStudents();
    final upcoming = _upcomingSessions();
    final pending = reminders.where((r) => r['done'] != true).length;
    return PageScroll(children: [
      AppCard(
        highlight: true,
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: AppColors.red, borderRadius: BorderRadius.circular(16)),
            child: const Icon(Icons.school, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Bon retour !', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              Text('DP · ${_fmtDate(_todayIso())}', style: const TextStyle(color: AppColors.muted)),
            ]),
          ),
          IconButton(
            onPressed: () => setState(() => tab = 7),
            tooltip: 'Calendrier des cours et rappels',
            icon: Badge(
              isLabelVisible: pending > 0,
              label: Text('$pending'),
              child: const Icon(Icons.notifications_active_outlined, color: AppColors.redSoft),
            ),
          ),
        ]),
      ),
      const SizedBox(height: 6),
      LayoutBuilder(builder: (context, box) {
        final count = box.maxWidth < 260 ? 1 : (box.maxWidth < 700 ? 2 : 4);
        final width = ((box.maxWidth - 12 * (count - 1)) / count).floorToDouble();
        return Wrap(spacing: 12, runSpacing: 12, children: [
          MetricTile(label: 'Élèves', value: '${students.length}', icon: Icons.people_alt, width: width),
          MetricTile(label: 'Niveaux', value: '${levels.length}', icon: Icons.school, width: width),
          MetricTile(label: 'Groupes', value: '${groups.length}', icon: Icons.groups, width: width),
          MetricTile(label: 'Évaluations', value: '${assessments.length}', icon: Icons.fact_check, width: width),
        ]);
      }),
      const SizedBox(height: 12),
      const SectionTitle('Actions rapides', icon: Icons.bolt),
      LayoutBuilder(builder: (context, box) {
        final count = box.maxWidth < 300 ? 1 : (box.maxWidth < 700 ? 2 : 3);
        final width = ((box.maxWidth - 10 * (count - 1)) / count).floorToDouble();
        return Wrap(spacing: 10, runSpacing: 10, children: [
          ActionTile(label: 'Ajouter un élève', icon: Icons.person_add_alt_1, onTap: _addStudent, width: width),
          ActionTile(label: 'Faire l’appel', icon: Icons.fact_check_outlined, onTap: () => setState(() => tab = 3), width: width),
          ActionTile(label: 'Planifier un cours', icon: Icons.calendar_month, onTap: _addCourseSession, width: width),
          ActionTile(label: 'Préparer un cours', icon: Icons.menu_book_outlined, onTap: _addPreparation, width: width),
          ActionTile(label: 'Créer une évaluation', icon: Icons.assignment_outlined, onTap: () => _addAssessment(), width: width),
          ActionTile(label: 'Sauvegarder', icon: Icons.backup_outlined, onTap: _exportBackup, width: width),
        ]);
      }),
      const SizedBox(height: 16),
      const SectionTitle('Moyennes des élèves · sur 100', icon: Icons.show_chart),
      AppCard(
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
        child: TrendChart(values: ranked.take(8).map((e) => _average(e.$1)).toList()),
      ),
      const SizedBox(height: 8),
      const SectionTitle('Classement par élève', icon: Icons.emoji_events_outlined),
      if (students.isEmpty)
        const EmptyState(
          icon: Icons.emoji_events_outlined,
          title: 'Pas encore de classement',
          message: 'Ajoutez des élèves et saisissez leurs notes pour générer le classement.',
        )
      else
        ...ranked.take(10).map((e) {
          final avg = _average(e.$1);
          return AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(children: [
              RankBadge(e.$2),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(e.$1.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text('${e.$1.level} · ${e.$1.group}', style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                ]),
              ),
              const SizedBox(width: 8),
              Text('${avg.toStringAsFixed(1)}%', style: const TextStyle(color: AppColors.redSoft, fontWeight: FontWeight.w800)),
            ]),
          );
        }),
      const SizedBox(height: 8),
      const SectionTitle('Prochains cours et rappels', icon: Icons.notifications_active_outlined),
      if (upcoming.isEmpty)
        EmptyState(
          icon: Icons.event_available_outlined,
          title: 'Aucun cours planifié',
          message: 'Ajoutez une séance dans le calendrier.',
          action: OutlinedButton.icon(onPressed: _addCourseSession, icon: const Icon(Icons.add), label: const Text('Planifier un cours')),
        )
      else
        ...upcoming.take(3).map((e) => _sessionTile(e)),
      AppCard(
        onTap: () => setState(() => tab = 7),
        child: Row(children: [
          const Icon(Icons.notifications, color: AppColors.redSoft),
          const SizedBox(width: 12),
          Expanded(child: Text('$pending rappel(s) à faire · ${reminders.length} enregistré(s)', style: const TextStyle(color: AppColors.muted))),
          const Icon(Icons.chevron_right, color: AppColors.muted),
        ]),
      ),
    ]);
  }

  static const List<String> _months = ['JAN', 'FÉV', 'MAR', 'AVR', 'MAI', 'JUN', 'JUL', 'AOÛ', 'SEP', 'OCT', 'NOV', 'DÉC'];

  Widget _sessionTile(Map<String, dynamic> session, {bool actions = false}) {
    final done = session['done'] == true;
    final dateStr = (session['date'] ?? '').toString();
    final d = DateTime.tryParse(dateStr);
    final place = (session['place'] ?? '').toString().trim();
    final note = (session['note'] ?? '').toString().trim();
    final time = (session['time'] ?? '').toString().trim();
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 52,
            height: 58,
            decoration: BoxDecoration(
              color: done ? AppColors.panelHigh : AppColors.red,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(d == null ? '--' : '${d.day}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              Text(d == null ? '' : _months[d.month - 1], style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
            ]),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${session['title'] ?? 'Cours'}', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 2),
              Text('${_fmtDate(dateStr)}${time.isEmpty ? '' : ' · $time'}', style: const TextStyle(color: AppColors.muted)),
              Text(place.isEmpty ? 'Lieu à préciser' : place, style: const TextStyle(color: AppColors.muted)),
              if (note.isNotEmpty) Text(note, style: const TextStyle(color: AppColors.muted)),
              if (done)
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: StatusPill(label: 'Terminé', color: AppColors.success, icon: Icons.check_circle_outline),
                ),
            ]),
          ),
        ]),
        if (actions) ...[
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 4, children: [
            TextButton.icon(
              onPressed: () async {
                setState(() => session['done'] = !(session['done'] == true));
                await _save();
              },
              icon: Icon(done ? Icons.undo : Icons.check_circle_outline),
              label: Text(done ? 'Rouvrir' : 'Marquer terminé'),
            ),
            TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: AppColors.danger),
              onPressed: () => _deleteSession(session),
              icon: const Icon(Icons.delete_outline),
              label: const Text('Supprimer'),
            ),
          ]),
        ],
      ]),
    );
  }

  Future<void> _deleteSession(Map<String, dynamic> session) async {
    final ok = await confirmDialog(
      context,
      title: 'Supprimer cette séance ?',
      message: '${session['title'] ?? 'Cours'} · ${_fmtDate((session['date'] ?? '').toString())}',
      confirmLabel: 'Supprimer',
      destructive: true,
    );
    if (!ok) return;
    setState(() => courseSessions.removeWhere((x) => x['id'] == session['id']));
    await _save();
  }

  Widget _studentsPage() {
    final q = _studentQuery.trim().toLowerCase();
    final filtered = q.isEmpty
        ? students
        : students.where((s) => s.name.toLowerCase().contains(q) || s.level.toLowerCase().contains(q) || s.group.toLowerCase().contains(q)).toList();
    return PageScroll(children: [
      PageHeader(
        title: 'Élèves',
        subtitle: '${students.length} élève(s) enregistré(s)',
        actions: [FilledButton.icon(onPressed: _addStudent, icon: const Icon(Icons.add), label: const Text('Ajouter un élève'))],
      ),
      if (students.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TextField(
            key: const ValueKey('student_search'),
            controller: _studentSearch,
            onChanged: (v) => setState(() => _studentQuery = v),
            decoration: InputDecoration(
              hintText: 'Rechercher un nom, un niveau ou un groupe',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _studentQuery.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Effacer la recherche',
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        _studentSearch.clear();
                        setState(() => _studentQuery = '');
                      },
                    ),
            ),
          ),
        ),
      if (students.isEmpty)
        EmptyState(
          icon: Icons.people_outline,
          title: 'Aucun élève',
          message: 'Ajoutez votre premier élève pour commencer.',
          action: FilledButton.icon(onPressed: _addStudent, icon: const Icon(Icons.add), label: const Text('Ajouter un élève')),
        )
      else if (filtered.isEmpty)
        const EmptyState(icon: Icons.search_off, title: 'Aucun résultat', message: 'Aucun élève ne correspond à votre recherche.')
      else
        ...filtered.map((s) {
          final avg = _average(s);
          return AppCard(
            padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
            child: Row(children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.redTint,
                child: Text(_initials(s.name), style: const TextStyle(color: AppColors.redSoft, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(s.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  Text('${s.level} · ${s.group}', style: const TextStyle(color: AppColors.muted)),
                  Text('Moyenne ${avg.toStringAsFixed(1)}/100 · Lettre ${_letterGrade(avg)}', style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                ]),
              ),
              IconButton(tooltip: 'Bulletin PDF de ${s.name}', onPressed: () => _showReport(s), icon: const Icon(Icons.picture_as_pdf_outlined)),
              IconButton(
                tooltip: 'Supprimer ${s.name}',
                onPressed: () async {
                  final ok = await confirmDialog(
                    context,
                    title: 'Supprimer cet élève ?',
                    message: s.name,
                    confirmLabel: 'Supprimer',
                    destructive: true,
                  );
                  if (ok) {
                    setState(() => students.removeWhere((x) => x.id == s.id));
                    await _save();
                  }
                },
                icon: const Icon(Icons.delete_outline),
              ),
            ]),
          );
        }),
    ]);
  }

  Widget _nameRow(String name, int count, VoidCallback onDelete, String deleteTooltip) {
    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 8, 6, 8),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            Text('$count élève(s)', style: const TextStyle(color: AppColors.muted, fontSize: 13)),
          ]),
        ),
        IconButton(tooltip: deleteTooltip, icon: const Icon(Icons.delete_outline), onPressed: onDelete),
      ]),
    );
  }

  Widget _levelsPage() => PageScroll(children: [
        PageHeader(
          title: 'Niveaux et groupes',
          subtitle: 'Organisez vos élèves par niveau et par groupe.',
          actions: [
            FilledButton.icon(
              onPressed: () => _textDialog('Créer un niveau', 'Nom du niveau', (v) async {
                if (levels.contains(v)) return 'Ce niveau existe déjà.';
                setState(() => levels.add(v));
                await _save();
                return null;
              }),
              icon: const Icon(Icons.add),
              label: const Text('Créer un niveau'),
            ),
            OutlinedButton.icon(
              onPressed: () => _textDialog('Créer un groupe', 'Nom du groupe', (v) async {
                if (groups.contains(v)) return 'Ce groupe existe déjà.';
                setState(() => groups.add(v));
                await _save();
                return null;
              }),
              icon: const Icon(Icons.group_add),
              label: const Text('Créer un groupe'),
            ),
          ],
        ),
        const SectionTitle('Niveaux', icon: Icons.school),
        ...levels.map((x) => _nameRow(x, students.where((s) => s.level == x).length, () async {
              if (levels.length > 1 && !students.any((s) => s.level == x)) {
                final ok = await confirmDialog(context, title: 'Supprimer ce niveau ?', message: x, confirmLabel: 'Supprimer', destructive: true);
                if (ok) {
                  setState(() => levels.remove(x));
                  await _save();
                }
              } else {
                _msg('Niveau utilisé par un élève ou dernier niveau.', error: true);
              }
            }, 'Supprimer le niveau $x')),
        const SizedBox(height: 8),
        const SectionTitle('Groupes', icon: Icons.groups),
        ...groups.map((x) => _nameRow(x, students.where((s) => s.group == x).length, () async {
              if (groups.length > 1 && !students.any((s) => s.group == x)) {
                final ok = await confirmDialog(context, title: 'Supprimer ce groupe ?', message: x, confirmLabel: 'Supprimer', destructive: true);
                if (ok) {
                  setState(() => groups.remove(x));
                  await _save();
                }
              } else {
                _msg('Groupe utilisé par un élève ou dernier groupe.', error: true);
              }
            }, 'Supprimer le groupe $x')),
      ]);

  Widget _attendancePage() {
    final records = attendance.reversed.toList();
    return PageScroll(children: [
      PageHeader(
        title: 'Présences et retards',
        subtitle: 'Appel du jour : ${_fmtDate(_todayIso())}',
        actions: [FilledButton.icon(onPressed: _markAttendance, icon: const Icon(Icons.fact_check), label: const Text('Faire l’appel'))],
      ),
      if (records.isEmpty)
        EmptyState(
          icon: Icons.fact_check_outlined,
          title: 'Aucun appel enregistré',
          message: 'Faites l’appel pour suivre les présences, retards et absences.',
          action: FilledButton.icon(onPressed: _markAttendance, icon: const Icon(Icons.fact_check), label: const Text('Faire l’appel')),
        )
      else
        ...records.map((a) {
          final s = _student(a.studentId);
          return AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(s?.name ?? 'Élève supprimé', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text(_fmtDate(a.date), style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                ]),
              ),
              const SizedBox(width: 8),
              StatusPill(label: _statusLabel(a.status), color: _statusColor(a.status), icon: _statusIcon(a.status)),
            ]),
          );
        }),
    ]);
  }

  Widget _assessmentsPage() => PageScroll(children: [
        PageHeader(
          title: 'Évaluations et notes',
          subtitle: '${assessments.length} évaluation(s)',
          actions: [
            FilledButton.icon(onPressed: () => _addAssessment(category: 'Devoir'), icon: const Icon(Icons.assignment_outlined), label: const Text('Nouveau devoir')),
            OutlinedButton.icon(onPressed: () => _addAssessment(category: 'Examen'), icon: const Icon(Icons.quiz_outlined), label: const Text('Examen')),
            OutlinedButton.icon(onPressed: () => _addAssessment(category: 'Participation'), icon: const Icon(Icons.record_voice_over_outlined), label: const Text('Participation')),
          ],
        ),
        if (assessments.isEmpty)
          const EmptyState(
            icon: Icons.grade_outlined,
            title: 'Aucune évaluation',
            message: 'Créez un devoir, un examen ou une participation pour saisir des notes.',
          )
        else
          ...assessments.map((a) {
            final matching = students.where((s) => s.level == a.level && s.group == a.group).length;
            final entered = grades.where((g) => g.assessmentId == a.id).length;
            return AppCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: Text(a.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
                  IconButton(tooltip: 'Supprimer ${a.title}', icon: const Icon(Icons.delete_outline), onPressed: () => _deleteAssessment(a)),
                ]),
                Text('${a.category} · ${a.level} / ${a.group}', style: const TextStyle(color: AppColors.muted)),
                Text('Note maximale ${_fmtNum(a.maxScore)} · ${_fmtDate(a.date)}', style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                Text('$entered / $matching note(s) saisie(s)', style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                const SizedBox(height: 10),
                FilledButton.icon(onPressed: () => _enterGrades(a), icon: const Icon(Icons.edit_note), label: const Text('Saisir les notes')),
              ]),
            );
          }),
      ]);

  Widget _examsPage() => PageScroll(children: [
        PageHeader(
          title: 'Examens et banque de questions',
          subtitle: '${questionBank.length} question(s) dans la banque',
          actions: [
            FilledButton.icon(onPressed: _addQuestion, icon: const Icon(Icons.add), label: const Text('Ajouter une question')),
            OutlinedButton.icon(onPressed: _generateExam, icon: const Icon(Icons.auto_awesome), label: const Text('Générer un examen')),
            OutlinedButton.icon(onPressed: _importPack, icon: const Icon(Icons.upload_file), label: const Text('Importer un pack')),
          ],
        ),
        if (questionBank.isEmpty)
          const EmptyState(
            icon: Icons.quiz_outlined,
            title: 'La banque est vide',
            message: 'Ajoutez vos questions pour pouvoir générer un examen.',
          )
        else
          ...questionBank.map((q) => AppCard(
                padding: const EdgeInsets.fromLTRB(16, 12, 6, 12),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(q.prompt, style: const TextStyle(fontWeight: FontWeight.w700)),
                      if (q.imageFile.isNotEmpty)
                        Padding(padding: const EdgeInsets.only(top: 8), child: _questionImage(q.imageFile, height: 110)),
                      const SizedBox(height: 4),
                      Text('${q.category} · ${_fmtNum(q.points)} point(s)', style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                      if (q.hasChoices)
                        for (var i = 0; i < q.choices.length; i++)
                          Text(
                            '${_choiceLabel(i)}. ${q.choices[i]}',
                            style: TextStyle(
                              color: q.correctIndexes.contains(i) ? AppColors.success : AppColors.muted,
                              fontWeight: q.correctIndexes.contains(i) ? FontWeight.w700 : FontWeight.normal,
                              fontSize: 13,
                            ),
                          )
                      else if (q.answer.isNotEmpty)
                        Text('Réponse : ${q.answer}', style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                    ]),
                  ),
                  Column(children: [
                    IconButton(tooltip: 'Modifier la question', icon: const Icon(Icons.edit_outlined), onPressed: () => _editQuestion(existing: q)),
                    IconButton(tooltip: 'Supprimer la question', icon: const Icon(Icons.delete_outline), onPressed: () => _deleteQuestion(q)),
                  ]),
                ]),
              )),
      ]);

  Widget _reportsPage() => PageScroll(children: [
        PageHeader(
          title: 'Rapports et classement',
          subtitle: 'La moyenne est calculée à partir des évaluations notées disponibles. Appuyez sur un élève pour préparer, modifier et imprimer son bulletin.',
          actions: [
            FilledButton.icon(onPressed: _exportCsv, icon: const Icon(Icons.table_view), label: const Text('Exporter le palmarès CSV')),
            FilledButton.icon(onPressed: _showClassReports, icon: const Icon(Icons.library_books_outlined), label: const Text('Bulletins de la classe')),
            OutlinedButton.icon(onPressed: _editRemarks, icon: const Icon(Icons.edit_note), label: const Text('Modifier les appréciations')),
            OutlinedButton.icon(onPressed: _exportBackup, icon: const Icon(Icons.download), label: const Text('Exporter sauvegarde JSON')),
            OutlinedButton.icon(onPressed: _importBackup, icon: const Icon(Icons.file_open_outlined), label: const Text('Importer une sauvegarde')),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger, side: const BorderSide(color: AppColors.danger)),
              onPressed: _clearHistory,
              icon: const Icon(Icons.delete_forever),
              label: const Text('Effacer l’historique'),
            ),
          ],
        ),
        const SectionTitle('Palmarès selon la moyenne', icon: Icons.emoji_events_outlined),
        if (students.isEmpty)
          const EmptyState(icon: Icons.emoji_events_outlined, title: 'Pas de palmarès', message: 'Ajoutez des élèves pour calculer le palmarès.')
        else
          ..._rankedStudents().map((e) {
            final s = e.$1;
            final rank = e.$2;
            final avg = _average(s);
            return AppCard(
              onTap: () => _showReport(s),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                RankBadge(rank),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(s.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                    Text('${s.level} · ${s.group} · Lettre ${_letterGrade(avg)}', style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                    const SizedBox(height: 2),
                    Text(_remark(avg), style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                  ]),
                ),
                const SizedBox(width: 8),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('${avg.toStringAsFixed(2)} /100', style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text(rank == 1 ? '1er' : '$rank' 'e', style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                  const SizedBox(height: 4),
                  const Icon(Icons.picture_as_pdf_outlined, size: 20, color: AppColors.redSoft),
                ]),
              ]),
            );
          }),
      ]);

  Widget _courseCalendarPage() {
    final upcoming = _upcomingSessions();
    final past = _pastSessions();
    return PageScroll(children: [
      PageHeader(
        title: 'Calendrier des cours',
        subtitle: 'Planifiez les séances et gardez le lieu, l’heure et les objectifs au même endroit.',
        actions: [
          FilledButton.icon(onPressed: _addCourseSession, icon: const Icon(Icons.add), label: const Text('Ajouter un cours')),
          OutlinedButton.icon(onPressed: _addReminder, icon: const Icon(Icons.add_alert_outlined), label: const Text('Nouveau rappel')),
          OutlinedButton.icon(onPressed: _testReminderSound, icon: const Icon(Icons.volume_up_outlined), label: const Text('Tester le son')),
        ],
      ),
      const SectionTitle('Séances à venir', icon: Icons.event_note),
      if (upcoming.isEmpty)
        const EmptyState(icon: Icons.event_available_outlined, title: 'Aucune séance à venir', message: 'Les séances planifiées apparaîtront ici.')
      else
        ...upcoming.map((s) => _sessionTile(s, actions: true)),
      if (past.isNotEmpty) ...[
        const SizedBox(height: 8),
        const SectionTitle('Séances passées', icon: Icons.history),
        ...past.map((s) => _sessionTile(s, actions: true)),
      ],
      const SizedBox(height: 8),
      const SectionTitle('Rappels', icon: Icons.notifications_active),
      if (reminders.isEmpty)
        const EmptyState(icon: Icons.notifications_none, title: 'Aucun rappel', message: 'Les rappels ajoutés lors de la planification apparaîtront ici.')
      else
        ...reminders.map((r) => AppCard(
              padding: const EdgeInsets.fromLTRB(4, 4, 6, 4),
              child: Row(children: [
                Expanded(
                  child: CheckboxListTile(
                    value: r['done'] == true,
                    contentPadding: const EdgeInsets.only(left: 12),
                    controlAffinity: ListTileControlAffinity.leading,
                    onChanged: (value) async {
                      setState(() => r['done'] = value == true);
                      await _save();
                      if (value == true) {
                        await NotificationService.cancel(r);
                      } else {
                        _alerted.remove('${r['id']}');
                        await NotificationService.schedule(r);
                      }
                    },
                    title: Text('${r['title'] ?? 'Rappel'}'),
                    subtitle: Text('${_fmtDate((r['date'] ?? '').toString())}${(r['time'] ?? '').toString().isEmpty ? '' : ' · ${r['time']}'}', style: const TextStyle(color: AppColors.muted)),
                  ),
                ),
                IconButton(
                  tooltip: 'Supprimer le rappel',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    final ok = await confirmDialog(context, title: 'Supprimer ce rappel ?', message: '${r['title'] ?? 'Rappel'}', confirmLabel: 'Supprimer', destructive: true);
                    if (ok) {
                      await NotificationService.cancel(r);
                      setState(() => reminders.removeWhere((x) => x['id'] == r['id']));
                      await _save();
                    }
                  },
                ),
              ]),
            )),
    ]);
  }

  Widget _labeled(String label, String value) => Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text.rich(TextSpan(children: [
          TextSpan(text: '$label : ', style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w700)),
          TextSpan(text: value),
        ])),
      );

  Widget _coursePreparationPage() => PageScroll(children: [
        PageHeader(
          title: 'Préparation des cours',
          subtitle: 'Préparez les objectifs, le matériel et les étapes avant la séance.',
          actions: [
            FilledButton.icon(onPressed: _addPreparation, icon: const Icon(Icons.add), label: const Text('Préparer un cours')),
            OutlinedButton.icon(onPressed: _importPack, icon: const Icon(Icons.upload_file), label: const Text('Importer un pack')),
          ],
        ),
        if (coursePreparations.isEmpty)
          EmptyState(
            icon: Icons.menu_book_outlined,
            title: 'Aucune préparation enregistrée',
            message: 'Appuyez sur « Préparer un cours » pour commencer.',
            action: FilledButton.icon(onPressed: _addPreparation, icon: const Icon(Icons.add), label: const Text('Préparer un cours')),
          )
        else
          ...coursePreparations.map((p) {
            final checks = List<bool>.from(p['checks'] ?? [false, false, false, false]);
            while (checks.length < 4) {
              checks.add(false);
            }
            const labels = ['Objectif défini', 'Matériel prêt', 'Étapes préparées', 'Évaluation prévue'];
            final done = checks.take(4).where((v) => v).length;
            final objective = (p['objective'] ?? '').toString();
            final materials = (p['materials'] ?? '').toString();
            final steps = (p['steps'] ?? '').toString();
            return AppCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text('${p['title'] ?? 'Cours'}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold))),
                  Text('$done/4', style: const TextStyle(color: AppColors.redSoft, fontWeight: FontWeight.bold)),
                  IconButton(
                    tooltip: 'Supprimer la préparation',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () async {
                      final ok = await confirmDialog(context, title: 'Supprimer cette préparation ?', message: '${p['title'] ?? 'Cours'}', confirmLabel: 'Supprimer', destructive: true);
                      if (ok) {
                        setState(() => coursePreparations.removeWhere((x) => x['id'] == p['id']));
                        await _save();
                      }
                    },
                  ),
                ]),
                if (objective.isNotEmpty) _labeled('Objectif', objective),
                if (materials.isNotEmpty) _labeled('Matériel', materials),
                if (steps.isNotEmpty) _labeled('Déroulement', steps),
                const SizedBox(height: 10),
                LinearProgressIndicator(value: done / 4, minHeight: 6, borderRadius: BorderRadius.circular(3)),
                const SizedBox(height: 4),
                ...List.generate(4, (i) => CheckboxListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      value: checks[i],
                      onChanged: (v) async {
                        setState(() {
                          checks[i] = v == true;
                          p['checks'] = checks;
                        });
                        await _save();
                      },
                      title: Text(labels[i]),
                    )),
              ]),
            );
          }),
      ]);

  // ---------------------------------------------------------------------------
  // Navigation
  // ---------------------------------------------------------------------------

  Widget _logo(double size) => ClipRRect(
        borderRadius: BorderRadius.circular(size * .24),
        child: Image.asset(
          'assets/dp_icon.png',
          width: size,
          height: size,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => Icon(Icons.school, color: AppColors.redSoft, size: size * .8),
        ),
      );

  Widget _navList({required bool inDrawer}) {
    void go(int index) {
      if (inDrawer) Navigator.pop(context);
      setState(() => tab = index);
    }

    return ListView(padding: const EdgeInsets.all(12), children: [
      ListTile(
        leading: _logo(46),
        title: const Text('DP', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
        subtitle: const Text('Apprendre · Progresser · Réussir'),
      ),
      const Divider(height: 24),
      for (final item in _navItems)
        Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: ListTile(
            leading: Icon(tab == item.index ? item.selectedIcon : item.icon),
            title: Text(item.label),
            selected: tab == item.index,
            selectedColor: AppColors.redSoft,
            selectedTileColor: AppColors.redTint,
            onTap: () => go(item.index),
          ),
        ),
      const Divider(height: 24),
      ListTile(
        leading: const Icon(Icons.file_open_outlined),
        title: const Text('Importer une sauvegarde'),
        onTap: () {
          if (inDrawer) Navigator.pop(context);
          _importBackup();
        },
      ),
      ListTile(
        leading: const Icon(Icons.share_outlined),
        title: const Text('Exporter et partager une sauvegarde'),
        onTap: () {
          if (inDrawer) Navigator.pop(context);
          _exportBackup();
        },
      ),
    ]);
  }

  /// Position dans la barre du bas ; -1 pour les pages secondaires (via le menu).
  int _bottomIndex() {
    switch (tab) {
      case 0:
        return 0;
      case 1:
        return 1;
      case 3:
        return 2;
      case 4:
        return 3;
      default:
        return -1;
    }
  }

  void _onBottomTap(int i) {
    switch (i) {
      case 0:
        setState(() => tab = 0);
        break;
      case 1:
        setState(() => tab = 1);
        break;
      case 2:
        setState(() => tab = 3);
        break;
      default:
        setState(() => tab = 4);
    }
  }

  Future<void> _showQuickAdd() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              const Expanded(child: Text('Ajouter', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800))),
              IconButton(tooltip: 'Fermer', onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close)),
            ]),
            const SizedBox(height: 8),
            GridView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 140,
                mainAxisExtent: 120,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
              ),
              children: [
                _quickAddItem(ctx, 'Nouvel élève', Icons.person_add_alt_1, _addStudent),
                _quickAddItem(ctx, 'Niveaux et groupes', Icons.school, () => setState(() => tab = 2)),
                _quickAddItem(ctx, 'Évaluation', Icons.assignment, () => _addAssessment()),
                _quickAddItem(ctx, 'Question d’examen', Icons.quiz, _addQuestion),
                _quickAddItem(ctx, 'Cours à planifier', Icons.calendar_month, _addCourseSession),
                _quickAddItem(ctx, 'Préparation de cours', Icons.menu_book, _addPreparation),
              ],
            ),
          ]),
        ),
      ),
    );
  }

  Widget _quickAddItem(BuildContext ctx, String label, IconData icon, VoidCallback action) => InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          Navigator.pop(ctx);
          action();
        },
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: AppColors.ink,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.redBorder),
              ),
              child: Icon(icon, color: AppColors.redSoft, size: 26),
            ),
            const SizedBox(height: 8),
            Text(label, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 850;
    final pending = reminders.where((r) => r['done'] != true).length;
    final navIndex = tab < 0 ? 0 : (tab >= _navItems.length ? _navItems.length - 1 : tab);
    final pageTitle = tab == 0 ? 'DP' : _navItems[navIndex].label;

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Row(mainAxisSize: MainAxisSize.min, children: [
          _logo(36),
          const SizedBox(width: 10),
          Flexible(child: Text(pageTitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800))),
        ]),
        actions: [
          IconButton(
            tooltip: 'Calendrier des cours et rappels',
            onPressed: () => setState(() => tab = 7),
            icon: Badge(
              isLabelVisible: pending > 0,
              label: Text('$pending'),
              child: const Icon(Icons.notifications_active_outlined),
            ),
          ),
          if (wide) ...[
            IconButton(tooltip: 'Importer une sauvegarde', onPressed: _importBackup, icon: const Icon(Icons.file_open_outlined)),
            IconButton(tooltip: 'Exporter et partager une sauvegarde', onPressed: _exportBackup, icon: const Icon(Icons.share_outlined)),
          ] else
            PopupMenuButton<String>(
              tooltip: 'Sauvegarde',
              onSelected: (v) {
                if (v == 'import') _importBackup();
                if (v == 'export') _exportBackup();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'import', child: Text('Importer une sauvegarde')),
                PopupMenuItem(value: 'export', child: Text('Exporter et partager')),
              ],
            ),
        ],
      ),
      drawer: wide ? null : Drawer(child: SafeArea(child: _navList(inDrawer: true))),
      body: SafeArea(
        top: false,
        child: Row(children: [
          if (wide)
            Container(
              width: 272,
              decoration: const BoxDecoration(
                color: AppColors.panel,
                border: Border(right: BorderSide(color: AppColors.border)),
              ),
              child: _navList(inDrawer: false),
            ),
          Expanded(child: KeyedSubtree(key: ValueKey<int>(tab), child: _page())),
        ]),
      ),
      floatingActionButton: loading
          ? null
          : FloatingActionButton(
              heroTag: 'dp_center_add',
              tooltip: 'Ajouter',
              onPressed: _showQuickAdd,
              child: const Icon(Icons.add, size: 30),
            ),
      bottomNavigationBar: (wide || _bottomIndex() < 0)
          ? null
          : NavigationBar(
              selectedIndex: _bottomIndex(),
              onDestinationSelected: _onBottomTap,
              destinations: const [
                NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Accueil'),
                NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: 'Élèves'),
                NavigationDestination(icon: Icon(Icons.fact_check_outlined), selectedIcon: Icon(Icons.fact_check), label: 'Présences'),
                NavigationDestination(icon: Icon(Icons.grade_outlined), selectedIcon: Icon(Icons.grade), label: 'Notes'),
              ],
            ),
    );
  }
}

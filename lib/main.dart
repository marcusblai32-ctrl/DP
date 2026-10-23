import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'models/student.dart';
import 'models/assessment.dart';
import 'models/attendance_record.dart';
import 'models/grade_record.dart';
import 'models/exam_question.dart';
import 'services/grade_service.dart';

void main() => runApp(const SchoolApp());

class SchoolApp extends StatelessWidget {
  const SchoolApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DP Scolaire',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF174A8B)),
        useMaterial3: true,
      ),
      home: const SchoolHome(),
    );
  }
}

class SchoolHome extends StatefulWidget {
  const SchoolHome({super.key});
  @override
  State<SchoolHome> createState() => _SchoolHomeState();
}

class _SchoolHomeState extends State<SchoolHome> {
  int tab = 0;
  bool loading = true;
  List<String> levels = ['Niveau 1'];
  List<String> groups = ['Groupe A'];
  List<Student> students = [];
  List<Assessment> assessments = [];
  List<AttendanceRecord> attendance = [];
  List<GradeRecord> grades = [];
  List<ExamQuestion> questionBank = [];
  final remarks = <String, String>{
    'excellent': 'Excellent travail. Continuez vos efforts.',
    'good': 'Bon travail. Poursuivez vos efforts.',
    'average': 'Résultats satisfaisants, mais des progrès sont nécessaires.',
    'weak': 'Des efforts supplémentaires sont nécessaires.',
    'poor': 'Un accompagnement régulier est recommandé.',
  };
  final tabs = const [
    'Tableau de bord', 'Élèves', 'Niveaux et groupes', 'Présences',
    'Évaluations et notes', 'Examens', 'Fiches, palmarès et bulletins'
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    try {
      levels = List<String>.from(jsonDecode(p.getString('levels') ?? '["Niveau 1"]'));
      groups = List<String>.from(jsonDecode(p.getString('groups') ?? '["Groupe A"]'));
      students = (jsonDecode(p.getString('students') ?? '[]') as List).map((e) => Student.fromJson(e)).toList();
      assessments = (jsonDecode(p.getString('assessments') ?? '[]') as List).map((e) => Assessment.fromJson(e)).toList();
      attendance = (jsonDecode(p.getString('attendance') ?? '[]') as List).map((e) => AttendanceRecord.fromJson(e)).toList();
      grades = (jsonDecode(p.getString('grades') ?? '[]') as List).map((e) => GradeRecord.fromJson(e)).toList();
      questionBank = (jsonDecode(p.getString('questions') ?? '[]') as List).map((e) => ExamQuestion(
        e['prompt'] ?? '', e['category'] ?? 'QCU',
        List<String>.from(e['choices'] ?? []), e['answer'] ?? '',
        (e['points'] as num?)?.toDouble() ?? 1,
      )).toList();
      remarks.addAll(Map<String, String>.from(jsonDecode(p.getString('remarks') ?? '{}')));
    } catch (_) {}
    if (mounted) setState(() => loading = false);
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
  }

  String _id() => DateTime.now().microsecondsSinceEpoch.toString();
  void _msg(String s) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
  Student? _student(String id) {
    for (final s in students) { if (s.id == id) return s; }
    return null;
  }
  Assessment? _assessment(String id) {
    for (final a in assessments) { if (a.id == id) return a; }
    return null;
  }

  double _average(Student s) => GradeService.average(s, grades, assessments);

  String _remark(double avg) {
    if (avg >= 90) return remarks['excellent']!;
    if (avg >= 80) return remarks['good']!;
    if (avg >= 60) return remarks['average']!;
    if (avg >= 40) return remarks['weak']!;
    return remarks['poor']!;
  }

  String _letterGrade(double avg) => GradeService.letterGrade(avg);

  Future<void> _textDialog(String title, String hint, void Function(String) onSave, {String initial = ''}) async {
    final c = TextEditingController(text: initial);
    await showDialog<void>(context: context, builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(controller: c, autofocus: true, decoration: InputDecoration(labelText: hint)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
        FilledButton(onPressed: () {
          final v = c.text.trim();
          if (v.isNotEmpty) onSave(v);
          Navigator.pop(ctx);
        }, child: const Text('Enregistrer')),
      ],
    ));
  }

  Future<void> _addStudent() async {
    final name = TextEditingController();
    String level = levels.first, group = groups.first;
    await showDialog<void>(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setD) => AlertDialog(
      title: const Text('Ajouter un élève'),
      content: SizedBox(width: 420, child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: name, decoration: const InputDecoration(labelText: 'Nom complet')),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(value: level, items: levels.map((x) => DropdownMenuItem(value: x, child: Text(x))).toList(), onChanged: (v) => setD(() => level = v ?? level), decoration: const InputDecoration(labelText: 'Niveau')),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(value: group, items: groups.map((x) => DropdownMenuItem(value: x, child: Text(x))).toList(), onChanged: (v) => setD(() => group = v ?? group), decoration: const InputDecoration(labelText: 'Groupe')),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
        FilledButton(onPressed: () async {
          if (name.text.trim().isNotEmpty) {
            setState(() => students.add(Student(_id(), name.text.trim(), level, group)));
            await _save(); if (mounted) Navigator.pop(ctx);
          }
        }, child: const Text('Ajouter')),
      ],
    )));
  }

  Future<void> _addAssessment({String category = 'Devoir'}) async {
    final title = TextEditingController();
    final max = TextEditingController(text: '100');
    String level = levels.first, group = groups.first;
    await showDialog<void>(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setD) => AlertDialog(
      title: Text('Créer une évaluation: $category'),
      content: SizedBox(width: 420, child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: title, decoration: const InputDecoration(labelText: 'Titre')),
        TextField(controller: max, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Note maximale')),
        DropdownButtonFormField<String>(value: level, items: levels.map((x) => DropdownMenuItem(value: x, child: Text(x))).toList(), onChanged: (v) => setD(() => level = v ?? level), decoration: const InputDecoration(labelText: 'Niveau')),
        DropdownButtonFormField<String>(value: group, items: groups.map((x) => DropdownMenuItem(value: x, child: Text(x))).toList(), onChanged: (v) => setD(() => group = v ?? group), decoration: const InputDecoration(labelText: 'Groupe')),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
        FilledButton(onPressed: () async {
          final n = double.tryParse(max.text) ?? 100;
          if (title.text.trim().isNotEmpty && n > 0) {
            setState(() => assessments.add(Assessment(_id(), title.text.trim(), category, level, group, DateTime.now().toIso8601String().substring(0,10), 'Manuel', n)));
            await _save(); if (mounted) Navigator.pop(ctx);
          }
        }, child: const Text('Créer')),
      ],
    )));
  }

  Future<void> _enterGrades(Assessment a) async {
    final matching = students.where((s) => s.level == a.level && s.group == a.group).toList();
    if (matching.isEmpty) { _msg('Aucun élève dans ce niveau/groupe.'); return; }
    final controllers = <String, TextEditingController>{};
    for (final s in matching) {
      final old = grades.where((g) => g.studentId == s.id && g.assessmentId == a.id).firstOrNull;
      controllers[s.id] = TextEditingController(text: old?.score.toString() ?? '');
    }
    await showDialog<void>(context: context, builder: (ctx) => AlertDialog(
      title: Text('Saisir les notes: ${a.title}'),
      content: SizedBox(width: 480, height: 420, child: ListView(children: matching.map((s) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(children: [
          Expanded(child: Text(s.name)),
          SizedBox(width: 110, child: TextField(controller: controllers[s.id], keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: '/ ${a.maxScore}'))),
        ]),
      )).toList())),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
        FilledButton(onPressed: () async {
          for (final s in matching) {
            final val = double.tryParse(controllers[s.id]!.text.trim());
            if (val == null) continue;
            if (val < 0 || val > a.maxScore) { _msg('Une note doit être entre 0 et ${a.maxScore}.'); return; }
            grades.removeWhere((g) => g.studentId == s.id && g.assessmentId == a.id);
            grades.add(GradeRecord(s.id, a.id, val, ''));
          }
          await _save(); if (mounted) { Navigator.pop(ctx); setState(() {}); _msg('Notes enregistrées.'); }
        }, child: const Text('Enregistrer les notes')),
      ],
    ));
  }

  Future<void> _markAttendance(String status) async {
    final date = DateTime.now().toIso8601String().substring(0,10);
    final active = List<Student>.from(students)..sort((a, b) {
      final levelCompare = a.level.compareTo(b.level);
      return levelCompare != 0 ? levelCompare : a.name.compareTo(b.name);
    });
    if (active.isEmpty) { _msg('Ajoutez d’abord des élèves.'); return; }
    await showDialog<void>(context: context, builder: (ctx) => AlertDialog(
      title: Text('Présence du $date'),
      content: SizedBox(width: 480, height: 400, child: ListView(children: active.map((s) {
        final record = attendance.where((a) => a.studentId == s.id && a.date == date).firstOrNull;
        return ListTile(title: Text(s.name), subtitle: Text(record?.status ?? 'Non enregistré'),
          trailing: PopupMenuButton<String>(onSelected: (v) async {
            attendance.removeWhere((a) => a.studentId == s.id && a.date == date);
            attendance.add(AttendanceRecord(s.id, date, v, ''));
            await _save(); setState(() {});
          }, itemBuilder: (_) => const [
            PopupMenuItem(value: 'Présent', child: Text('Présent')),
            PopupMenuItem(value: 'Absent', child: Text('Absent')),
            PopupMenuItem(value: 'Retard', child: Text('En retard')),
            PopupMenuItem(value: 'Excusé', child: Text('Absence excusée')),
          ], child: const Icon(Icons.more_vert)));
      }).toList())),
      actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Terminé'))],
    ));
  }

  Future<void> _addQuestion() async {
    final prompt = TextEditingController();
    final answer = TextEditingController();
    final choices = TextEditingController();
    final points = TextEditingController(text: '1');
    String category = 'QCU';
    await showDialog<void>(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setD) => AlertDialog(
      title: const Text('Ajouter une question à la banque'),
      content: SizedBox(width: 500, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        DropdownButtonFormField<String>(value: category, items: const ['QCU','QCM','Compléter','Définition','Subjectif'].map((x) => DropdownMenuItem(value: x, child: Text(x))).toList(), onChanged: (v) => setD(() => category = v ?? category), decoration: const InputDecoration(labelText: 'Catégorie')),
        TextField(controller: prompt, decoration: const InputDecoration(labelText: 'Question')),
        TextField(controller: choices, decoration: const InputDecoration(labelText: 'Choix séparés par | (QCM/QCU)')),
        TextField(controller: answer, decoration: const InputDecoration(labelText: 'Réponse attendue / corrigé')),
        TextField(controller: points, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Points')),
      ]))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
        FilledButton(onPressed: () async {
          if (prompt.text.trim().isEmpty) return;
          questionBank.add(ExamQuestion(prompt.text.trim(), category, choices.text.split('|').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(), answer.text.trim(), double.tryParse(points.text) ?? 1));
          await _save(); if (mounted) { Navigator.pop(ctx); setState(() {}); }
        }, child: const Text('Ajouter')),
      ],
    )));
  }

  Future<void> _generateExam() async {
    if (questionBank.isEmpty) { _msg('Ajoutez des questions à la banque avant de générer.'); return; }
    final count = TextEditingController(text: questionBank.length < 10 ? '${questionBank.length}' : '10');
    String category = 'Toutes';
    await showDialog<void>(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setD) => AlertDialog(
      title: const Text('Générer un examen'),
      content: SizedBox(width: 400, child: Column(mainAxisSize: MainAxisSize.min, children: [
        DropdownButtonFormField<String>(value: category, items: const ['Toutes','QCU','QCM','Compléter','Définition','Subjectif'].map((x) => DropdownMenuItem(value: x, child: Text(x))).toList(), onChanged: (v) => setD(() => category = v ?? category)),
        TextField(controller: count, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Nombre de questions')),
        const SizedBox(height: 8),
        const Text('Le générateur choisit des questions existantes au hasard. Il ne crée pas de nouvelles questions par IA.'),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
        FilledButton(onPressed: () async {
          final pool = questionBank.where((q) => category == 'Toutes' || q.category == category).toList()..shuffle();
          final n = int.tryParse(count.text) ?? 0;
          if (n < 1 || n > pool.length) { _msg('Nombre invalide. Questions disponibles: ${pool.length}.'); return; }
          final chosen = pool.take(n).toList();
          if (mounted) Navigator.pop(ctx);
          await _showExamPreview(chosen, category);
        }, child: const Text('Générer')),
      ],
    )));
  }

  Future<void> _showExamPreview(List<ExamQuestion> questions, String category) async {
    await showDialog<void>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Examen généré'),
      content: SizedBox(width: 600, height: 500, child: ListView(children: [
        Text('Catégorie: $category · ${questions.length} questions'),
        const Divider(),
        ...questions.asMap().entries.map((e) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${e.key + 1}. ${e.value.prompt}', style: const TextStyle(fontWeight: FontWeight.bold)),
            if (e.value.choices.isNotEmpty) Text('Choix: ${e.value.choices.join(" / ")}'),
            Text('Points: ${e.value.points}'),
            const SizedBox(height: 4),
          ]),
        )),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fermer')),
        FilledButton.icon(onPressed: () async {
          final doc = pw.Document();
          doc.addPage(pw.MultiPage(build: (_) => [
            pw.Text('DP SCOLAIRE · EXAMEN', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 12),
            pw.Text('Nom: __________________________________    Date: ______________'),
            pw.SizedBox(height: 16),
            ...questions.asMap().entries.map((e) => pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 12),
              child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text('${e.key + 1}. ${e.value.prompt} (${e.value.points} pts)'),
                if (e.value.choices.isNotEmpty) pw.Text(e.value.choices.join('    ')),
                pw.SizedBox(height: 18),
              ]),
            )),
          ]));
          await Printing.layoutPdf(onLayout: (_) async => doc.save());
        }, icon: const Icon(Icons.picture_as_pdf), label: const Text('Imprimer / PDF')),
      ],
    ));
  }


  Future<void> _clearHistory() async {
    final confirmation = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Effacer l’historique'),
        content: const Text(
          'Cette action effacera les présences, les notes, les évaluations et la banque de questions. '
          'Les élèves, niveaux et groupes seront conservés. Exportez une sauvegarde avant de continuer.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Effacer l’historique'),
          ),
        ],
      ),
    );
    if (confirmation != true) return;
    setState(() {
      attendance.clear();
      grades.clear();
      assessments.clear();
      questionBank.clear();
    });
    await _save();
    if (mounted) _msg('Historique effacé. Les élèves, niveaux et groupes sont conservés.');
  }

  Future<void> _exportCsv() async {
    final rows = <List<String>>[
      ['Nom', 'Niveau', 'Groupe', 'Moyenne /100', 'Rang'],
    ];
    final sorted = students.toList()..sort((a,b) => _average(b).compareTo(_average(a)));
    for (var i = 0; i < sorted.length; i++) {
      final s = sorted[i];
      rows.add([s.name, s.level, s.group, _average(s).toStringAsFixed(2), '${i+1}']);
    }
    final csv = rows.map((r) => r.map((x) => '"${x.replaceAll('"','""')}"').join(';')).join('\n');
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}${Platform.pathSeparator}educadim_palmares.csv');
    await file.writeAsString(csv);
    _msg('Fichier créé: ${file.path}');
  }

  Future<void> _exportBackup() async {
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
      'questions': questionBank.map((e) => e.toJson()).toList(),
      'remarks': remarks,
    };
    final bytes = utf8.encode(const JsonEncoder.withIndent('  ').convert(data));
    final result = await FilePicker.platform.saveFile(
      dialogTitle: 'Exporter une sauvegarde DP Scolaire',
      fileName: 'DP_Scolaire_Backup_${DateTime.now().toIso8601String().substring(0, 10)}.json',
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
      if (mounted) _msg('Sauvegarde enregistrée : $result');
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
      _msg('Impossible de lire ce fichier. Choisissez un fichier JSON accessible.');
      return;
    }
    Map<String, dynamic> data;
    try {
      data = Map<String, dynamic>.from(jsonDecode(utf8.decode(raw)) as Map);
      if (data['format'] != 'dp_scolaire_backup' || data['version'] != 1) {
        _msg('Ce fichier n’est pas une sauvegarde DP Scolaire reconnue.');
        return;
      }
      if (data['levels'] is! List || data['groups'] is! List || data['students'] is! List) {
        _msg('Le fichier de sauvegarde est incomplet ou invalide.');
        return;
      }
    } catch (_) {
      _msg('Le fichier JSON est invalide ou endommagé.');
      return;
    }
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remplacer les données actuelles ?'),
        content: const Text('L’importation remplacera les données actuellement affichées dans DP Scolaire. Exportez une sauvegarde avant de continuer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Importer')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      levels = List<String>.from(data['levels'] as List);
      groups = List<String>.from(data['groups'] as List);
      students = (data['students'] as List).map((e) => Student.fromJson(Map<String, dynamic>.from(e as Map))).toList();
      assessments = ((data['assessments'] as List?) ?? []).map((e) => Assessment.fromJson(Map<String, dynamic>.from(e as Map))).toList();
      attendance = ((data['attendance'] as List?) ?? []).map((e) => AttendanceRecord.fromJson(Map<String, dynamic>.from(e as Map))).toList();
      grades = ((data['grades'] as List?) ?? []).map((e) => GradeRecord.fromJson(Map<String, dynamic>.from(e as Map))).toList();
      questionBank = ((data['questions'] as List?) ?? []).map((e) {
        final q = Map<String, dynamic>.from(e as Map);
        return ExamQuestion(q['prompt'] ?? '', q['category'] ?? 'QCU', List<String>.from(q['choices'] ?? []), q['answer'] ?? '', (q['points'] as num?)?.toDouble() ?? 1);
      }).toList();
      remarks.addAll(Map<String, String>.from(data['remarks'] ?? {}));
      await _save();
      if (mounted) {
        setState(() {});
        _msg('Sauvegarde importée avec succès.');
      }
    } catch (e) {
      if (mounted) _msg('Erreur pendant l’importation : $e');
    }
  }

  Future<void> _editRemarks() async {
    final labels = ['excellent','good','average','weak','poor'];
    final titles = ['90–100','80–89','60–79','40–59','0–39'];
    final ctrls = {for (final k in labels) k: TextEditingController(text: remarks[k])};
    await showDialog<void>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Modifier les appréciations automatiques'),
      content: SizedBox(width: 560, child: ListView(shrinkWrap: true, children: [
        for (var i=0;i<labels.length;i++) TextField(controller: ctrls[labels[i]], maxLines: 2, decoration: InputDecoration(labelText: titles[i])),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
        FilledButton(onPressed: () async {
          for (final k in labels) { remarks[k] = ctrls[k]!.text.trim(); }
          await _save(); if (mounted) { Navigator.pop(ctx); setState(() {}); }
        }, child: const Text('Enregistrer')),
      ],
    ));
  }

  Future<void> _showReport(Student s) async {
    final avg = _average(s);
    final studentGrades = grades.where((g) => g.studentId == s.id).toList();
    final doc = pw.Document();
    doc.addPage(pw.MultiPage(build: (_) => [
      pw.Center(child: pw.Text('BULLETIN SCOLAIRE', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold))),
      pw.SizedBox(height: 16),
      pw.Text('Élève: ${s.name}'),
      pw.Text('Niveau: ${s.level}    Groupe: ${s.group}'),
      pw.SizedBox(height: 12),
      pw.TableHelper.fromTextArray(
        headers: ['Évaluation', 'Note', 'Maximum', 'Pourcentage'],
        data: studentGrades.map((g) {
          final a = _assessment(g.assessmentId);
          return [a?.title ?? 'Évaluation', g.score.toStringAsFixed(2), a?.maxScore.toStringAsFixed(2) ?? '-', a == null ? '-' : '${(g.score / a.maxScore * 100).toStringAsFixed(1)}%'];
        }).toList(),
      ),
      pw.SizedBox(height: 16),
      pw.Text('Moyenne générale: ${avg.toStringAsFixed(2)} / 100'),
      pw.Text('Lettre: ${_letterGrade(avg)}'),
      pw.Text('Appréciation: ${_remark(avg)}'),
      pw.SizedBox(height: 30),
      pw.Text('Signature: ______________________________'),
    ]));
    await Printing.layoutPdf(onLayout: (_) async => doc.save());
  }

  Widget _page() {
    if (loading) return const Center(child: CircularProgressIndicator());
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
      default:
        return _reportsPage();
    }
  }

  Widget _dashboard() => ListView(padding: const EdgeInsets.all(24), children: [
    const Text('Tableau de bord', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
    const SizedBox(height: 20),
    Wrap(spacing: 12, runSpacing: 12, children: [
      _metric('Élèves', '${students.length}', Icons.people),
      _metric('Niveaux', '${levels.length}', Icons.school),
      _metric('Groupes', '${groups.length}', Icons.groups),
      _metric('Évaluations', '${assessments.length}', Icons.fact_check),
      _metric('Questions', '${questionBank.length}', Icons.quiz),
    ]),
    const SizedBox(height: 24),
    const Text('Actions rapides', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
    const SizedBox(height: 10),
    Wrap(spacing: 10, runSpacing: 10, children: [
      FilledButton.icon(onPressed: _addStudent, icon: const Icon(Icons.person_add), label: const Text('Ajouter un élève')),
      OutlinedButton.icon(onPressed: () => setState(() => tab = 3), icon: const Icon(Icons.fact_check), label: const Text('Faire l’appel')),
      OutlinedButton.icon(onPressed: () => _addAssessment(category: 'Examen'), icon: const Icon(Icons.assignment), label: const Text('Créer un examen')),
      OutlinedButton.icon(onPressed: _exportBackup, icon: const Icon(Icons.backup), label: const Text('Sauvegarder les données')),
    ]),
    const SizedBox(height: 24),
    const Text('Classement actuel', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
    ...(_rankedStudents().take(5).map((e) => ListTile(
      leading: CircleAvatar(child: Text('${e.$2}')),
      title: Text(e.$1.name),
      subtitle: Text('${e.$1.level} · ${e.$1.group}'),
      trailing: Text('${_average(e.$1).toStringAsFixed(2)} /100'),
    ))),
  ]);

  List<(Student, int)> _rankedStudents() {
    final sorted = students.toList()..sort((a,b) => _average(b).compareTo(_average(a)));
    return [for (var i=0;i<sorted.length;i++) (sorted[i], i+1)];
  }

  Widget _metric(String label, String value, IconData icon) => SizedBox(
    width: 180, child: Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, size: 28), const SizedBox(height: 12),
      Text(value, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
      Text(label),
    ]))),
  );

  Widget _studentsPage() => Padding(padding: const EdgeInsets.all(20), child: Column(children: [
    Row(children: [const Expanded(child: Text('Élèves', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold))), FilledButton.icon(onPressed: _addStudent, icon: const Icon(Icons.add), label: const Text('Ajouter'))]),
    const SizedBox(height: 12),
    Expanded(child: students.isEmpty ? const Center(child: Text('Aucun élève. Cliquez sur Ajouter.')) : ListView.builder(itemCount: students.length, itemBuilder: (_, i) {
      final s = students[i];
      return Card(child: ListTile(
        title: Text(s.name), subtitle: Text('${s.level} · ${s.group} · Moyenne ${_average(s).toStringAsFixed(1)}/100 · Lettre ${_letterGrade(_average(s))}'),
        trailing: Wrap(children: [
          IconButton(tooltip: 'Bulletin PDF', onPressed: () => _showReport(s), icon: const Icon(Icons.picture_as_pdf)),
          IconButton(tooltip: 'Supprimer', onPressed: () async {
            final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: const Text('Supprimer cet élève ?'), content: Text(s.name), actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Supprimer')),
            ]));
            if (ok == true) { setState(() => students.removeWhere((x) => x.id == s.id)); await _save(); }
          }, icon: const Icon(Icons.delete_outline)),
        ]),
      ));
    })),
  ]));

  Widget _levelsPage() => ListView(padding: const EdgeInsets.all(20), children: [
    const Text('Niveaux et groupes', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
    const SizedBox(height: 12),
    Wrap(spacing: 10, children: [
      FilledButton.icon(onPressed: () => _textDialog('Créer un niveau', 'Nom du niveau', (v) async { if (!levels.contains(v)) { setState(() => levels.add(v)); await _save(); } }), icon: const Icon(Icons.add), label: const Text('Créer un niveau')),
      FilledButton.tonalIcon(onPressed: () => _textDialog('Créer un groupe', 'Nom du groupe', (v) async { if (!groups.contains(v)) { setState(() => groups.add(v)); await _save(); } }), icon: const Icon(Icons.group_add), label: const Text('Créer un groupe')),
    ]),
    const SizedBox(height: 20),
    const Text('Niveaux', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
    ...levels.map((x) => Card(child: ListTile(title: Text(x), trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () async { if (levels.length > 1 && !students.any((s) => s.level == x)) { setState(() => levels.remove(x)); await _save(); } else { _msg('Niveau utilisé par un élève ou dernier niveau.'); } })))),
    const SizedBox(height: 12),
    const Text('Groupes', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
    ...groups.map((x) => Card(child: ListTile(title: Text(x), trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () async { if (groups.length > 1 && !students.any((s) => s.group == x)) { setState(() => groups.remove(x)); await _save(); } else { _msg('Groupe utilisé par un élève ou dernier groupe.'); } })))),
  ]);

  Widget _attendancePage() => Padding(padding: const EdgeInsets.all(20), child: Column(children: [
    Row(children: [const Expanded(child: Text('Présences et retards', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold))), FilledButton.icon(onPressed: () => _markAttendance('Présent'), icon: const Icon(Icons.fact_check), label: const Text('Faire l’appel'))]),
    const SizedBox(height: 12),
    Expanded(child: attendance.isEmpty ? const Center(child: Text('Aucun appel enregistré.')) : ListView.builder(itemCount: attendance.length, itemBuilder: (_, i) {
      final a = attendance.reversed.toList()[i]; final s = _student(a.studentId);
      return Card(child: ListTile(title: Text(s?.name ?? 'Élève supprimé'), subtitle: Text(a.date), trailing: Chip(label: Text(a.status))));
    })),
  ]));

  Widget _assessmentsPage() => Padding(padding: const EdgeInsets.all(20), child: Column(children: [
    Row(children: [const Expanded(child: Text('Évaluations et notes', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold))), PopupMenuButton<String>(onSelected: (v) => _addAssessment(category: v), itemBuilder: (_) => const [
      PopupMenuItem(value: 'Devoir', child: Text('Créer un devoir')),
      PopupMenuItem(value: 'Examen', child: Text('Créer un examen')),
      PopupMenuItem(value: 'Participation', child: Text('Participation')),
    ], child: const FilledButton(onPressed: null, child: Text('Nouvelle évaluation')))]),
    const SizedBox(height: 12),
    Expanded(child: assessments.isEmpty ? const Center(child: Text('Aucune évaluation.')) : ListView.builder(itemCount: assessments.length, itemBuilder: (_, i) {
      final a = assessments[i];
      return Card(child: ListTile(title: Text(a.title), subtitle: Text('${a.category} · ${a.level} / ${a.group} · max ${a.maxScore}'), trailing: FilledButton(onPressed: () => _enterGrades(a), child: const Text('Saisir notes'))));
    })),
  ]));

  Widget _examsPage() => Padding(padding: const EdgeInsets.all(20), child: Column(children: [
    Row(children: [const Expanded(child: Text('Examens et banque de questions', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold))), FilledButton.icon(onPressed: _addQuestion, icon: const Icon(Icons.add), label: const Text('Ajouter une question'))]),
    const SizedBox(height: 8),
    Align(alignment: Alignment.centerLeft, child: FilledButton.tonalIcon(onPressed: _generateExam, icon: const Icon(Icons.auto_awesome), label: const Text('Générer un examen depuis la banque'))),
    const SizedBox(height: 12),
    Expanded(child: questionBank.isEmpty ? const Center(child: Text('La banque est vide. Ajoutez vos questions.')) : ListView.builder(itemCount: questionBank.length, itemBuilder: (_, i) {
      final q = questionBank[i];
      return Card(child: ListTile(title: Text(q.prompt), subtitle: Text('${q.category} · ${q.points} point(s)${q.choices.isEmpty ? '' : ' · ${q.choices.join(" / ")}'}')));
    })),
  ]));

  Widget _reportsPage() => ListView(padding: const EdgeInsets.all(20), children: [
    const Text('Fiches d’évaluation, palmarès et bulletins', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
    const SizedBox(height: 8),
    const Text('La moyenne est calculée à partir des évaluations notées disponibles. Le classement ci-dessous est général. Pour un palmarès officiel, filtrez par niveau et groupe dans une prochaine version.'),
    const SizedBox(height: 14),
    Wrap(spacing: 10, runSpacing: 10, children: [
      FilledButton.icon(onPressed: _exportCsv, icon: const Icon(Icons.table_view), label: const Text('Exporter le palmarès CSV')),
      OutlinedButton.icon(onPressed: _editRemarks, icon: const Icon(Icons.edit_note), label: const Text('Modifier les appréciations')),
      OutlinedButton.icon(onPressed: _exportBackup, icon: const Icon(Icons.download), label: const Text('Exporter sauvegarde JSON')),
      OutlinedButton.icon(
        onPressed: _clearHistory,
        icon: const Icon(Icons.delete_forever, color: Colors.red),
        label: const Text('Effacer l’historique'),
      ),
    ]),
    const SizedBox(height: 16),
    const Text('Palmarès selon la moyenne', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
    if (students.isEmpty) const Padding(padding: EdgeInsets.all(20), child: Text('Ajoutez des élèves pour calculer le palmarès.')),
    ..._rankedStudents().map((e) {
      final s = e.$1; final rank = e.$2; final avg = _average(s);
      return Card(child: ListTile(
        leading: CircleAvatar(child: Text('$rank')),
        title: Text(s.name),
        subtitle: Text('${s.level} · ${s.group} · Lettre ${_letterGrade(avg)} · ${_remark(avg)}'),
        trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('${avg.toStringAsFixed(2)} /100', style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(rank == 1 ? '1er' : rank == 2 ? '2e' : rank == 3 ? '3e' : '$rank'),
        ]),
        onTap: () => _showReport(s),
      ));
    }),
  ]);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('DP Scolaire'), actions: [
        IconButton(tooltip: 'Importer une sauvegarde', onPressed: _importBackup, icon: const Icon(Icons.file_open)),
        IconButton(tooltip: 'Exporter et partager une sauvegarde', onPressed: _exportBackup, icon: const Icon(Icons.share)),
      ]),
      body: Row(children: [
        NavigationRail(
          selectedIndex: tab, labelType: NavigationRailLabelType.all,
          onDestinationSelected: (i) => setState(() => tab = i),
          destinations: const [
            NavigationRailDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: Text('Accueil')),
            NavigationRailDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: Text('Élèves')),
            NavigationRailDestination(icon: Icon(Icons.school_outlined), selectedIcon: Icon(Icons.school), label: Text('Niveaux')),
            NavigationRailDestination(icon: Icon(Icons.fact_check_outlined), selectedIcon: Icon(Icons.fact_check), label: Text('Présences')),
            NavigationRailDestination(icon: Icon(Icons.grade_outlined), selectedIcon: Icon(Icons.grade), label: Text('Notes')),
            NavigationRailDestination(icon: Icon(Icons.quiz_outlined), selectedIcon: Icon(Icons.quiz), label: Text('Examens')),
            NavigationRailDestination(icon: Icon(Icons.assessment_outlined), selectedIcon: Icon(Icons.assessment), label: Text('Rapports')),
          ],
        ),
        const VerticalDivider(width: 1),
        Expanded(child: _page()),
      ]),
    );
  }
}

extension FirstOrNullExt<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}

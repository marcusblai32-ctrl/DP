import 'package:flutter/material.dart';
import 'database.dart';
import 'exporter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalDb.instance.db;
  runApp(const DimensionApp());
}

class DimensionApp extends StatelessWidget {
  const DimensionApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'DP', debugShowCheckedModeBanner: false,
    theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF174A8B)), useMaterial3: true),
    home: const HomePage(),
  );
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int tab = 0;
  void refresh() => setState(() {});
  @override
  Widget build(BuildContext context) {
    final pages = [StudentsPage(onChanged: refresh), AssignmentsPage(onChanged: refresh), AssessmentPage(), ExportPage()];
    return Scaffold(
      appBar: AppBar(title: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Dimension Production'), Text('Suivi pédagogique hors ligne', style: TextStyle(fontSize: 12))])),
      body: pages[tab],
      bottomNavigationBar: NavigationBar(selectedIndex: tab, onDestinationSelected: (i) => setState(() => tab = i), destinations: const [
        NavigationDestination(icon: Icon(Icons.people_alt_outlined), selectedIcon: Icon(Icons.people), label: 'Élèves'),
        NavigationDestination(icon: Icon(Icons.assignment_outlined), selectedIcon: Icon(Icons.assignment), label: 'Devoirs'),
        NavigationDestination(icon: Icon(Icons.fact_check_outlined), selectedIcon: Icon(Icons.fact_check), label: 'Évaluer'),
        NavigationDestination(icon: Icon(Icons.file_download_outlined), selectedIcon: Icon(Icons.file_download), label: 'Exports'),
      ]),
    );
  }
}

class StudentsPage extends StatefulWidget {
  const StudentsPage({super.key, required this.onChanged});
  final VoidCallback onChanged;
  @override
  State<StudentsPage> createState() => _StudentsPageState();
}
class _StudentsPageState extends State<StudentsPage> {
  List<Map<String, Object?>> items = [];
  final name = TextEditingController();
  String dimension = 'Dimension 2';
  String subgroup = 'A';
  @override
  void initState() { super.initState(); load(); }
  Future<void> load() async { items = await LocalDb.instance.students(); if (mounted) setState(() {}); }
  Future<void> add() async {
    if (name.text.trim().isEmpty) return;
    await LocalDb.instance.addStudent(name.text, dimension, subgroup);
    name.clear(); await load(); widget.onChanged();
  }
  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(16), children: [
    Text('Liste des élèves (${items.length})', style: Theme.of(context).textTheme.titleLarge),
    const SizedBox(height: 12),
    TextField(controller: name, decoration: const InputDecoration(labelText: 'Nom et prénom', border: OutlineInputBorder())),
    const SizedBox(height: 8),
    Row(children: [Expanded(child: DropdownButtonFormField<String>(value: dimension, decoration: const InputDecoration(labelText: 'Dimension'), items: ['Dimension 1','Dimension 2','Dimension 3'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(), onChanged: (v) => setState(() => dimension = v ?? dimension))), const SizedBox(width: 8), SizedBox(width: 110, child: DropdownButtonFormField<String>(value: subgroup, decoration: const InputDecoration(labelText: 'Groupe'), items: ['A','B','C'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(), onChanged: (v) => setState(() => subgroup = v ?? subgroup)))]),
    const SizedBox(height: 8), FilledButton.icon(onPressed: add, icon: const Icon(Icons.person_add), label: const Text('Ajouter un élève')),
    const Divider(height: 28),
    if (items.isEmpty) const Text('Aucun élève pour le moment. Ajoutez les élèves du groupe.'),
    ...items.map((s) => Card(child: ListTile(leading: const CircleAvatar(child: Icon(Icons.person)), title: Text('${s['name']}'), subtitle: Text('${s['dimension']} • Groupe ${s['subgroup']}'), trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () async { final yes = await showDialog<bool>(context: context, builder: (c) => AlertDialog(title: const Text('Supprimer cet élève ?'), content: const Text('Cette action supprime aussi ses données de suivi.'), actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Annuler')), FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Supprimer'))])); if (yes == true) { await LocalDb.instance.deleteStudent(s['id'] as int); await load(); widget.onChanged(); } }))))
  ]);
}

class AssignmentsPage extends StatefulWidget {
  const AssignmentsPage({super.key, required this.onChanged});
  final VoidCallback onChanged;
  @override
  State<AssignmentsPage> createState() => _AssignmentsPageState();
}
class _AssignmentsPageState extends State<AssignmentsPage> {
  List<Map<String, Object?>> assignments = [];
  List<Map<String, Object?>> students = [];
  final title = TextEditingController(); final chapter = TextEditingController(); final due = TextEditingController(); final details = TextEditingController();
  @override
  void initState() { super.initState(); load(); }
  Future<void> load() async { assignments = await LocalDb.instance.assignments(); students = await LocalDb.instance.students(); if (mounted) setState(() {}); }
  Future<void> add() async { if (title.text.trim().isEmpty) return; await LocalDb.instance.addAssignment(title.text, chapter.text, due.text, details.text); title.clear(); chapter.clear(); due.clear(); details.clear(); await load(); widget.onChanged(); }
  Future<void> editStatus(Map<String, Object?> assignment) async {
    if (students.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ajoutez d’abord un élève.'))); return; }
    int studentId = students.first['id'] as int; String status = 'AF';
    final ok = await showDialog<bool>(context: context, builder: (c) => StatefulBuilder(builder: (c, setD) => AlertDialog(title: const Text('Suivi du devoir'), content: Column(mainAxisSize: MainAxisSize.min, children: [DropdownButtonFormField<int>(value: studentId, decoration: const InputDecoration(labelText: 'Élève'), items: students.map((s) => DropdownMenuItem(value: s['id'] as int, child: Text('${s['name']}'))).toList(), onChanged: (v) => setD(() => studentId = v ?? studentId)), const SizedBox(height: 12), DropdownButtonFormField<String>(value: status, decoration: const InputDecoration(labelText: 'Statut'), items: const [DropdownMenuItem(value:'AF',child:Text('AF — À faire')),DropdownMenuItem(value:'NR',child:Text('NR — Non remis')),DropdownMenuItem(value:'R',child:Text('R — Remis')),DropdownMenuItem(value:'V',child:Text('V — Vérifié')),DropdownMenuItem(value:'AR',child:Text('AR — À reprendre')),DropdownMenuItem(value:'VAL',child:Text('VAL — Validé'))], onChanged: (v) => setD(() => status = v ?? status))]), actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Annuler')), FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Enregistrer'))])));
    if (ok == true) { await LocalDb.instance.setStatus(studentId, assignment['id'] as int, status); if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Statut enregistré hors ligne.'))); }
  }
  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(16), children: [
    Text('Créer un devoir', style: Theme.of(context).textTheme.titleLarge), const SizedBox(height: 10),
    TextField(controller: title, decoration: const InputDecoration(labelText: 'Devoir / compétence attendue', border: OutlineInputBorder())), const SizedBox(height: 8),
    Row(children: [Expanded(child: TextField(controller: chapter, decoration: const InputDecoration(labelText: 'Chapitre / pages', border: OutlineInputBorder()))), const SizedBox(width: 8), Expanded(child: TextField(controller: due, decoration: const InputDecoration(labelText: 'Échéance (JJ/MM/AAAA)', border: OutlineInputBorder())))]), const SizedBox(height: 8),
    TextField(controller: details, maxLines: 2, decoration: const InputDecoration(labelText: 'Consignes (facultatif)', border: OutlineInputBorder())), const SizedBox(height: 8),
    FilledButton.icon(onPressed: add, icon: const Icon(Icons.add_task), label: const Text('Enregistrer le devoir')), const Divider(height: 28),
    Text('Devoirs enregistrés (${assignments.length})', style: Theme.of(context).textTheme.titleMedium),
    if (assignments.isEmpty) const Text('Aucun devoir créé.'),
    ...assignments.map((a) => Card(child: ListTile(title: Text('${a['title']}'), subtitle: Text('${a['chapter']} • Échéance : ${a['due_date']}\n${a['details']}'), isThreeLine: true, trailing: IconButton(tooltip: 'Suivre un élève', icon: const Icon(Icons.fact_check_outlined), onPressed: () => editStatus(a)))))
  ]);
}

class AssessmentPage extends StatefulWidget { const AssessmentPage({super.key}); @override State<AssessmentPage> createState() => _AssessmentPageState(); }
class _AssessmentPageState extends State<AssessmentPage> {
  List<Map<String, Object?>> students = []; int? studentId; final chapter = TextEditingController(); final practical = TextEditingController(text: '0'); final theory = TextEditingController(text: '0'); final discipline = TextEditingController(text: '0'); final notes = TextEditingController();
  List<Map<String, Object?>> recent = [];
  @override void initState() { super.initState(); load(); }
  Future<void> load() async { students = await LocalDb.instance.students(); recent = await LocalDb.instance.assessments(); studentId ??= students.isEmpty ? null : students.first['id'] as int; if (mounted) setState(() {}); }
  double parseScore(TextEditingController c) => double.tryParse(c.text.replaceAll(',', '.')) ?? 0;
  Future<void> save() async { if (studentId == null || chapter.text.trim().isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Choisissez un élève et saisissez le chapitre.'))); return; } if (parseScore(practical)>70 || parseScore(theory)>20 || parseScore(discipline)>10 || parseScore(practical)<0 || parseScore(theory)<0 || parseScore(discipline)<0) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Barème : pratique /70, théorie /20, discipline-présence /10.'))); return; }
    await LocalDb.instance.addAssessment(studentId: studentId!, chapter: chapter.text, practical: parseScore(practical), theory: parseScore(theory), discipline: parseScore(discipline), notes: notes.text); chapter.clear(); notes.clear(); await load(); }
  String decision(double total) => total >= 70 ? 'Validé' : total >= 50 ? 'Rattrapage ciblé' : 'Reprise du cycle';
  @override Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(16), children: [Text('Évaluation de chapitre', style: Theme.of(context).textTheme.titleLarge), const SizedBox(height: 10),
    if (students.isEmpty) const Text('Ajoutez un élève dans l’onglet Élèves avant de noter.'),
    if (students.isNotEmpty) DropdownButtonFormField<int>(value: studentId, decoration: const InputDecoration(labelText: 'Élève'), items: students.map((s) => DropdownMenuItem(value: s['id'] as int, child: Text('${s['name']}'))).toList(), onChanged: (v) => setState(() => studentId = v)), const SizedBox(height: 8),
    TextField(controller: chapter, decoration: const InputDecoration(labelText: 'Chapitre évalué', border: OutlineInputBorder())), const SizedBox(height: 8),
    Row(children: [Expanded(child: TextField(controller: practical, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Pratique /70', border: OutlineInputBorder()))), const SizedBox(width: 8), Expanded(child: TextField(controller: theory, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Théorie /20', border: OutlineInputBorder()))), const SizedBox(width: 8), Expanded(child: TextField(controller: discipline, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Discipline /10', border: OutlineInputBorder())))]), const SizedBox(height: 8),
    TextField(controller: notes, maxLines: 2, decoration: const InputDecoration(labelText: 'Observations / exercice de reprise', border: OutlineInputBorder())), const SizedBox(height: 8), FilledButton.icon(onPressed: save, icon: const Icon(Icons.save), label: const Text('Enregistrer l’évaluation')), const Divider(height: 28), Text('Historique des évaluations', style: Theme.of(context).textTheme.titleMedium),
    ...recent.map((r) { final total = (r['total'] as num?)?.toDouble() ?? 0; return Card(child: ListTile(title: Text('${r['student']} — ${r['chapter']}'), subtitle: Text('Pratique ${r['practical']}/70 • Théorie ${r['theory']}/20 • Discipline ${r['discipline']}/10\n${decision(total)} • ${r['notes']}'), isThreeLine: true, trailing: Text('${total.toStringAsFixed(0)}/100'))); })
  ]);
}

class ExportPage extends StatelessWidget { const ExportPage({super.key});
  Future<void> run(BuildContext context, Future<void> Function() fn) async { try { await fn(); if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fichier créé. Choisissez une application pour le partager ou l’enregistrer.'))); } catch (e) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur d’export : $e'))); } }
  @override Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(16), children: [Text('Exporter les données', style: Theme.of(context).textTheme.titleLarge), const SizedBox(height: 8), const Text('Les fichiers contiennent les élèves, les devoirs et leurs statuts, ainsi que les évaluations enregistrées sur cet appareil.'), const SizedBox(height: 18), Card(child: ListTile(leading: const Icon(Icons.picture_as_pdf, size: 32), title: const Text('Exporter en PDF'), subtitle: const Text('Rapport lisible et imprimable'), trailing: const Icon(Icons.chevron_right), onTap: () => run(context, Exporter.exportPdf))), Card(child: ListTile(leading: const Icon(Icons.table_chart, size: 32), title: const Text('Exporter en Excel (.xlsx)'), subtitle: const Text('Feuilles séparées pour élèves, devoirs et évaluations'), trailing: const Icon(Icons.chevron_right), onTap: () => run(context, Exporter.exportExcel))), Card(child: ListTile(leading: const Icon(Icons.description, size: 32), title: const Text('Exporter en Word (.docx)'), subtitle: const Text('Rapport modifiable dans Microsoft Word ou LibreOffice'), trailing: const Icon(Icons.chevron_right), onTap: () => run(context, Exporter.exportWord))), const SizedBox(height: 12), const Text('Important : gardez régulièrement une copie des exports dans un autre emplacement. Les données de l’application restent locales à l’appareil.'),]);
}

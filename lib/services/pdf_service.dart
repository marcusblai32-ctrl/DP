import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Ligne de note d'un bulletin.
class ReportLine {
  const ReportLine({required this.title, required this.category, required this.date, required this.score, required this.max});
  final String title, category, date;
  final double score, max;
}

/// Données d'un bulletin scolaire (déjà éditées par l'utilisateur).
class ReportCardData {
  const ReportCardData({
    required this.schoolName,
    required this.schoolYear,
    required this.period,
    required this.teacher,
    required this.studentName,
    required this.level,
    required this.group,
    required this.lines,
    required this.average,
    required this.letter,
    required this.rank,
    required this.classSize,
    required this.absences,
    required this.lates,
    required this.excused,
    required this.appreciation,
    required this.observation,
    required this.date,
  });

  final String schoolName, schoolYear, period, teacher, studentName, level, group;
  final List<ReportLine> lines;
  final double average;
  final String letter;
  final int rank, classSize, absences, lates, excused;
  final String appreciation, observation, date;
}

/// Question d'examen prête pour le PDF.
class ExamPdfQuestion {
  const ExamPdfQuestion({
    required this.prompt,
    required this.category,
    required this.choices,
    required this.correct,
    required this.answer,
    required this.points,
    this.image,
  });
  final String prompt, category, answer;
  final List<String> choices;
  final List<int> correct;
  final double points;
  final Uint8List? image;
}

/// Options d'en-tête d'un examen.
class ExamPdfOptions {
  const ExamPdfOptions({
    required this.schoolName,
    required this.schoolYear,
    required this.title,
    required this.subject,
    required this.level,
    required this.group,
    required this.date,
    required this.duration,
    required this.instructions,
    required this.answerKey,
  });
  final String schoolName, schoolYear, title, subject, level, group, date, duration, instructions;
  final bool answerKey;
}

/// Génération des PDF (bulletin scolaire et examen). Police standard Latin-1 :
/// les caractères typographiques sont ramenés à leur équivalent simple.
class PdfService {
  const PdfService._();

  static final PdfColor _red = PdfColor.fromHex('#B3162B');
  static final PdfColor _ink = PdfColor.fromHex('#1B1D22');
  static final PdfColor _grey = PdfColor.fromHex('#5F6672');
  static final PdfColor _light = PdfColor.fromHex('#F1F2F5');
  static final PdfColor _line = PdfColor.fromHex('#9AA0AC');

  static String _t(String s) => s
      .replaceAll('\u2019', "'")
      .replaceAll('\u2018', "'")
      .replaceAll('\u201C', '"')
      .replaceAll('\u201D', '"')
      .replaceAll('\u2013', '-')
      .replaceAll('\u2014', '-')
      .replaceAll('\u2026', '...')
      .replaceAll('\u0153', 'oe')
      .replaceAll('\u0152', 'OE')
      .replaceAll('\u00A0', ' ')
      .replaceAll('\u202F', ' ');

  static String _n(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1).replaceAll('.', ',');
  static String _n2(double v) => v.toStringAsFixed(2).replaceAll('.', ',');

  static String mention(String letter) {
    switch (letter) {
      case 'A':
        return 'Excellent';
      case 'B':
        return 'Tres bien';
      case 'C':
        return 'Bien';
      case 'D':
        return 'Passable';
      default:
        return 'Insuffisant';
    }
  }

  static String _fmtDate(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  static pw.Widget _footer(pw.Context c, String school, {String prefix = ''}) => pw.Container(
        padding: const pw.EdgeInsets.only(top: 6),
        decoration: pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(color: _line, width: .5))),
        child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Text(_t('$prefix$school'), style: pw.TextStyle(fontSize: 8, color: _grey)),
          pw.Text('Page ${c.pageNumber} / ${c.pagesCount}', style: pw.TextStyle(fontSize: 8, color: _grey)),
        ]),
      );

  static pw.Widget _cell(String text, {bool bold = false, PdfColor? color, pw.TextAlign align = pw.TextAlign.left, double size = 10}) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        child: pw.Text(_t(text), textAlign: align, style: pw.TextStyle(fontSize: size, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal, color: color ?? _ink)),
      );

  // ---------------------------------------------------------------------------
  // Bulletin scolaire
  // ---------------------------------------------------------------------------

  static pw.Widget _statBox(String label, String value, {String? sub}) => pw.Expanded(
        child: pw.Container(
          padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          decoration: pw.BoxDecoration(color: _light, border: pw.Border.all(color: _line, width: .6)),
          child: pw.Column(children: [
            pw.Text(_t(label), style: pw.TextStyle(fontSize: 8.5, color: _grey)),
            pw.SizedBox(height: 3),
            pw.Text(_t(value), style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold, color: _red)),
            if (sub != null) pw.Text(_t(sub), style: pw.TextStyle(fontSize: 8.5, color: _grey)),
          ]),
        ),
      );

  static pw.Widget _textBox(String title, String text, {double minHeight = 52}) => pw.Container(
        width: double.infinity,
        constraints: pw.BoxConstraints(minHeight: minHeight),
        padding: const pw.EdgeInsets.all(8),
        decoration: pw.BoxDecoration(border: pw.Border.all(color: _line, width: .6)),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text(_t(title), style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: _red)),
          pw.SizedBox(height: 4),
          pw.Text(_t(text), style: const pw.TextStyle(fontSize: 10)),
        ]),
      );

  static pw.Widget _signature(String label) => pw.Expanded(
        child: pw.Container(
          height: 64,
          margin: const pw.EdgeInsets.symmetric(horizontal: 4),
          padding: const pw.EdgeInsets.all(6),
          decoration: pw.BoxDecoration(border: pw.Border.all(color: _line, width: .6)),
          child: pw.Text(_t(label), style: pw.TextStyle(fontSize: 9, color: _grey)),
        ),
      );

  static void _addReportPage(pw.Document doc, ReportCardData d) {

    final header = pw.TableRow(
      decoration: pw.BoxDecoration(color: _red),
      children: [
        _cell('Evaluation', bold: true, color: PdfColors.white),
        _cell('Type', bold: true, color: PdfColors.white),
        _cell('Date', bold: true, color: PdfColors.white, align: pw.TextAlign.center),
        _cell('Note', bold: true, color: PdfColors.white, align: pw.TextAlign.center),
        _cell('Sur', bold: true, color: PdfColors.white, align: pw.TextAlign.center),
        _cell('%', bold: true, color: PdfColors.white, align: pw.TextAlign.center),
      ],
    );

    final rows = <pw.TableRow>[header];
    for (var i = 0; i < d.lines.length; i++) {
      final l = d.lines[i];
      final pct = l.max > 0 ? l.score / l.max * 100 : 0.0;
      rows.add(pw.TableRow(
        decoration: pw.BoxDecoration(color: i.isOdd ? _light : PdfColors.white),
        children: [
          _cell(l.title),
          _cell(l.category),
          _cell(_fmtDate(l.date), align: pw.TextAlign.center),
          _cell(_n(l.score), bold: true, align: pw.TextAlign.center),
          _cell(_n(l.max), align: pw.TextAlign.center),
          _cell('${_n(pct)} %', align: pw.TextAlign.center),
        ],
      ));
    }
    if (d.lines.isEmpty) {
      rows.add(pw.TableRow(children: [
        _cell('Aucune note enregistree pour cette periode.', color: _grey),
        _cell(''),
        _cell(''),
        _cell(''),
        _cell(''),
        _cell(''),
      ]));
    }

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(32, 28, 32, 32),
      footer: (c) => _footer(c, d.schoolName, prefix: 'Bulletin scolaire - '),
      build: (c) => [
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          decoration: pw.BoxDecoration(color: _red, borderRadius: pw.BorderRadius.circular(4)),
          child: pw.Column(children: [
            pw.Text(_t(d.schoolName.toUpperCase()), textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
            pw.SizedBox(height: 3),
            pw.Text(_t('Annee scolaire ${d.schoolYear}'), style: const pw.TextStyle(fontSize: 10, color: PdfColors.white)),
          ]),
        ),
        pw.SizedBox(height: 14),
        pw.Center(child: pw.Text('BULLETIN SCOLAIRE', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: _ink))),
        pw.Center(child: pw.Text(_t(d.period), style: pw.TextStyle(fontSize: 10, color: _grey))),
        pw.SizedBox(height: 12),
        pw.Table(
          border: pw.TableBorder.all(color: _line, width: .6),
          columnWidths: {0: const pw.FlexColumnWidth(3), 1: const pw.FlexColumnWidth(2), 2: const pw.FlexColumnWidth(2)},
          children: [
            pw.TableRow(children: [
              _cell('Eleve : ${d.studentName}', bold: true, size: 11),
              _cell('Niveau : ${d.level}'),
              _cell('Groupe : ${d.group}'),
            ]),
            pw.TableRow(children: [
              _cell('Titulaire : ${d.teacher.isEmpty ? '-' : d.teacher}'),
              _cell('Periode : ${d.period}'),
              _cell('Effectif : ${d.classSize}'),
            ]),
          ],
        ),
        pw.SizedBox(height: 14),
        pw.Table(
          border: pw.TableBorder.all(color: _line, width: .6),
          columnWidths: {
            0: const pw.FlexColumnWidth(4),
            1: const pw.FlexColumnWidth(2.2),
            2: const pw.FlexColumnWidth(2),
            3: const pw.FlexColumnWidth(1.3),
            4: const pw.FlexColumnWidth(1.1),
            5: const pw.FlexColumnWidth(1.4),
          },
          children: rows,
        ),
        pw.SizedBox(height: 14),
        pw.Row(children: [
          _statBox('MOYENNE GENERALE', '${_n2(d.average)} / 100', sub: '${_n2(d.average / 5)} / 20'),
          pw.SizedBox(width: 8),
          _statBox('RANG', d.classSize > 0 ? '${d.rank} / ${d.classSize}' : '-', sub: 'dans le groupe'),
          pw.SizedBox(width: 8),
          _statBox('MENTION', d.letter, sub: mention(d.letter)),
        ]),
        pw.SizedBox(height: 10),
        pw.Table(
          border: pw.TableBorder.all(color: _line, width: .6),
          children: [
            pw.TableRow(decoration: pw.BoxDecoration(color: _light), children: [
              _cell('Assiduite', bold: true),
              _cell('Absences : ${d.absences}', align: pw.TextAlign.center),
              _cell('Retards : ${d.lates}', align: pw.TextAlign.center),
              _cell('Absences excusees : ${d.excused}', align: pw.TextAlign.center),
            ]),
          ],
        ),
        pw.SizedBox(height: 10),
        _textBox('APPRECIATION GENERALE', d.appreciation, minHeight: 60),
        pw.SizedBox(height: 8),
        if (d.observation.trim().isNotEmpty) ...[
          _textBox('OBSERVATIONS', d.observation),
          pw.SizedBox(height: 8),
        ],
        pw.SizedBox(height: 10),
        pw.Align(alignment: pw.Alignment.centerRight, child: pw.Text(_t('Fait le ${_fmtDate(d.date)}'), style: const pw.TextStyle(fontSize: 10))),
        pw.SizedBox(height: 6),
        pw.Row(children: [
          _signature('Le/La titulaire'),
          _signature('Le parent / tuteur'),
          _signature('La direction'),
        ]),
      ],
    ));
  }

  /// Génère un PDF contenant un bulletin par élève (une ou plusieurs pages chacun).
  static Future<Uint8List> buildReportCards(List<ReportCardData> cards) async {
    final first = cards.isEmpty ? null : cards.first;
    final doc = pw.Document(
      title: _t(cards.length == 1 ? 'Bulletin - ${first!.studentName}' : 'Bulletins scolaires'),
      author: _t(first?.schoolName ?? ''),
    );
    for (final card in cards) {
      _addReportPage(doc, card);
    }
    return doc.save();
  }

  static Future<Uint8List> buildReportCard(ReportCardData d) => buildReportCards([d]);

  // ---------------------------------------------------------------------------
  // Examen
  // ---------------------------------------------------------------------------

  static pw.Widget _idCell(String label, {String value = ''}) => pw.Container(
        height: 30,
        alignment: pw.Alignment.centerLeft,
        padding: const pw.EdgeInsets.symmetric(horizontal: 8),
        child: pw.Row(children: [
          pw.Text(_t(label), style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(width: 6),
          pw.Expanded(child: pw.Text(_t(value), style: const pw.TextStyle(fontSize: 10))),
        ]),
      );

  static pw.Widget _examHeader(ExamPdfOptions o, String heading, double total) {
    return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
        pw.Expanded(
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text(_t(o.schoolName.toUpperCase()), style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: _red)),
            pw.Text(_t('Annee scolaire ${o.schoolYear}'), style: pw.TextStyle(fontSize: 10, color: _grey)),
          ]),
        ),
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: pw.BoxDecoration(border: pw.Border.all(color: _ink, width: 1.2)),
          child: pw.Text(_t(heading.toUpperCase()), style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
        ),
      ]),
      pw.Divider(thickness: 2, color: _red, height: 14),
      pw.Table(
        border: pw.TableBorder.all(color: _ink, width: .8),
        children: [
          pw.TableRow(children: [_idCell('Nom :'), _idCell('Prenom :')]),
          pw.TableRow(children: [_idCell('Classe :', value: o.level), _idCell('Groupe :', value: o.group)]),
          pw.TableRow(children: [_idCell('Date :', value: o.date), _idCell('Duree :', value: o.duration)]),
          pw.TableRow(children: [
            _idCell('Matiere :', value: o.subject),
            _idCell('Note :', value: '............ / ${_n(total)}'),
          ]),
        ],
      ),
    ]);
  }

  static pw.Widget _questionBlock(int number, ExamPdfQuestion q, bool key) {
    final isChoice = q.choices.isNotEmpty && (q.category == 'QCU' || q.category == 'QCM');
    final children = <pw.Widget>[
      pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Text('$number. ', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
        pw.Expanded(child: pw.Text(_t(q.prompt), style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold))),
        pw.SizedBox(width: 8),
        pw.Text('(${_n(q.points)} ${q.points > 1 ? 'pts' : 'pt'})', style: pw.TextStyle(fontSize: 9, color: _grey)),
      ]),
    ];

    if (isChoice) {
      children.add(pw.Padding(
        padding: const pw.EdgeInsets.only(left: 16, top: 1, bottom: 3),
        child: pw.Text(q.category == 'QCM' ? 'Plusieurs reponses possibles.' : 'Une seule reponse possible.',
            style: pw.TextStyle(fontSize: 8.5, color: _grey, fontStyle: pw.FontStyle.italic)),
      ));
    }

    if (q.image != null) {
      pw.Widget? img;
      try {
        img = pw.Container(
          alignment: pw.Alignment.center,
          margin: const pw.EdgeInsets.symmetric(vertical: 6),
          constraints: const pw.BoxConstraints(maxHeight: 170, maxWidth: 380),
          child: pw.Image(pw.MemoryImage(q.image!), fit: pw.BoxFit.contain),
        );
      } catch (_) {
        img = null;
      }
      if (img != null) children.add(pw.Center(child: img));
    }

    if (isChoice) {
      for (var i = 0; i < q.choices.length; i++) {
        final isCorrect = q.correct.contains(i);
        final letter = i < 26 ? String.fromCharCode(65 + i) : '${i + 1}';
        children.add(pw.Padding(
          padding: const pw.EdgeInsets.only(left: 16, top: 4),
          child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Container(
              width: 11,
              height: 11,
              margin: const pw.EdgeInsets.only(top: 1),
              decoration: pw.BoxDecoration(
                shape: q.category == 'QCU' ? pw.BoxShape.circle : pw.BoxShape.rectangle,
                color: (key && isCorrect) ? _ink : null,
                border: pw.Border.all(color: _ink, width: .8),
              ),
            ),
            pw.SizedBox(width: 8),
            pw.Expanded(
              child: pw.Text('$letter. ${_t(q.choices[i])}',
                  style: pw.TextStyle(fontSize: 10.5, fontWeight: (key && isCorrect) ? pw.FontWeight.bold : pw.FontWeight.normal)),
            ),
          ]),
        ));
      }
    } else if (key) {
      children.add(pw.Container(
        width: double.infinity,
        margin: const pw.EdgeInsets.only(left: 16, top: 6),
        padding: const pw.EdgeInsets.all(6),
        decoration: pw.BoxDecoration(color: _light, border: pw.Border.all(color: _line, width: .5)),
        child: pw.Text(_t('Reponse attendue : ${q.answer.isEmpty ? '-' : q.answer}'), style: const pw.TextStyle(fontSize: 10)),
      ));
    } else {
      final lines = q.category == 'Subjectif' ? 6 : (q.category == 'Définition' ? 3 : 1);
      for (var i = 0; i < lines; i++) {
        children.add(pw.Container(
          height: 22,
          margin: const pw.EdgeInsets.only(left: 16),
          decoration: pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: _line, width: .6))),
        ));
      }
    }

    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 14),
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: children),
    );
  }

  static Future<Uint8List> buildExam(ExamPdfOptions o, List<ExamPdfQuestion> questions) async {
    final total = questions.fold<double>(0, (sum, q) => sum + q.points);
    final heading = o.answerKey ? 'Corrigé - ${o.title}' : o.title;
    final doc = pw.Document(title: _t('${o.title} - ${o.subject}'), author: _t(o.schoolName));

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(36, 30, 36, 34),
      header: (c) => c.pageNumber == 1
          ? pw.SizedBox()
          : pw.Container(
              padding: const pw.EdgeInsets.only(bottom: 6),
              margin: const pw.EdgeInsets.only(bottom: 10),
              decoration: pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: _line, width: .5))),
              child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                pw.Text(_t(o.schoolName.toUpperCase()), style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: _red)),
                pw.Text(_t('${heading.toUpperCase()}${o.subject.isEmpty ? '' : ' - ${o.subject}'}'), style: pw.TextStyle(fontSize: 9, color: _grey)),
                pw.Text('Nom : ........................', style: pw.TextStyle(fontSize: 9, color: _grey)),
              ]),
            ),
      footer: (c) => _footer(c, o.schoolName),
      build: (c) => [
        _examHeader(o, heading, total),
        pw.SizedBox(height: 10),
        if (!o.answerKey && o.instructions.trim().isNotEmpty) ...[
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(color: _light, border: pw.Border.all(color: _line, width: .6)),
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text('CONSIGNES', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: _red)),
              pw.SizedBox(height: 3),
              pw.Text(_t(o.instructions), style: const pw.TextStyle(fontSize: 9.5)),
            ]),
          ),
          pw.SizedBox(height: 8),
        ],
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(_t('Bareme total : ${_n(total)} points'), style: pw.TextStyle(fontSize: 9, color: _grey)),
        ),
        pw.SizedBox(height: 10),
        for (var i = 0; i < questions.length; i++) _questionBlock(i + 1, questions[i], o.answerKey),
        pw.Center(child: pw.Text('Fin de l\'epreuve', style: pw.TextStyle(fontSize: 9, color: _grey, fontStyle: pw.FontStyle.italic))),
      ],
    ));
    return doc.save();
  }
}

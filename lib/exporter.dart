import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cross_file/cross_file.dart';
import 'database.dart';

class Exporter {
  static Future<List<Map<String, Object?>>> _collect() async {
    final db = LocalDb.instance;
    return [
      {'section': 'ÉLÈVES', 'rows': await db.allStudentsForExport()},
      {'section': 'DEVOIRS ET STATUTS', 'rows': await db.statusRows()},
      {'section': 'ÉVALUATIONS', 'rows': await db.assessments()},
    ];
  }

  static Future<Directory> _dir() async => getApplicationDocumentsDirectory();
  static Future<void> _share(File file) async => Share.shareXFiles([XFile(file.path)], text: 'Export Dimension Production');

  static Future<void> exportPdf() async {
    final sections = await _collect();
    final doc = pw.Document();
    for (final section in sections) {
      final rows = (section['rows'] as List).cast<Map<String, Object?>>();
      doc.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        build: (_) => [
          pw.Text('DIMENSION PRODUCTION — SUIVI DES ÉLÈVES', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.Text(section['section'] as String, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          if (rows.isEmpty) pw.Text('Aucune donnée enregistrée.') else pw.TableHelper.fromTextArray(
            headers: rows.first.keys.toList(),
            data: rows.map((r) => r.values.map((v) => v?.toString() ?? '').toList()).toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
            cellStyle: const pw.TextStyle(fontSize: 7),
            cellAlignment: pw.Alignment.centerLeft,
          ),
        ],
      ));
    }
    final file = File('${(await _dir()).path}/dimension_production_suivi.pdf');
    await file.writeAsBytes(await doc.save());
    await _share(file);
  }

  static Future<void> exportExcel() async {
    final sections = await _collect();
    final excel = Excel.createExcel();
    final firstName = excel.getDefaultSheet() ?? 'Élèves';
    for (var i = 0; i < sections.length; i++) {
      final section = sections[i];
      final name = (section['section'] as String).length > 31 ? (section['section'] as String).substring(0, 31) : section['section'] as String;
      final sheet = i == 0 ? excel[firstName] : excel[name];
      final rows = (section['rows'] as List).cast<Map<String, Object?>>();
      if (rows.isEmpty) {
        sheet.appendRow([TextCellValue('Aucune donnée enregistrée')]);
      } else {
        sheet.appendRow(rows.first.keys.map((k) => TextCellValue(k)).toList());
        for (final row in rows) {
          sheet.appendRow(row.values.map((v) => TextCellValue(v?.toString() ?? '')).toList());
        }
      }
    }
    final bytes = excel.encode();
    if (bytes == null) throw Exception('Impossible de créer le fichier Excel.');
    final file = File('${(await _dir()).path}/dimension_production_suivi.xlsx');
    await file.writeAsBytes(bytes);
    await _share(file);
  }

  static String _xml(String s) => const HtmlEscape().convert(s);
  static String _paragraph(String text) => '<w:p><w:r><w:t xml:space="preserve">${_xml(text)}</w:t></w:r></w:p>';

  static Future<void> exportWord() async {
    final sections = await _collect();
    final body = StringBuffer();
    body.write(_paragraph('DIMENSION PRODUCTION — SUIVI DES ÉLÈVES'));
    body.write(_paragraph('Export généré le ${DateTime.now().toLocal()}'));
    for (final section in sections) {
      body.write(_paragraph(''));
      body.write(_paragraph(section['section'] as String));
      final rows = (section['rows'] as List).cast<Map<String, Object?>>();
      if (rows.isEmpty) {
        body.write(_paragraph('Aucune donnée enregistrée.'));
      } else {
        body.write(_paragraph(rows.first.keys.join(' | ')));
        for (final row in rows) {
          body.write(_paragraph(row.values.map((v) => v?.toString() ?? '').join(' | ')));
        }
      }
    }
    final documentXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body>${body.toString()}<w:sectPr><w:pgSz w:w="16838" w:h="11906" w:orient="landscape"/><w:pgMar w:top="720" w:right="720" w:bottom="720" w:left="720"/></w:sectPr></w:body></w:document>''';
    final contentTypes = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/></Types>''';
    final rels = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/></Relationships>''';
    final archive = Archive();
    void add(String name, String value) { final bytes = utf8.encode(value); archive.addFile(ArchiveFile(name, bytes.length, bytes)); }
    add('[Content_Types].xml', contentTypes);
    add('_rels/.rels', rels);
    add('word/document.xml', documentXml);
    final bytes = ZipEncoder().encode(archive);
    if (bytes == null) throw Exception('Impossible de créer le fichier Word.');
    final file = File('${(await _dir()).path}/dimension_production_suivi.docx');
    await file.writeAsBytes(Uint8List.fromList(bytes));
    await _share(file);
  }
}

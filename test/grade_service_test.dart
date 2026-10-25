import 'package:dp_scolaire/models/assessment.dart';
import 'package:dp_scolaire/models/grade_record.dart';
import 'package:dp_scolaire/models/student.dart';
import 'package:dp_scolaire/services/grade_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final student = Student('s1', 'Élève Test', 'Niveau 1', 'Groupe A');
  final out20 = Assessment('a1', 'Devoir 1', 'Devoir', 'Niveau 1', 'Groupe A', '2026-01-01', 'Manuel', 20);
  final out100 = Assessment('a2', 'Examen', 'Examen', 'Niveau 1', 'Groupe A', '2026-01-02', 'Manuel', 100);
  final otherGroup = Assessment('a3', 'Autre', 'Devoir', 'Niveau 1', 'Groupe B', '2026-01-03', 'Manuel', 10);

  test('average normalizes every grade to 100', () {
    final grades = [GradeRecord('s1', 'a1', 15, ''), GradeRecord('s1', 'a2', 50, '')];
    expect(GradeService.average(student, grades, [out20, out100]), closeTo(62.5, 0.001));
  });

  test('average ignores assessments of another group and unknown ones', () {
    final grades = [GradeRecord('s1', 'a3', 10, ''), GradeRecord('s1', 'zz', 10, '')];
    expect(GradeService.average(student, grades, [otherGroup]), 0);
  });

  test('letter grade thresholds', () {
    expect(GradeService.letterGrade(90), 'A');
    expect(GradeService.letterGrade(80), 'B');
    expect(GradeService.letterGrade(70), 'C');
    expect(GradeService.letterGrade(60), 'D');
    expect(GradeService.letterGrade(59.9), 'F');
  });
}

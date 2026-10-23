import '../models/assessment.dart';
import '../models/grade_record.dart';
import '../models/student.dart';

/// Centralise les calculs de notes de DP Scolaire.
/// Les notes sont ramenées sur 100 avant le calcul de la moyenne.
class GradeService {
  const GradeService._();

  static double average(Student student, List<GradeRecord> grades,
      List<Assessment> assessments) {
    final assessmentById = {for (final assessment in assessments) assessment.id: assessment};
    final relevant = grades.where((grade) {
      final assessment = assessmentById[grade.assessmentId];
      return grade.studentId == student.id && assessment != null &&
          assessment.level == student.level && assessment.group == student.group;
    }).toList();
    if (relevant.isEmpty) return 0;
    var total = 0.0;
    for (final grade in relevant) {
      final assessment = assessmentById[grade.assessmentId]!;
      if (assessment.maxScore > 0) {
        total += (grade.score / assessment.maxScore) * 100;
      }
    }
    return total / relevant.length;
  }

  static String letterGrade(double average) {
    if (average >= 90) return 'A';
    if (average >= 80) return 'B';
    if (average >= 70) return 'C';
    if (average >= 60) return 'D';
    return 'F';
  }
}

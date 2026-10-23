// DP Scolaire — modèle de données.
class GradeRecord {
  String studentId, assessmentId, note;
  double score;
  GradeRecord(this.studentId, this.assessmentId, this.score, this.note);
  Map<String, dynamic> toJson() => {'studentId': studentId, 'assessmentId': assessmentId, 'score': score, 'note': note};
  factory GradeRecord.fromJson(Map<String, dynamic> j) =>
      GradeRecord(j['studentId'] ?? '', j['assessmentId'] ?? '', (j['score'] as num?)?.toDouble() ?? 0, j['note'] ?? '');
}

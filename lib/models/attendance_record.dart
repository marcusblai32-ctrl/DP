// DP Scolaire — modèle de données.
class AttendanceRecord {
  String studentId, date, status, note;
  AttendanceRecord(this.studentId, this.date, this.status, this.note);
  Map<String, dynamic> toJson() => {'studentId': studentId, 'date': date, 'status': status, 'note': note};
  factory AttendanceRecord.fromJson(Map<String, dynamic> j) =>
      AttendanceRecord(j['studentId'] ?? '', j['date'] ?? '', j['status'] ?? 'Présent', j['note'] ?? '');
}

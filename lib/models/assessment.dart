// DP Scolaire — modèle de données.
class Assessment {
  String id, title, category, level, group, date, type;
  double maxScore;
  Assessment(this.id, this.title, this.category, this.level, this.group, this.date, this.type, this.maxScore);
  Map<String, dynamic> toJson() => {
    'id': id, 'title': title, 'category': category, 'level': level,
    'group': group, 'date': date, 'type': type, 'maxScore': maxScore
  };
  factory Assessment.fromJson(Map<String, dynamic> j) => Assessment(
    j['id'] ?? '', j['title'] ?? '', j['category'] ?? 'Examen',
    j['level'] ?? '', j['group'] ?? '', j['date'] ?? '',
    j['type'] ?? 'QCU', (j['maxScore'] as num?)?.toDouble() ?? 100,
  );
}

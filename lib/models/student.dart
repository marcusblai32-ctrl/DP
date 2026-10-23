// DP Scolaire — modèle de données.
class Student {
  String id, name, level, group;
  Student(this.id, this.name, this.level, this.group);
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'level': level, 'group': group};
  factory Student.fromJson(Map<String, dynamic> j) =>
      Student(j['id'] ?? '', j['name'] ?? '', j['level'] ?? '', j['group'] ?? '');
}

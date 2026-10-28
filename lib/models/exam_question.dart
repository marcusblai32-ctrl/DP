// DP Scolaire — modèle de données.
class ExamQuestion {
  String prompt, category;
  List<String> choices;

  /// Pour QCU/QCM : texte(s) des bonnes réponses séparés par « | ».
  /// Pour les autres catégories : réponse attendue / corrigé.
  String answer;
  double points;

  /// Nom du fichier image (dans le dossier dp_images), vide si aucune image.
  String imageFile;

  ExamQuestion(this.prompt, this.category, this.choices, this.answer, this.points, {this.imageFile = ''});

  bool get hasChoices => category == 'QCU' || category == 'QCM';

  /// Indices des bonnes réponses parmi [choices].
  List<int> get correctIndexes {
    if (choices.isEmpty) return [];
    final parts = answer.split('|').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    final result = <int>[];
    for (var i = 0; i < choices.length; i++) {
      if (parts.contains(choices[i].trim())) result.add(i);
    }
    if (result.isEmpty) {
      // Anciennes données : réponse saisie sous forme de lettre (A, B, C…).
      for (final part in parts) {
        if (part.length == 1) {
          final idx = part.toUpperCase().codeUnitAt(0) - 65;
          if (idx >= 0 && idx < choices.length && !result.contains(idx)) result.add(idx);
        }
      }
    }
    return result;
  }

  Map<String, dynamic> toJson() => {
        'prompt': prompt,
        'category': category,
        'choices': choices,
        'answer': answer,
        'points': points,
        'imageFile': imageFile,
      };

  factory ExamQuestion.fromJson(Map<String, dynamic> j) => ExamQuestion(
        (j['prompt'] ?? '').toString(),
        (j['category'] ?? 'QCU').toString(),
        List<String>.from(j['choices'] ?? []),
        (j['answer'] ?? '').toString(),
        (j['points'] as num?)?.toDouble() ?? 1,
        imageFile: (j['imageFile'] ?? '').toString(),
      );
}

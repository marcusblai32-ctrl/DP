// DP Scolaire — modèle de données.
class ExamQuestion {
  String prompt, category;
  List<String> choices;
  String answer;
  double points;
  ExamQuestion(this.prompt, this.category, this.choices, this.answer, this.points);
  Map<String, dynamic> toJson() => {'prompt': prompt, 'category': category, 'choices': choices, 'answer': answer, 'points': points};
}

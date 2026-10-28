import 'package:dp_scolaire/models/exam_question.dart';
import 'package:dp_scolaire/services/notification_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ExamQuestion', () {
    test('QCM : plusieurs bonnes réponses retrouvées par leur texte', () {
      final q = ExamQuestion('Q', 'QCM', ['Un', 'Deux', 'Trois', 'Quatre'], 'Deux | Trois', 2);
      expect(q.hasChoices, isTrue);
      expect(q.correctIndexes, [1, 2]);
    });

    test('ancienne réponse sous forme de lettre', () {
      final q = ExamQuestion('Q', 'QCU', ['a', 'b', 'c'], 'C', 1);
      expect(q.correctIndexes, [2]);
    });

    test('nombre de choix libre et conversion JSON avec image', () {
      final choices = List.generate(9, (i) => 'Choix $i');
      final q = ExamQuestion('Énoncé', 'QCU', choices, 'Choix 8', 1.5, imageFile: 'q_1.png');
      final copy = ExamQuestion.fromJson(q.toJson());
      expect(copy.choices.length, 9);
      expect(copy.correctIndexes, [8]);
      expect(copy.imageFile, 'q_1.png');
      expect(copy.points, 1.5);
    });

    test('question sans choix : pas de bonnes réponses par indice', () {
      final q = ExamQuestion('Q', 'Définition', [], 'Texte', 1);
      expect(q.hasChoices, isFalse);
      expect(q.correctIndexes, isEmpty);
    });
  });

  group('NotificationService.dueTime', () {
    test('soustrait l\'avance choisie', () {
      final due = NotificationService.dueTime({'date': '2026-11-02', 'time': '09:30', 'lead': 30});
      expect(due, DateTime(2026, 11, 2, 9, 0));
    });

    test('date invalide : aucune échéance', () {
      expect(NotificationService.dueTime({'date': 'x', 'time': '09:30'}), isNull);
    });

    test('identifiant de notification stable', () {
      final a = NotificationService.notifId({'id': '12345'});
      final b = NotificationService.notifId({'id': '12345'});
      expect(a, b);
      expect(a, isNonNegative);
    });
  });
}

DP SCOLAIRE — CORRECTION DE L'ERREUR flutter analyze

Ce ZIP contient uniquement les fichiers à remplacer :

1. lib/main.dart
   - Corrige la parenthèse manquante à la ligne de la liste des évaluations.
   - Met à jour DropdownButtonFormField pour utiliser initialValue.
   - Corrige les vérifications de BuildContext après des opérations asynchrones.

2. lib/database/database_helper.dart
   - Retire l'import sqflite redondant signalé par l'analyseur.

3. test/widget_test.dart
   - Remplace la référence obsolète à MyApp par SchoolApp, qui est le nom réel de l'application.

Copiez les fichiers en conservant exactement les chemins, puis poussez vers GitHub. Le workflow devrait alors passer l'analyse syntaxique. Les avertissements informatifs restants, s'il y en a, ne sont pas bloquants avec --no-fatal-infos --no-fatal-warnings.

Important : Flutter n'est pas installé dans l'environnement de préparation, donc cette correction n'a pas été compilée ici. Vérifiez le prochain journal GitHub Actions.

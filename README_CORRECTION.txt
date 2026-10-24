DP — CORRECTION DU BUILD

Fichiers à remplacer à la racine du dépôt :
- pubspec.yaml
- lib/main.dart

Corrections :
1. Ajout des dépendances path, sqflite et sqflite_common_ffi requises par lib/database/database_helper.dart.
2. Ajout de la parenthèse fermante manquante dans la page Évaluations et notes (main.dart).

Après avoir appliqué les deux fichiers :
1. Ouvrir le dépôt GitHub et remplacer les fichiers aux chemins indiqués.
2. Lancer GitHub Actions (workflow Build DP Android + Windows).
3. Si une nouvelle erreur apparaît, envoyer le log complet du premier bloc « error ».

Note : la page principale utilise encore SharedPreferences pour charger/sauvegarder les données. Le DatabaseHelper SQLite est présent mais n'est pas encore branché à l'interface; ce patch corrige sa compilation, il ne migre pas les données vers SQLite.

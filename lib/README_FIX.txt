DP — patch de correction de l'analyse GitHub Actions

Remplacer uniquement ces fichiers aux mêmes chemins dans le dépôt :
- lib/main.dart : correction de parenthèse manquante vers la ligne 653.
- pubspec.yaml : ajout des dépendances path, sqflite et sqflite_common_ffi utilisées par lib/database/database_helper.dart.
- .github/workflows/build.yml : conserve la configuration d'icône Android/Windows et les étapes de build existantes.

Puis commit/push et relancer GitHub Actions. Les avertissements (deprecated_member_use et use_build_context_synchronously) ne sont pas les erreurs bloquantes signalées ici.

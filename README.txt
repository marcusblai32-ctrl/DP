DP — patch de correction ciblé

Contenu à copier dans le dépôt GitHub en conservant exactement les chemins :
- .github/workflows/build.yml
- pubspec.yaml
- flutter_launcher_icons_android.yaml
- flutter_launcher_icons_windows.yaml

Important : le logo existant doit être à assets/dp_icon.png à la racine du dépôt.
Ne remplacez pas le dossier assets ni le reste du projet.

Ce patch sépare la génération d'icônes Android et Windows pour éviter que le job Windows cherche AndroidManifest.xml. Il ajoute aussi les dépendances SQLite/path utilisées par lib/database/database_helper.dart.

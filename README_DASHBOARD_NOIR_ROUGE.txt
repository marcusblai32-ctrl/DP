DP Scolaire — patch dashboard Android noir/rouge

Fichiers à remplacer/ajouter à la racine du dépôt GitHub :
- lib/main.dart (remplacer)
- pubspec.yaml (remplacer)
- .github/workflows/build.yml (remplacer)
- flutter_launcher_icons_android.yaml (ajouter/remplacer)
- flutter_launcher_icons_windows.yaml (ajouter/remplacer)

Fonctions incluses dans cette version :
- interface adaptative téléphone portrait / écran large, thème noir et rouge ;
- cartes de statistiques et actions rapides de dimensions cohérentes ;
- graphique basé sur les moyennes disponibles ;
- classement général des élèves avec rang 1, 2, 3, etc. ;
- calendrier/liste des séances avec date, heure, lieu, note et statut terminé ;
- rappels visibles dans l'application et compteur de rappels non terminés ;
- fiches de préparation de cours avec objectif, matériel, déroulement et checklist ;
- sauvegarde et restauration des séances, rappels et préparations dans le JSON de sauvegarde ;
- workflow GitHub Actions qui produit l'APK Android et l'archive Windows, en gardant le nom de l'application « DP ».

Si les anciens fichiers `lib/exporter.dart` ou `lib/database.dart` existent encore dans le dépôt, supprimez-les comme demandé précédemment ; ce patch ne les réintroduit pas. Conservez `lib/database/database_helper.dart`.

Important : les rappels sont actuellement des rappels internes à l'application. Cette version ne programme pas encore de notifications système Android en arrière-plan lorsque l'application est fermée.

Après avoir appliqué les fichiers :
1. Ouvrir le projet à la racine (là où se trouve pubspec.yaml).
2. Exécuter `flutter pub get`.
3. Exécuter `flutter analyze` et `flutter test`.
4. Commit/push vers main ou master pour déclencher GitHub Actions.

Le build n'a pas pu être exécuté localement dans l'environnement de préparation ; confirmer le résultat dans GitHub Actions avant de distribuer l'APK.

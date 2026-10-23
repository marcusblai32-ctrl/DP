CORRECTION DU TEST DP SCOLAIRE

Le journal montre que le fichier fautif est lib/test/widget_test.dart.
Un test Flutter ne doit pas être placé dans lib/ : Flutter analyse alors
flutter_test comme une dépendance normale de l'application.

À faire dans le dépôt GitHub :
1. SUPPRIMER le fichier lib/test/widget_test.dart.
2. Garder/créer le fichier test/widget_test.dart à la racine du projet
   (au même niveau que lib/ et pubspec.yaml).
3. Remplacer son contenu par celui fourni dans test/widget_test.dart.
4. Vérifier dans pubspec.yaml que ceci existe sous dev_dependencies :

  flutter_test:
    sdk: flutter

5. Lancer flutter pub get puis relancer GitHub Actions.

Le test fait référence à SchoolApp, qui est la classe présente dans
lib/main.dart. Il ne faut pas utiliser MyApp.

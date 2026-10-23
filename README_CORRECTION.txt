DP SCOLAIRE - FICHIERS À REMPLACER / AJOUTER

Ce ZIP contient uniquement les fichiers concernés par la correction :

1. Remplacer pubspec.yaml à la racine du projet.
2. Remplacer lib/main.dart.
3. Ajouter/remplacer lib/database/database_helper.dart.
4. Remplacer .github/workflows/build.yml.

Correction de l'erreur flutter_launcher_icons :
Le workflow corrigé ne lance plus `dart run flutter_launcher_icons`, car cette commande n'est pas nécessaire pour construire l'APK ou la version Windows. Aucun package ni fichier d'icône n'est requis pour cette étape.

Après avoir copié ces fichiers dans le projet en conservant exactement les chemins :
- lancer `flutter pub get` localement si Flutter est installé ;
- pousser les modifications sur GitHub ;
- ouvrir l'onglet Actions et vérifier le résultat.

ATTENTION : la compilation n'a pas été exécutée ici. Vérifier les logs GitHub Actions avant de considérer la correction validée.

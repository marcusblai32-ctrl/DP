DP SCOLAIRE — PATCH TRANSFERT DE DONNÉES

Fichiers de ce ZIP :
1) pubspec.yaml : À REMPLACER à la racine du projet. Il conserve les dépendances du projet de référence et ajoute share_plus. Si votre pubspec.yaml a d’autres dépendances récentes, ne le remplacez pas aveuglément : ajoutez seulement `share_plus: ^10.1.4` sous `dependencies:`.
2) lib/main.dart : À REMPLACER dans lib/ pour le projet de référence DP Scolaire. Il ajoute importation JSON et partage du backup via le menu de partage Android/Windows.

Après remplacement : exécutez `flutter pub get`, puis vérifiez avec `flutter analyze`.

IMPORTANT : ce patch vise la version de référence DP_Scolaire_Complet qui utilise SharedPreferences. Il ne transforme pas la base de données en SQLite et n’ajoute pas encore de synchronisation automatique appareil-à-appareil. Le backup JSON peut être envoyé par Bluetooth, Quick Share, câble/USB, e-mail ou toute application de partage compatible; WhatsApp n’est pas obligatoire.
Avant d’importer, l’application demande confirmation car l’import remplace les données actuellement chargées par celles du fichier. Faites une sauvegarde d’abord.

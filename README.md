# DP — Dimension Production | Suivi hors ligne

Application Flutter de départ pour gérer les élèves, devoirs, statuts et évaluations sans connexion Internet. Les données sont enregistrées localement dans SQLite.

## Fonctions incluses
- Ajout/suppression d'élèves, avec Dimension et sous-groupe.
- Création de devoirs avec chapitre/pages, échéance et consignes.
- Enregistrement du statut d'un devoir pour un élève : AF, NR, R, V, AR, VAL.
- Évaluations par chapitre : pratique /70, théorie /20, discipline-présence /10.
- Décision automatique indicative : 70–100 validé ; 50–69 rattrapage ciblé ; 0–49 reprise du cycle.
- Export des données en PDF, Excel (.xlsx) et Word (.docx), via le menu de partage Android.
- Nom affiché sur Android : **DP**.
- Icône Android générée à partir de `assets/dp_icon.png` (image fournie).
- GitHub Actions pour compiler un APK Android automatiquement.

## Préparer le projet
1. Installez Flutter stable et Android Studio/Android SDK.
2. Créez la structure Android du projet en exécutant dans ce dossier : `flutter create --platforms=android .`
3. Lancez `flutter pub get`.
4. Lancez `flutter run` sur un appareil Android ou un émulateur.

## Générer l'APK sur GitHub
1. Envoyez le contenu de ce dossier (y compris `.github/`, `assets/`, `lib/` et `pubspec.yaml`) à la racine du dépôt GitHub `DP`. Ne téléversez pas seulement le dossier parent.
2. Dans l'onglet Actions, lancez **Build Android APK**, ou faites un push sur la branche `main`/`master`.
3. Téléchargez l'artifact `DP-android-apk` depuis l'exécution réussie.

## Limites de cette première version
- Les exports sont des rapports de données, pas encore des formulaires de certificat ou des bulletins graphiques personnalisés.
- Il n'y a pas encore d'importation depuis les anciens PDF/Word/Excel : ces formats sont prévus ici comme formats d'export. L'import/export de sauvegarde structurée devra être ajouté séparément.
- Les données restent sur le téléphone. Désinstaller l'application ou effacer ses données peut les supprimer : exportez régulièrement des copies.
- Les fonctions de suivi des statuts et les évaluations doivent être testées sur appareil réel avant usage officiel.

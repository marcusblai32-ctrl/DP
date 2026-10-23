# DP Scolaire — projet Flutter complet

Application Flutter/Dart de gestion scolaire locale, conçue pour Android et Windows. L'interface et les documents portent le nom **DP Scolaire**.

## Fonctions déjà présentes dans cette version
- Gestion des élèves, niveaux et groupes dynamiques.
- Appel avec statuts Présent, Absent, Retard et Excusé.
- Création des devoirs/évaluations et saisie des notes par élève.
- Banque de questions : QCU, QCM, Compléter, Définition et Subjectif.
- Génération aléatoire d'un sujet à partir de la banque, aperçu et impression PDF.
- Calcul des moyennes, notes en lettres et appréciations modifiables.
- Bulletin individuel PDF et palmarès exportable en CSV.
- Sauvegarde JSON et bouton de suppression de l'historique (les élèves, niveaux et groupes sont conservés).
- Données conservées localement sur chaque appareil avec SharedPreferences.
- Code de modèles et calculs séparés dans des fichiers Dart distincts.

## Limites à connaître
- Cette archive n'a pas été compilée dans l'environnement de création. Il faut vérifier les résultats GitHub Actions avant installation.
- Les données ne sont pas synchronisées entre le téléphone et le PC. Chaque installation possède ses propres données.
- La génération de sujet choisit parmi les questions saisies par l'utilisateur; elle ne crée pas de questions par IA.
- La correction automatique des réponses des élèves, les coefficients personnalisés, les modèles multiples de bulletins et les fiches d'évaluation PDF détaillées ne sont pas encore implémentés.
- Le palmarès actuel est global; il ne propose pas encore de filtres de classement par niveau/groupe.
- Le bouton d'appel permet de sélectionner le statut de chaque élève, mais cette version ne fournit pas encore des rapports statistiques avancés de présence.

## Générer l'APK Android et la version Windows avec GitHub
1. Décompressez tout le ZIP.
2. Importez **tout le contenu** du dossier `DP_Scolaire_Complet` dans le dépôt GitHub, en conservant le dossier caché `.github`.
3. Faites un commit/push vers la branche `main` ou `master`.
4. Dans le dépôt GitHub, ouvrez **Actions** puis le workflow **Build Android + Windows**.
5. Attendez que les deux tâches soient vertes.
6. Ouvrez l'exécution terminée, puis téléchargez les artefacts `dp-scolaire-android-apk` et `dp-scolaire-windows-release`.

### Installer
- Android : téléchargez l'artefact APK, extrayez-le si nécessaire, puis ouvrez le fichier APK sur le téléphone et autorisez l'installation depuis cette source si Android le demande.
- Windows : téléchargez et extrayez l'archive Windows. Conservez **tout** le contenu du dossier `Release`; lancez `dp_scolaire.exe` à l'intérieur. Ne déplacez pas l'EXE seul.

## Construction locale
Installez Flutter stable et les outils requis par la plateforme, puis lancez :

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --release
flutter build windows --release
```

La construction Windows doit se faire sous Windows avec les outils de compilation Windows installés.

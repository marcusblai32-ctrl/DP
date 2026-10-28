# DP — refonte UI/UX

Cette version conserve les fonctions, les données (SharedPreferences, mêmes clés), le format de sauvegarde JSON,
le logo `assets/dp_icon.png`, le nom « DP », `pubspec.yaml` et le workflow `.github/workflows/build.yml` **inchangés**.

## Nouveaux fichiers
- `lib/theme/app_theme.dart` : palette noir/rouge et thème Material 3 global (dialogues, menus, champs, boutons).
- `lib/widgets/` : `AppCard`, `PageHeader`, `PageScroll`, `EmptyState`, `DialogBody`/`confirmDialog`,
  `MetricTile`/`ActionTile`/`RankBadge`/`StatusPill`, `TrendChart`, `SectionTitle`.
- `test/grade_service_test.dart`, `test/widget_test.dart` (tests ajoutés/étendus).

## Corrections (défauts constatés dans le code d'origine)
- Les dialogues utilisaient le thème clair par défaut (le thème sombre n'était appliqué qu'au Scaffold) → thème global.
- Le bouton « Nouvelle évaluation » était un `FilledButton(onPressed: null)` (désactivé visuellement) → trois boutons explicites.
- L'écran « Préparation des cours » n'était accessible depuis aucune navigation → ajouté au menu/tiroir/barre latérale.
- La fenêtre « Faire l'appel » ne se rafraîchissait pas après un choix → `StatefulBuilder`.
- La saisie des notes pouvait modifier des notes en mémoire puis s'interrompre sur une valeur invalide → validation complète avant écriture ; virgule décimale acceptée.
- Le libellé « Matières » menait en réalité à « Évaluations et notes » → « Notes ».
- Les séances passées disparaissaient de l'écran Calendrier sans pouvoir être supprimées → section « Séances passées ».
- Export CSV : BOM UTF-8 (accents corrects dans Excel) et partage sur Android (dossier privé).
- Plus d'avertissements d'API dépréciées `withOpacity` / `activeColor`.

## Ajouts mineurs
Recherche d'élèves, suppression (avec confirmation) des évaluations, questions et rappels, sélecteur d'heure,
dates affichées en jj/mm/aaaa, messages de validation dans les formulaires.

## Non vérifié
Le code n'a pas pu être compilé ni analysé dans l'environnement de préparation (pas de SDK Flutter/Dart).
Lancez le workflow GitHub Actions « Build DP Android + Windows » et `flutter analyze` / `flutter test` pour confirmer.

## Mise à jour : documents PDF, questions et navigation
- **Bulletin scolaire** (`lib/services/pdf_service.dart`) : en-tête établissement (« Dimension Production » par défaut, modifiable),
  tableau des notes, moyenne /100 et /20, rang dans le groupe, mention, assiduité, appréciation, observations, signatures.
  Tout est modifiable avant l'impression (établissement, période, titulaire, date, notes, appréciation) sans toucher aux données.
- **Bulletins de la classe** : un seul PDF pour tous les élèves d'un niveau et d'un groupe (écran Rapports).
- **Examen** : en-tête « Dimension Production », cases Nom / Prénom / Classe / Date / Durée / Note, consignes, barème,
  numérotation des pages, version corrigé enseignant, retrait de questions avant impression.
- **Questions** : nombre de choix illimité (ajout / suppression), bonne(s) réponse(s) cochée(s), image PNG/JPEG dans l'énoncé,
  modification d'une question existante. Les images sont incluses dans la sauvegarde JSON.
- **Navigation** : le bouton « Plus » de la barre du bas est supprimé (doublon du menu en haut à gauche).
- Non compilé ni testé dans l'environnement de préparation : lancer `flutter analyze` et le workflow GitHub Actions.

## Mise à jour : rappels avec notification sonore
- Android : vraies notifications planifiées (canal « Rappels de cours », importance maximale, son + vibration),
  réaffichées au redémarrage du téléphone. `lib/services/notification_service.dart`.
- Avance au choix (à l'heure, 10 min, 30 min, 1 h, 1 jour), nouveau bouton « Nouveau rappel » et bouton « Tester le son ».
- Windows : alerte dans l'application avec bip lorsque DP est ouvert (pas de notification système).
- Dépendances ajoutées : `flutter_local_notifications` (version fixe 18.0.1, sans module Windows) et `timezone`.
- Workflow : une seule étape ajoutée (« Enable Android reminder notifications ») qui déclare les permissions Android
  et active le desugaring requis par le plugin. Rien d'autre n'a été modifié.
- Non compilé ni testé dans l'environnement de préparation.

## Mise à jour : packs de contenu
- « Importer un pack » (écrans Examens et Préparation des cours) : ajoute des questions et des préparations depuis un fichier
  JSON de format `dp_pack`, sans remplacer les données (les doublons sont ignorés).
- Le générateur d'examen accepte un mot-clé (ex. « Rythme », « Chap. 3 ») pour limiter les questions.
- Pack fourni : `DP_pack_Dimension2_Revision_Chap1-4_Prep_Chap6.json` (76 questions + 6 préparations).

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

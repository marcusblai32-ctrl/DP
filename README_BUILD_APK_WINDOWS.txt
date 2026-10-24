DP — GÉNÉRATION APK ANDROID ET WINDOWS

Ce dépôt contient un workflow GitHub Actions qui génère trois artefacts après exécution réussie :
1. DP-Android-APK : APK Android installable.
2. DP-Windows-ZIP : archive complète Windows avec le .exe, DLL et ressources nécessaires.
3. DP-Windows-EXE : le fichier .exe seul, pour accès rapide.

IMPORTANT : l'application Flutter Windows a besoin des DLL et ressources qui accompagnent le .exe. Pour exécuter l'application, télécharger DP-Windows-ZIP et extraire TOUS les fichiers dans un même dossier. Le .exe seul ne suffit généralement pas.

Pour lancer le build :
1. Téléverser le contenu de DP-main sur GitHub (ou remplacer les fichiers du dépôt existant).
2. Ouvrir l'onglet Actions du dépôt GitHub.
3. Choisir « Build DP Android + Windows ».
4. Cliquer « Run workflow » et attendre que les deux jobs soient verts.
5. Ouvrir l'exécution terminée et télécharger les artefacts dans la section Artifacts.

La compilation n'est pas exécutée dans cet environnement : les artefacts ne seront disponibles qu'après un build GitHub Actions réussi.

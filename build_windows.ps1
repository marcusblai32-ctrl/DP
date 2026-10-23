$ErrorActionPreference = "Stop"
Write-Host "Vérification de Flutter..."
flutter doctor
Write-Host "Activation de Windows Desktop..."
flutter config --enable-windows-desktop
Write-Host "Préparation des fichiers Windows..."
flutter create --platforms=windows .
Write-Host "Téléchargement des dépendances..."
flutter pub get
Write-Host "Compilation EXE Release..."
flutter build windows --release
Write-Host ""
Write-Host "Compilation terminée."
Write-Host "Le dossier à copier est : build\windows\x64\runner\Release\"

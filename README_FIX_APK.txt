DP Scolaire — APK compileSdk fix v2

Replace the repository file:
  .github/workflows/build.yml

This workflow runs flutter pub get first, then updates compileSdk declarations
in generated Android Gradle files and cached Flutter plugin Gradle files to API 36.
It does not change the Windows job or targetSdk/minSdk.

Commit the file, then rerun GitHub Actions. Verify the log shows the Android
compileSdk settings updated before flutter build apk --release.

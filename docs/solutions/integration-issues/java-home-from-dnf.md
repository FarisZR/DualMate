# Prefer system Java (installed via dnf) for Gradle builds ✅

Problem:
- The project contained a hard-coded `org.gradle.java.home` path (e.g. `/home/farahmani/.jdks/...`) which fails on other machines.

Fix applied:
- Removed the committed `org.gradle.java.home` from `android/gradle.properties`.
- Added a short snippet to `android/settings.gradle` that sets Gradle's Java home from the `JAVA_HOME` environment variable when present and valid. If `JAVA_HOME` is not set, Gradle will fall back to the system Java (the one provided by `dnf` and available on the `PATH`).

How to verify (on your machine):
1. Ensure Java from dnf is installed, for example:
   - sudo dnf install java-17-openjdk-devel
2. Check the Java runtime:
   - java -version
3. Confirm JAVA_HOME (optional):
   - echo $JAVA_HOME  # set this in your shell profile (~/.bashrc / ~/.profile) if needed
   - If not set, Gradle will use the system Java from /usr/lib/jvm or the java on PATH.
4. Run the app:
   - flutter clean
   - flutter pub get
   - flutter run

Notes:
- Avoid committing machine-specific Java paths to `android/gradle.properties`. Use shell environment (JAVA_HOME) or system alternatives instead.

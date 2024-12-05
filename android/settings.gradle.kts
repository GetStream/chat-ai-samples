pluginManagement {
  repositories {
    google {
      content {
        includeGroupByRegex("com\\.android.*")
        includeGroupByRegex("com\\.google.*")
        includeGroupByRegex("androidx.*")
      }
    }
    mavenCentral()
    gradlePluginPortal()
    maven(url = "https://jitpack.io")
    maven(url="https://oss.sonatype.org/content/repositories/snapshots/")
  }
}
dependencyResolutionManagement {
  repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
  repositories {
    google()
    mavenCentral()
    maven(url = "https://jitpack.io")
    maven(url="https://oss.sonatype.org/content/repositories/snapshots/")
  }
}

rootProject.name = "ai-assistant-android"
include(":app")

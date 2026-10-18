// Clear ANDROID_PREFS_ROOT from JVM environment map via reflection to resolve AGP AndroidLocationsException
try {
    val processEnvironment = Class.forName("java.lang.ProcessEnvironment")
    val fields = arrayOf("theEnvironment", "theUnmodifiableEnvironment")
    for (fieldName in fields) {
        try {
            val field = processEnvironment.getDeclaredField(fieldName)
            field.isAccessible = true
            val envMap = field.get(null) as? MutableMap<String, String>
            envMap?.remove("ANDROID_PREFS_ROOT")
        } catch (_: Throwable) {}
    }
} catch (_: Throwable) {}

System.getProperties().remove("ANDROID_PREFS_ROOT")

pluginManagement {
    val flutterSdkPath = run {
        val properties = java.util.Properties()
        file("local.properties").inputStream().use { properties.load(it) }
        val flutterSdkPath = properties.getProperty("flutter.sdk")
        require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
        flutterSdkPath
    }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("org.gradle.toolchains.foojay-resolver-convention") version "0.8.0"
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.2.1" apply false
    id("org.jetbrains.kotlin.android") version "2.1.10" apply false
}

include(":app")

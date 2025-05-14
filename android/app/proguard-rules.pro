# Flutter specific rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Keep your application classes that will be accessed through reflection
-keep class com.example.hockey_stats_app.** { *; }

# Hive rules
-keep class hive.** { *; }
-keep class ** extends hive.** { *; }
-keep class com.hive.** { *; }
-keepclassmembers class * {
    @io.hive.annotations.** <fields>;
}

# Google Sign-In rules
-keep class com.google.android.gms.** { *; }
-keep class com.google.api.** { *; }

# SVG related rules
-keep class com.caverock.androidsvg.** { *; }

# Prevent R8 from stripping interface information
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes SourceFile,LineNumberTable

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep the BuildConfig
-keep class com.example.hockey_stats_app.BuildConfig { *; }

# Keep Play Core classes
-keep class com.google.android.play.core.** { *; }
-keep class com.google.android.play.core.splitcompat.** { *; }
-keep class com.google.android.play.core.splitinstall.** { *; }
-keep class com.google.android.play.core.tasks.** { *; }

# Keep custom exceptions
-keep public class * extends java.lang.Exception

# Preserve the line number information for debugging stack traces
-keepattributes SourceFile,LineNumberTable

# If you keep the line number information, uncomment this to hide the original source file name
#-renamesourcefileattribute SourceFile

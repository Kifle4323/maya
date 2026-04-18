# Flutter wrapper
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Keep Dart entry points
-keep class et.gov.ehia.cbhi.member.** { *; }

# Sentry
-keepattributes *Annotation*
-keepattributes SourceFile,LineNumberTable
-keep public class * extends java.lang.Exception

# SQLite / sqflite
-keep class com.tekartik.sqflite.** { *; }

# image_picker / file_picker
-keep class io.flutter.plugins.imagepicker.** { *; }

# local_auth
-keep class io.flutter.plugins.localauth.** { *; }

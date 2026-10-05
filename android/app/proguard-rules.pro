# Reglas de ProGuard/R8 para el build release.

# Flutter engine
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# El motor de Flutter referencia Play Core para los "deferred components"
# (Android App Bundle con modulos bajo demanda). Esta app es un APK completo y
# no usa esa feature, asi que la dependencia no esta en el classpath. Sin esta
# regla R8 aborta el build con "Missing classes detected".
-dontwarn com.google.android.play.core.**

# barcode_scan2
-keep class com.google.zxing.** { *; }

# Conserva los nombres de los campos usados por sqflite
-keepclassmembers class * { @com.tekartik.sqflite.* <fields>; }

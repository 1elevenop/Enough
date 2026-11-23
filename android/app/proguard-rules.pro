# Flutter plugins ship their own consumer rules; these cover the rest.
-keep class io.github.elevenop.enough.MainActivity { *; }
-keep class androidx.webkit.** { *; }
# flutter_local_notifications (Gson-serialized scheduled notifications)
-keep class com.dexterous.** { *; }
-keepattributes Signature, *Annotation*
# Play Core split-install classes referenced by the Flutter embedding.
-dontwarn com.google.android.play.core.**

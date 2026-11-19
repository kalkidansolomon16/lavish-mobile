# Release builds shrink the code (R8). Keep what the notification plugins load by reflection.
# flutter_local_notifications stores scheduled reminders with Gson:
-keep class com.dexterous.** { *; }
-keepattributes Signature
-keepattributes *Annotation*
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken
# Firebase messaging
-keep class io.flutter.plugins.firebase.** { *; }

# ProGuard Rules for Arena
# This file contains keep rules to prevent crashes when minification is enabled
# Currently minification is disabled, but these rules are prepared for future use

# ============================================
# Flutter Engine Rules
# ============================================
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Keep Flutter embedding
-keep class io.flutter.embedding.** { *; }

# Flutter Play Core (deferred components) - ignore if not used
-dontwarn com.google.android.play.core.splitcompat.**
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**
-dontwarn io.flutter.embedding.android.FlutterPlayStoreSplitApplication
-dontwarn io.flutter.embedding.engine.deferredcomponents.**

# ============================================
# Firebase Rules
# ============================================
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# Firebase Auth
-keep class com.google.firebase.auth.** { *; }
-keep class com.google.android.gms.internal.firebase-auth-api.** { *; }

# Firebase Firestore
-keep class com.google.firebase.firestore.** { *; }
-keep class com.google.cloud.firestore.** { *; }

# Firebase Core
-keep class com.google.firebase.FirebaseApp { *; }
-keep class com.google.firebase.FirebaseOptions { *; }

# Firebase Cloud Functions
-keep class com.google.firebase.functions.** { *; }

# Firebase Messaging
-keep class com.google.firebase.messaging.** { *; }

# ============================================
# Plugin Rules
# ============================================

# Shared Preferences
-keep class android.content.SharedPreferences { *; }
-keep class android.content.SharedPreferences$** { *; }

# URL Launcher
-keep class io.flutter.plugins.urllauncher.** { *; }

# Connectivity Plus
-keep class dev.fluttercommunity.plus.connectivity.** { *; }

# Flutter Local Notifications
-keep class com.dexterous.flutterlocalnotifications.** { *; }

# App Links
-keep class com.llfbandit.app_links.** { *; }

# In-App Purchase
-keep class io.flutter.plugins.inapppurchase.** { *; }
-keep class com.android.billingclient.** { *; }

# Crypto
-keep class dart.crypto.** { *; }

# ============================================
# Kotlin/Java Reflection
# ============================================
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes Exceptions
-keepattributes InnerClasses
-keepattributes EnclosingMethod

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep Parcelable implementations
-keepclassmembers class * implements android.os.Parcelable {
    public static final android.os.Parcelable$Creator CREATOR;
}

# Keep Serializable classes
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}

# ============================================
# Application Classes
# ============================================
-keep class com.xoarena.neonclash.** { *; }

# Keep MainActivity
-keep class com.xoarena.neonclash.MainActivity { *; }

# ============================================
# General Android Rules
# ============================================
-keep public class * extends android.app.Activity
-keep public class * extends android.app.Application
-keep public class * extends android.app.Service
-keep public class * extends android.content.BroadcastReceiver
-keep public class * extends android.content.ContentProvider

# Keep View constructors
-keepclasseswithmembers class * {
    public <init>(android.content.Context, android.util.AttributeSet);
}
-keepclasseswithmembers class * {
    public <init>(android.content.Context, android.util.AttributeSet, int);
}

# ============================================
# Gson (if used by Firebase)
# ============================================
-keepattributes Signature
-keepattributes *Annotation*
-dontwarn sun.misc.**
-keep class com.google.gson.** { *; }
-keep class * implements com.google.gson.TypeAdapter
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer

# ============================================
# OkHttp (if used by Firebase/plugins)
# ============================================
-dontwarn okhttp3.**
-dontwarn okio.**
-keepnames class okhttp3.internal.publicsuffix.PublicSuffixDatabase

# ============================================
# Notes
# ============================================
# - These rules are prepared for when minification is enabled
# - Test thoroughly after enabling minification
# - Add specific rules for any new plugins or libraries
# - If you encounter crashes after enabling minification, check logcat for missing classes

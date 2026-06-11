# FlowCRM Mobile - ProGuard Rules for Code Obfuscation
# This file controls which code is obfuscated in release builds
# Location: android/app/proguard-rules.pro

# Keep all public and protected methods (API level)
-keepclassmembers class * {
    public protected *;
}

# Keep Flutter engine classes (required for Flutter runtime)
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.embedding.** { *; }

# Keep Dart-related reflection
-keepattributes *Annotation*
-keep class java.lang.invoke.MethodHandle { *; }

# Keep FlowCRM app classes (don't obfuscate our own code for easier debugging)
-keep class com.flowcrm.** { *; }
-keep class com.flowcrm.flowcrm_mobile.** { *; }

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep enum classes
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# Keep Parcelable implementations
-keep class * implements android.os.Parcelable {
    public static final android.os.Parcelable$Creator *;
}

# Keep serializable classes
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}

# Keep Fragment classes (Android lifecycle)
-keep public class * extends android.app.Fragment
-keep public class * extends androidx.fragment.app.Fragment

# Keep Activities, Services, BroadcastReceivers
-keep public class * extends android.app.Activity
-keep public class * extends android.app.Service
-keep public class * extends android.content.BroadcastReceiver
-keep public class * extends android.content.ContentProvider

# Keep AsyncTask
-keep public class * extends android.os.AsyncTask { *; }

# Keep R classes
-keepclassmembers class **.R$* {
    public static <fields>;
}

# Keep exception classes
-keep class * extends java.lang.Exception { *; }
-keep class * extends java.lang.RuntimeException { *; }

# Keep Android Architecture Components
-keep class androidx.** { *; }
-keep interface androidx.** { *; }

# Keep Dio (HTTP client library)
-keep class io.flutter.plugins.** { *; }
-keep class com.google.gson.** { *; }
-keep interface com.google.gson.** { *; }

# Keep Firebase classes
-keep class com.google.firebase.** { *; }
-keep interface com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }

# Keep flutter_secure_storage
-keep class com.example.flutter_secure_storage.** { *; }

# Keep ViewModels (Riverpod)
-keep class * extends androidx.lifecycle.ViewModel { *; }

# Suppress warnings for third-party libraries
-dontwarn com.google.**
-dontwarn com.android.**
-dontwarn androidx.**
-dontwarn org.conscrypt.**

# Optimization flags
-optimizationpasses 5
-dontusemixedcaseclassnames
-verbose

# Remove logging in release build
-assumenosideeffects class android.util.Log {
    public static *** d(...);
    public static *** v(...);
    public static *** i(...);
}

# Resource shrinking configuration
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile

# Optimization settings
-optimizations !code/simplification/arithmetic,!code/simplification/cast,!field/*,!class/merging/*

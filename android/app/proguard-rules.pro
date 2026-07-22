# --- Room / WorkManager --------------------------------------------------
# See the comment in build.gradle.kts: androidx.room.Room is looked up via
# Class.forName reflection by WorkManager/Room at runtime. R8 full mode
# removes it unless it's explicitly kept. These rules make that safe even
# if a future dependency bump reintroduces an old Room/WorkManager version.
-keep class androidx.room.Room { *; }
-keep class androidx.room.RoomDatabase { *; }
-keep class * extends androidx.room.RoomDatabase { *; }
-keep class **_Impl { *; }
-keep class **_Impl$* { *; }
-dontwarn androidx.room.**

-keep class * extends androidx.work.Worker
-keep class * extends androidx.work.InputMerger
-keep public class * extends androidx.work.ListenableWorker {
    public <init>(android.content.Context, androidx.work.WorkerParameters);
}
-keep class androidx.work.impl.** { *; }
-dontwarn androidx.work.**

# --- Google Mobile Ads / Play Services Ads --------------------------------
-keep class com.google.android.gms.ads.** { *; }
-keep class com.google.android.gms.internal.ads.** { *; }
-dontwarn com.google.android.gms.ads.**

# --- Google Sign-In / Play Services Auth ----------------------------------
-keep class com.google.android.gms.auth.** { *; }
-keep class com.google.android.gms.common.** { *; }
-dontwarn com.google.android.gms.**

# --- flutter_secure_storage (AndroidKeyStore / Tink) ----------------------
-keep class androidx.security.crypto.** { *; }
-dontwarn androidx.security.crypto.**

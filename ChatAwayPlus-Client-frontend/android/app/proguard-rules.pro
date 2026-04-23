# Keep OkHttp classes for image_cropper
-keep class okhttp3.** { *; }
-dontwarn okhttp3.**
-dontwarn okio.**

# Keep UCrop classes
-keep class com.yalantis.ucrop.** { *; }
-dontwarn com.yalantis.ucrop.**

# Keep Agora SDK classes (voice/video calling)
-keep class io.agora.** { *; }
-dontwarn io.agora.**

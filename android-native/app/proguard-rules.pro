# kotlinx.serialization
-keepattributes *Annotation*, InnerClasses
-dontnote kotlinx.serialization.AnnotationsKt
-keepclassmembers class kotlinx.serialization.json.** { *** Companion; }
-keepclasseswithmembers class kotlinx.serialization.json.** { kotlinx.serialization.KSerializer serializer(...); }
-keep,includedescriptorclasses class ru.kiper.android.**$$serializer { *; }
-keepclassmembers class ru.kiper.android.** { *** Companion; }
-keepclasseswithmembers class ru.kiper.android.** { kotlinx.serialization.KSerializer serializer(...); }

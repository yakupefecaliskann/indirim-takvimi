# flutter_local_notifications zamanlanmis bildirimleri Gson ile saklar;
# model siniflari kucultulmemeli yoksa yeniden baslatma sonrasi bildirimler
# geri yuklenemez.
-keep class com.dexterous.** { *; }
-keep class * extends com.google.gson.TypeAdapter
-dontwarn com.dexterous.**

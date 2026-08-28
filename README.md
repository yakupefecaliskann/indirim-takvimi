# İndirim Takvimi

Türkiye'deki kişisel bakım ve giyim markalarının indirim günlerini tek ekranda
gösteren, gün yaklaştıkça bildirim düşüren Android uygulaması.

Takip edilen markalar: **Gratis, Watsons, Sephora, Rossmann** (kişisel bakım) ve
**Zara, Bershka, Pull&Bear, Stradivarius, Oysho** (Inditex grubu), ayrıca
markadan bağımsız büyük indirim günleri.

---

## Temel fikir: iki katmanlı veri

| Katman | Nerede | Bozulursa ne olur |
|---|---|---|
| **1. Hesaplanan takvim** | Uygulamanın içinde, Dart kodu | Bozulamaz. İnternet olmasa da geri sayım ve bildirimler çalışır. |
| **2. Canlı veri** | GitHub Actions, 6 saatte bir | Uygulama 1. katmana düşer, çalışmaya devam eder. |

Bu ayrım bilinçli. Scraper'lar er ya da geç bozulur; bozulduğunda uygulamanın
ölmemesi gerekiyordu. Hesaplanan takvim hiçbir dış kaynağa bağlı değil.

**Hesaplanan takvim kuralları** (2026 verisiyle doğrulandı):

| Olay | Kural | 2026 |
|---|---|---|
| Inditex yaz indirimi | Haziran'ın son çarşambası | 24 Haziran ✅ |
| Inditex kış indirimi | Ocak'ın ilk çarşambası | 7 Ocak ✅ |
| Black Friday | Kasım'ın 4. cuması | 27 Kasım ✅ |
| Anneler Günü | Mayıs'ın 2. pazarı | 10 Mayıs |
| 11.11 / Sevgililer / Kadınlar Günü / Yılbaşı | Sabit tarih | — |

Tahmini tarihler arayüzde **Tahmini** rozetiyle işaretlenir; kesinleşmiş tarihten
görsel olarak ayrılır. Bildirim metni de bunu belirtir ("30 gün kaldı (tahmini
tarih)").

---

## Durum

Depo: https://github.com/yakupefecaliskann/indirim-takvimi — kurulu ve çalışıyor.
Boru hattı 6 saatte bir kendi kendine veri topluyor, uygulama Android 13'te
(Infinix X6528B) test edildi: 64 hatırlatma kuruldu, bildirimler çalışıyor.

## Kurulum (tek seferlik — yapıldı)

### 1. Kişisel bilgileri doldur

`app/lib/config.dart`:

```dart
const String kHerName = 'Aşkım';              // ← ismini yaz
const String kWelcomeMessage = '...';          // ← karşılama mesajını yaz
const String kGithubUser = 'GITHUB_KULLANICI_ADI'; // ← GitHub kullanıcı adın
```

`kGithubUser` yanlış kalırsa uygulama çalışır ama canlı fırsatları çekemez;
hesaplanan takvimle devam eder.

### 2. GitHub deposunu kur

```bash
git init
git add .
git commit -m "ilk surum"
git branch -M main
git remote add origin https://github.com/<kullanici>/indirim-takvimi.git
git push -u origin main
```

Depo **public** olmalı — uygulama veriyi `raw.githubusercontent.com` üzerinden
okuyor. İçinde kişisel hiçbir veri yok (imza anahtarları `.gitignore`'da).

Depoda **Settings → Actions → General → Workflow permissions** ayarını
*Read and write permissions* yap; bot veriyi commit'leyebilsin.

### 3. APK'yı üret ve gönder

```bash
cd app
flutter build apk --release --split-per-abi
```

`build/app/outputs/flutter-apk/app-arm64-v8a-release.apk` dosyasını gönder
(neredeyse tüm modern Android telefonlar arm64). Telefonda "bilinmeyen
kaynaklardan yükleme" izni verilmesi gerekir.

---

## Boru hattı

```
GitHub Actions (6 saatte bir)
  └─ collector/  ── kaynaklar paralel denenir ── data/campaigns.json commit
                                                      │
                              raw.githubusercontent.com üzerinden servis
                                                      │
                          Flutter uygulaması günde 1 çeker, diske cache'ler
                                                      │
                     hesaplanan takvimle birleşir → geri sayım + bildirim
```

### Kaynaklar

| Kaynak | Ne veriyor | Durum |
|---|---|---|
| `sources/picodi.js` | Canlı kampanya/fırsatlar (9 marka) | ✅ Çalışıyor — ~66 fırsat |
| `sources/news.js` | Haberlerden kesinleşmiş tarih | ⚠️ Bonus katman, çoğu zaman boş döner |

**`news.js` neden çoğu zaman boş döner:** Google News RSS açıklamaları makale
gövdesini içermiyor, yalnızca başlığı tekrarlıyor; indirim tarihi ise gövdede
geçiyor. Makale bağlantıları da `news.google.com` yönlendirmesi olduğu için
doğrudan çekilemiyor. 266 haber üzerinde ölçüldü: yalnızca 11'inde tarih vardı,
3'ü "başlangıç" bağlamındaydı ve üçü de eski haberlere ait yanlış pozitifti —
filtreler üçünü de eledi. Bu katman ucuz ve güvenli (yanlış tarih üretmiyor),
ama uygulamanın doğru çalışması ona bağlı değil.

**İndirim kodu dizeleri neden yok:** Kupon siteleri kod dizesini tıklama arkasında
tutuyor (gelir modelleri bu) ve o adresler `robots.txt`'de yasaklı. Kodlar
uydurulmuyor; kod gerektiren fırsatlar "Kod gerekli" rozetiyle ve kaynak
bağlantısıyla gösteriliyor. Türkiye'deki perakende kampanyalarının çoğu zaten
kod istemiyor, indirim kasada otomatik uygulanıyor.

### Sürpriz bir tuzak: kaynak küçültücü

Release derlemesinde `isShrinkResources = true` açık. Bildirim simgesine yalnızca
Dart tarafından bir **metinle** (`'@drawable/ic_notification'`) atıf yapıldığı için
küçültücü onu göremeyip APK'dan atıyordu; uygulama açılışta `invalid_icon`
istisnası fırlatıp **hiçbir bildirim kuramıyordu** — hem de sessizce, yalnızca
release derlemesinde. `app/android/app/src/main/res/raw/keep.xml` bunu önlüyor.
Bildirim simgesini değiştirirsen o dosyayı da güncelle.

### Güvenlik ağları

1. Her kaynak izole; biri patlarsa diğerleri devam eder.
2. Yeni çıktı bir öncekinin yarısından azsa **yazılmaz** — son iyi veri kalır.
3. 30 gündür görülmeyen fırsat uygulamada otomatik gizlenir.
4. Bozuk JSON kaydı istisna fırlatmaz, sessizce atlanır.
5. Emin olunmayan tarih hiç üretilmez; uygulama tahmine düşer.

---

## Geliştirme

```bash
# Uygulama
cd app
flutter test                    # 57 test
flutter analyze
flutter run

# Toplayıcı
cd collector
npm install
npm test                        # 37 test
npm run dry                     # kuru çalışma, dosya yazmaz
node src/main.js --only=picodi  # tek kaynak
npm start                       # topla ve data/campaigns.json yaz
```

### Bildirimler

- Kademeler: **30 / 14 / 7 / 3 / 1 gün kala + başladığı gün**, saat 10:00.
- `inexactAllowWhileIdle` kullanılıyor: gün bazlı hatırlatmada saniye
  hassasiyeti gerekmediği için Android 12+'ta `SCHEDULE_EXACT_ALARM` izin ekranı
  hiç çıkmıyor.
- Yerel bildirim oldukları için uygulama hiç açılmasa da düşerler.
- Ayarlar ekranındaki "Deneme bildirimi gönder" ile anında doğrulanabilir.

---

## Uygulama simgesi

`python tools/make_icons.py` simgeyi yeniden üretir (gül kurusu gradyan üzerinde
kalpli alışveriş çantası) ve tüm mipmap yoğunluklarına yazar. Pillow gerekir.
Bildirim simgesi ayrı: `res/drawable/ic_notification.xml`, tek renk siluet.

## İmza anahtarı ⚠️

`app/android/indirim-takvimi.jks` ve `app/android/key.properties` **depoya
girmiyor** (`.gitignore`). Bu anahtar kaybolursa uygulamanın üzerine güncelleme
kurulamaz — yalnızca kaldırıp yeniden kurmak gerekir. Ayrı bir yere yedekle.

---

## Bilerek kapsam dışı

iOS derlemesi (Mac gerekir) · push bildirim / FCM (yerel bildirim yeterli,
sunucu maliyeti yok) · kullanıcılar arası ortak oylama (tek kullanıcılı
uygulama) · fiyat takibi ve sepet entegrasyonu.

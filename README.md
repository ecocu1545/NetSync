# NetSync - Ebeveyn Denetim ve Aile Güvenliği Uygulaması

NetSync; Flutter ve Native Android Kotlin köprüleri (Platform Channels / MethodChannel) kullanılarak geliştirilmiş, tam şeffaf ve izin tabanlı bir Ebeveyn Denetim ve Güvenlik uygulamasıdır.

---

## 📱 Özellikler

### 1. Çocuk Cihazı Modu
* **Standart İzin Akışı:** Kamera, Mikrofon, GPS Konumu (Background Location), Medya ve Pil Optimizasyonu muafiyeti talebi.
* **Native Foreground Service (`ChildMonitorService.kt`):** Uygulama kapatılsa dahi işletim sisteminde "NetSync Aile Koruması Aktif" bildirimi ile kesintisiz çalışma.
* **Otomatik Başlama (`BootReceiver.kt`):** Cihaz yeniden başlatıldığında (`BOOT_COMPLETED`) servisi otomatik ayağa kaldırma.
* **Şeffaf Gizlilik:** Sistem gizlilik göstergeleri (yeşil kamera/mikrofon noktaları) standart şekilde çalışır.
* **Canlı Medya Yayını:** Ebeveynden gelen çağrılarda kamera veya ekran görüntüsünü WebRTC üzerinden P2P iletme.
* **GPS Telemetrisi:** Konum, hız ve hassasiyet verilerini anlık sunucuya aktarma.

### 2. Ebeveyn Cihazı Kontrol Paneli
* **Canlı Kamera & Ortam Sesi:** Çocuğun kamerasını ve mikrofonunu anlık olarak izleme/dinleme, ses kapatma/açma.
* **Canlı Ekran Yayını:** Çocuğun telefon ekranını WebRTC MediaProjection üzerinden gerçek zamanlı izleme.
* **GPS Konum Telemetrisi:** Enlem, boylam, hız, doğruluk ve son güncelleme zamanını gösteren canlı takip kartı.
* **Galeri Denetimi:** Çocuk cihazındaki medya dosyalarını uzaktan listeleme ve inceleme.

---

## 🚀 Proje Dizin Yapısı

```text
NetSync/
├── .github/workflows/
│   └── build_apk.yml                 # Bulutta otomatik APK derleyen GitHub Actions iş akışı
├── android/
│   ├── app/
│   │   ├── src/main/
│   │   │   ├── AndroidManifest.xml   # Tüm izinler, servisler ve Flutter v2 embedding
│   │   │   ├── kotlin/com/example/netsync/
│   │   │   │   ├── MainActivity.kt   # Native MethodChannel köprüsü (Pil optimizasyonu, servis durumu)
│   │   │   │   ├── services/
│   │   │   │   │   └── ChildMonitorService.kt # Android 14+ uyumlu Foreground Service & WakeLock
│   │   │   │   └── receivers/
│   │   │   │       └── BootReceiver.kt        # Cihaz açılışında otomatik tetikleyici
│   │   │   └── res/
│   │   │       ├── values/styles.xml
│   │   │       ├── drawable/launch_background.xml
│   │   │       └── mipmap-*/ic_launcher.png   # NetSync uygulama simgesi (Tüm çözünürlüklerde hazır)
│   │   └── build.gradle
│   ├── build.gradle
│   ├── settings.gradle
│   └── gradle.properties
├── assets/icon/
│   └── app_icon.png                  # Yüksek çözünürlüklü kalkan ve senkronizasyon simgesi
├── lib/
│   ├── main.dart                     # Uygulama başlangıcı ve tema
│   ├── core/
│   │   ├── method_channels.dart      # Flutter -> Kotlin Native köprü çağrıları
│   │   ├── signaling_manager.dart    # Socket.IO sinyalleşme, oda ve mesajlaşma yöneticisi
│   │   └── webrtc_manager.dart       # P2P WebRTC ses, video ve ekran yayın motoru
│   └── screens/
│       ├── mode_selection_screen.dart # Çocuk / Ebeveyn Mod Seçimi
│       ├── child/
│       │   └── child_setup_screen.dart # İzinler, servis aktivasyonu, WebRTC ve GPS yayınlayıcı
│       └── parent/
│           ├── parent_dashboard.dart  # Eşleştirme ve 4 ana modül kontrol paneli
│           ├── live_camera_screen.dart # Canlı kamera izleme ve ses kontrolleri
│           ├── screen_share_screen.dart # Canlı ekran izleme
│           ├── location_map_screen.dart # GPS telemetrisi ve koordinat takibi
│           └── gallery_screen.dart     # Uzaktan galeri denetimi
├── server/
│   ├── package.json
│   └── server.js                     # Node.js + Socket.IO sinyalleşme sunucusu
├── pubspec.yaml                      # Flutter bağımlılıkları (webrtc, socket.io, geolocator)
└── derle_ve_calistir.bat              # Tek tıkla yerel APK derleme aracı
```

---

## ⚡ Sinyalleşme Sunucusunu Başlatma

Cihazların birbiriyle eşleşebilmesi için sinyalleşme sunucusunu başlatın:

```bash
cd server
npm install
node server.js
```
*Sunucu varsayılan olarak `3000` portunda çalışır.*

---

## 📦 APK Derleme Seçenekleri

### 1. Bulutta Otomatik Derleme (En Kolay ve Sıfır Kurulum)
Proje klasörünü bir GitHub deposuna yüklediğinizde, `.github/workflows/build_apk.yml` dosyası sayesinde GitHub'ın bulut sunucuları otomatik devreye girer:
1. Projeyi GitHub'a `git push` yapın.
2. Deponuzdaki **Actions** sekmesine gidin.
3. 2-3 dakika içinde tamamlanan işlemden sonra **`netsync-release-apk`** dosyasını doğrudan indirin!

### 2. Kendi Bilgisayarınızda Yerel Derleme
Bilgisayarınızda Flutter SDK kurulu olduğunda:
1. Klasördeki `derle_ve_calistir.bat` dosyasını çift tıklayın veya terminalde şu komutu girin:
```bash
flutter pub get
flutter build apk --release
```
2. Çıktı APK dosyası: `build/app/outputs/flutter-apk/app-release.apk` dizininde oluşacaktır.

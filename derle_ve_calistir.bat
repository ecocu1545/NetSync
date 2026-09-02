@echo off
chcp 65001 > nul
echo ======================================================================
echo             NetSync - Ebeveyn Denetim ve Aile Güvenliği
echo                     APK Derleme ve Kontrol Aracı
echo ======================================================================
echo.

where flutter >nul 2>nul
if %errorlevel% neq 0 (
    echo [!] UYARI: Sisteminizde 'flutter' komutu bulunamadı!
    echo.
    echo APK derleyebilmek için lütfen aşağıdaki adımlardan birini yapın:
    echo 1. Seçenek (Yerel Kurulum):
    echo    - Flutter SDK'yı indirin: https://docs.flutter.dev/get-started/install/windows
    echo    - Klasörü C:\src\flutter veya C:\flutter dizinine açın.
    echo    - C:\src\flutter\bin yolunu Windows 'Ortam Değişkenleri -> PATH' içine ekleyin.
    echo.
    echo 2. Seçenek (Otomatik Bulut Derleme - Tavsiye Edilen):
    echo    - Projeyi GitHub'a yüklediğinizde (.github/workflows/build_apk.yml hazır),
    echo      GitHub Actions herhangi bir kurulum gerektirmeden 2 dakika içinde APK'nızı
    echo      otomatik derleyip 'Artifacts' bölümünde indirmeye hazır hale getirir!
    echo.
    pause
    exit /b 1
)

echo [+] Flutter tespit edildi!
echo [*] Bağımlılıklar indiriliyor (flutter pub get)...
call flutter pub get

echo [*] Uygulama simgeleri oluşturuluyor...
call dart run flutter_launcher_icons

echo [*] Release APK derleniyor (flutter build apk --release)...
call flutter build apk --release

if %errorlevel% equ 0 (
    echo.
    echo ======================================================================
    echo [✓] TEBRİKLER! APK Başarıyla Derlendi:
    echo     build\app\outputs\flutter-apk\app-release.apk
    echo ======================================================================
    explorer build\app\outputs\flutter-apk
) else (
    echo.
    echo [X] Derleme sırasında bir hata oluştu. Lütfen konsol çıktısını kontrol edin.
)

pause

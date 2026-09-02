@echo off
chcp 65001 > nul
echo ======================================================================
echo             NetSync - GitHub'a Yükleme ve Bulut APK Tetikleyici
echo ======================================================================
echo.
echo Depo Adresi: https://github.com/ecocu1545/NetSync.git
echo.
echo Kodlar GitHub'a gönderiliyor... Lütfen açılan tarayıcı veya pencereden
echo GitHub hesabınıza onay verin.
echo.

C:\Users\LOQ\mingit\cmd\git.exe push -u origin main

if %errorlevel% equ 0 (
    echo.
    echo ======================================================================
    echo [✓] BAŞARILI! Tüm proje GitHub'a yüklendi.
    echo.
    echo Şimdi GitHub'daki Actions sekmesine giderek APK'nızın otomatik
    echo derlenmesini izleyebilir ve doğrudan indirebilirsiniz:
    echo.
    echo 👉 https://github.com/ecocu1545/NetSync/actions
    echo ======================================================================
    start https://github.com/ecocu1545/NetSync/actions
) else (
    echo.
    echo [!] Gönderme tamamlanamadı. Lütfen GitHub giriş bilgilerinizi kontrol edin.
)

pause

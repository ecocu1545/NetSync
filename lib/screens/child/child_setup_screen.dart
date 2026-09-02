import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/method_channels.dart';
import '../../core/signaling_manager.dart';
import '../../core/webrtc_manager.dart';

class ChildSetupScreen extends StatefulWidget {
  @override
  _ChildSetupScreenState createState() => _ChildSetupScreenState();
}

class _ChildSetupScreenState extends State<ChildSetupScreen> with WidgetsBindingObserver {
  bool _isServiceActive = false;
  bool _isSocketConnected = false;
  late String _deviceId;
  
  // Varsayılan kalıcı 7/24 bulut sinyalleşme sunucusu
  final TextEditingController _serverUrlController = TextEditingController(text: "https://netsync-k68k.onrender.com");
  final TextEditingController _deviceIdController = TextEditingController();

  WebRTCManager? _childWebRTC;
  Timer? _locationTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _generateDeviceId();
    _checkInitialServiceStatus();
    _setupSignaling(); // Ekran açılır açılmaz sinyalleşmeye bağlan
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      // Uygulama simge durumuna küçültüldüğünde veya ekran kapandığında
      SignalingManager().onAppPaused();
    } else if (state == AppLifecycleState.resumed) {
      // Uygulama tekrar ön plana geldiğinde
      SignalingManager().onAppResumed();
      if (mounted) {
        setState(() {
          _isSocketConnected = SignalingManager().isConnected;
        });
      }
    }
  }

  void _generateDeviceId() {
    final random = Random();
    final id = "NET-${1000 + random.nextInt(9000)}";
    _deviceId = id;
    _deviceIdController.text = id;
  }

  Future<void> _checkInitialServiceStatus() async {
    final running = await NativeBridge.isServiceRunning();
    if (mounted) {
      setState(() {
        _isServiceActive = running;
      });
      if (running) {
        _startLocationTracking();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Koruma servisi aktifse arka planda devam etmeli, kaynakları kapatma
    if (!_isServiceActive) {
      _locationTimer?.cancel();
      _childWebRTC?.dispose();
    }
    _serverUrlController.dispose();
    _deviceIdController.dispose();
    super.dispose();
  }

  String _getQrPayload() {
    final payload = {
      'app': 'NetSync',
      'deviceId': _deviceIdController.text.trim(),
      'server': _serverUrlController.text.trim(),
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    return jsonEncode(payload);
  }

  Future<void> _requestPermissionsAndStart() async {
    // 1. Bildirim İzni (Android 13+ Foreground bildirimleri için zorunlu)
    try {
      await Permission.notification.request();
    } catch (_) {}

    // 2. Kamera ve Mikrofon İzinleri
    try {
      await Permission.camera.request();
      await Permission.microphone.request();
    } catch (_) {}

    // 3. Konum İzni (Android kuralı: önce normal, sonra arka plan)
    try {
      final locStatus = await Permission.location.request();
      if (locStatus.isGranted) {
        await Permission.locationAlways.request();
      }
    } catch (_) {}

    // 4. Fotoğraf ve Medya İzni
    try {
      await Permission.photos.request();
    } catch (_) {}

    // 5. Pil Optimizasyonu Muafiyeti (Kesintisiz arka plan)
    try {
      await NativeBridge.requestBatteryOptimization();
    } catch (_) {}

    // 6. Native Foreground Servisi Güvenle Başlat
    try {
      await NativeBridge.startService();
    } catch (_) {}

    // 7. Sinyalleşme ve GPS Konum Takibini Başlat
    _setupSignaling();
    _startLocationTracking();

    if (mounted) {
      setState(() {
        _isServiceActive = true;
      });
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('NetSync Çocuk Koruma Servisi Devrede!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _setupSignaling() {
    final signaling = SignalingManager();
    _childWebRTC ??= WebRTCManager();
    signaling.webRTCManager = _childWebRTC;

    signaling.onConnectionChange = (connected) {
      if (mounted) {
        setState(() {
          _isSocketConnected = connected;
        });
      }
    };

    // Ebeveynden gelen yayın isteklerini dinle (Kamera veya Ekran)
    signaling.onRequestStream = (requesterId, type) async {
      print('Ebeveynden gelen yayın isteği: $type');
      await _childWebRTC?.initConnection(requesterId);

      if (type == 'screen') {
        await _childWebRTC?.startScreenShareStream();
      } else {
        await _childWebRTC?.startLocalCameraStream(frontCamera: false);
      }

      final offer = await _childWebRTC?.createOffer();
      if (offer != null) {
        signaling.sendOffer(requesterId, offer.toMap());
      }
    };

    signaling.connect(
      serverUrl: _serverUrlController.text.trim(),
      deviceId: _deviceIdController.text.trim(),
      role: 'child',
    );
  }

  void _startLocationTracking() {
    _locationTimer?.cancel();
    _locationTimer = Timer.periodic(const Duration(seconds: 15), (_) async {
      final loc = await NativeBridge.getCurrentLocation();
      if (loc != null) {
        SignalingManager().sendLocation('PARENT-ADMIN', {
          'childId': _deviceIdController.text.trim(),
          'latitude': loc['latitude'],
          'longitude': loc['longitude'],
          'accuracy': loc['accuracy'],
          'speed': loc['speed'],
          'timestamp': DateTime.now().toIso8601String(),
        });
      }
    });
  }

  Future<void> _stopProtection() async {
    await NativeBridge.stopService();
    _locationTimer?.cancel();
    _childWebRTC?.stopTracks();

    if (mounted) {
      setState(() {
        _isServiceActive = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final qrData = _getQrPayload();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Çocuk Cihazı Kurulumu & QR'),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Ebeveyn İçin QR Kod Kartı
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    const Text(
                      'Ebeveyn Cihazından Bu QR Kodu Tarayın',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Ebeveyn cihazı bu QR kodu okuttuğu anda cihazlar otomatik eşleşir.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),

                    // QR Kod Görseli
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.blue[100]!, width: 2),
                      ),
                      child: QrImageView(
                        data: qrData,
                        version: QrVersions.auto,
                        size: 200.0,
                        backgroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Cihaz Kodu ve Kopyalama
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Cihaz Kodu: ${_deviceIdController.text}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[900],
                            letterSpacing: 1.2,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy, size: 20),
                          tooltip: 'Kodu Kopyala',
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: _deviceIdController.text));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Cihaz kodu kopyalandı!')),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Durum Göstergesi
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: _isSocketConnected ? Colors.green[50] : Colors.red[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _isSocketConnected ? Colors.green[300]! : Colors.red[300]!),
              ),
              child: Row(
                children: [
                  Icon(
                    _isSocketConnected ? Icons.cloud_done : Icons.cloud_off,
                    color: _isSocketConnected ? Colors.green[700] : Colors.red[700],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isSocketConnected ? 'Sinyalleşme Sunucusu: ÇEVRİMİÇİ' : 'Sinyalleşme Sunucusu: BAĞLANTI YOK',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: _isSocketConnected ? Colors.green[900] : Colors.red[900],
                          ),
                        ),
                        Text(
                          _isServiceActive ? 'Arka Plan Koruma: Aktif' : 'Arka Plan Koruma: Başlatılmadı',
                          style: const TextStyle(fontSize: 11, color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isSocketConnected ? Colors.green : Colors.red,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Sunucu Ayarları
            ExpansionTile(
              initiallyExpanded: false,
              title: const Text('Sunucu & Bağlantı Ayarları', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Column(
                    children: [
                      TextField(
                        controller: _serverUrlController,
                        decoration: const InputDecoration(
                          labelText: 'Sinyalleşme Sunucusu URL',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        onSubmitted: (_) => _setupSignaling(),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal[50], foregroundColor: Colors.teal[900]),
                              onPressed: () {
                                setState(() {
                                  _serverUrlController.text = "https://netsync-k68k.onrender.com";
                                });
                                _setupSignaling();
                              },
                              child: const Text('🌐 7/24 Bulut Sunucu', style: TextStyle(fontSize: 11)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[50], foregroundColor: Colors.blue[900]),
                              onPressed: () {
                                setState(() {
                                  _serverUrlController.text = "http://192.168.1.110:3000";
                                });
                                _setupSignaling();
                              },
                              child: const Text('🏠 Yerel Wi-Fi IP', style: TextStyle(fontSize: 11)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Başlatma / Durdurma Butonu
            if (!_isServiceActive)
              ElevatedButton.icon(
                icon: const Icon(Icons.shield, color: Colors.white),
                label: const Text('İzinleri Ver ve Korumayı Başlat', style: TextStyle(fontSize: 16, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[800],
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _requestPermissionsAndStart,
              )
            else
              OutlinedButton.icon(
                icon: const Icon(Icons.stop_circle, color: Colors.red),
                label: const Text('Korumayı Durdur', style: TextStyle(color: Colors.red, fontSize: 16)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: Colors.red),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _stopProtection,
              ),
          ],
        ),
      ),
    );
  }
}

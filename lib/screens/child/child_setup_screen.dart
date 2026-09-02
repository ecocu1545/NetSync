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

class _ChildSetupScreenState extends State<ChildSetupScreen> {
  bool _isServiceActive = false;
  bool _isSocketConnected = false;
  late String _deviceId;
  
  // Varsayılan genel sinyalleşme sunucusu (farklı ağlarda çalışabilmesi için)
  final TextEditingController _serverUrlController = TextEditingController(text: "https://netsync-relay.glitch.me");
  final TextEditingController _deviceIdController = TextEditingController();

  WebRTCManager? _childWebRTC;
  Timer? _locationTimer;

  @override
  void initState() {
    super.initState();
    _generateDeviceId();
    _checkInitialServiceStatus();
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
        _setupSignaling();
        _startLocationTracking();
      }
    }
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    _childWebRTC?.dispose();
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
    // 1. İzinleri talep et
    await [
      Permission.camera,
      Permission.microphone,
      Permission.location,
      Permission.locationAlways,
      Permission.photos,
      Permission.storage,
      Permission.notification,
    ].request();

    // Pil optimizasyonu muafiyeti iste
    await NativeBridge.requestBatteryOptimization();

    // 2. Native Foreground Servisi Başlat
    await NativeBridge.startService();

    // 3. Socket.IO ve WebRTC Sinyalleşmesini Başlat
    _setupSignaling();

    // 4. GPS Konum Takibini Başlat
    _startLocationTracking();

    if (mounted) {
      setState(() {
        _isServiceActive = true;
      });
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('NetSync Çocuk Koruma Servisi Başarıyla Başlatıldı'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _setupSignaling() {
    final signaling = SignalingManager();
    _childWebRTC = WebRTCManager();
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
      print('Ebeveynden gelen yayın isteği işleniyor: $type');
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
        SignalingManager().sendLocation('parentDeviceId', {
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
    SignalingManager().disconnect();

    if (mounted) {
      setState(() {
        _isServiceActive = false;
        _isSocketConnected = false;
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
                      'Farklı internet ağlarında (4G/Wi-Fi) olsanız bile otomatik eşleşir.',
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
                color: _isServiceActive ? Colors.green[50] : Colors.amber[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _isServiceActive ? Colors.green[300]! : Colors.amber[300]!),
              ),
              child: Row(
                children: [
                  Icon(
                    _isServiceActive ? Icons.verified_user : Icons.shield_outlined,
                    color: _isServiceActive ? Colors.green[700] : Colors.amber[800],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isServiceActive ? 'Koruma ve Yayın Servisi Aktif' : 'Koruma Başlatılmadı',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: _isServiceActive ? Colors.green[900] : Colors.amber[900],
                          ),
                        ),
                        Text(
                          _isSocketConnected ? 'Sinyalleşme Sunucusu: Bağlı' : 'Sinyalleşme Sunucusu: Bekleniyor',
                          style: const TextStyle(fontSize: 11, color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isSocketConnected ? Colors.green : Colors.red,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Sunucu Ayarları (Genişletilebilir)
            ExpansionTile(
              title: const Text('Gelişmiş Ağ & Sunucu Ayarları', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Column(
                    children: [
                      TextField(
                        controller: _serverUrlController,
                        decoration: const InputDecoration(
                          labelText: 'Sinyalleşme Sunucusu URL',
                          hintText: 'https://netsync-relay.glitch.me veya http://192.168.1.X:3000',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                setState(() {
                                  _serverUrlController.text = "https://netsync-relay.glitch.me";
                                });
                              },
                              child: const Text('🌐 İnternet Sunucusu', style: TextStyle(fontSize: 11)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                setState(() {
                                  _serverUrlController.text = "http://192.168.1.110:3000";
                                });
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

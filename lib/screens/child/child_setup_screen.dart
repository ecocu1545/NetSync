import 'dart:async';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
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
  String _deviceId = "NET-8821";
  final TextEditingController _serverUrlController = TextEditingController(text: "http://10.0.2.2:3000");
  final TextEditingController _deviceIdController = TextEditingController(text: "NET-8821");

  WebRTCManager? _childWebRTC;
  Timer? _locationTimer;

  @override
  void initState() {
    super.initState();
    _checkInitialServiceStatus();
  }

  Future<void> _checkInitialServiceStatus() async {
    final running = await NativeBridge.isServiceRunning();
    if (mounted) {
      setState(() {
        _isServiceActive = running;
      });
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

  Future<void> _requestPermissionsAndStart() async {
    // 1. İzinleri sırayla talep et
    Map<Permission, PermissionStatus> statuses = await [
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
    final serviceStarted = await NativeBridge.startService();

    // 3. Socket.IO ve WebRTC Sinyalleşmesini Başlat
    _setupSignaling();

    // 4. GPS Konum Takibini Başlat (Native Android LocationManager üzerinden)
    _startLocationTracking();

    if (mounted) {
      setState(() {
        _isServiceActive = true;
      });
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('NetSync Çocuk Koruma Servisi Başarıyla Devreye Girdi'),
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Çocuk Cihazı Kurulumu'),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Durum Kartı
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              color: _isServiceActive ? Colors.green[50] : Colors.amber[50],
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    Icon(
                      _isServiceActive ? Icons.verified_user : Icons.gpp_maybe,
                      size: 70,
                      color: _isServiceActive ? Colors.green[700] : Colors.amber[800],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _isServiceActive ? 'CİHAZ KORUMA ALTINDA' : 'KORUMA BAŞLATILMADI',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _isServiceActive ? Colors.green[900] : Colors.amber[900],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _isServiceActive
                          ? 'Arka plan koruma servisi aktif. Sistem yeşil gizlilik göstergeleri standart çalışır.'
                          : 'Ebeveyn denetimini aktif etmek için aşağıdaki izinleri verin ve servisi başlatın.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 13, color: Colors.black87),
                    ),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _isSocketConnected ? Colors.green : Colors.red,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isSocketConnected ? 'Sunucu Bağlantısı Aktif' : 'Sunucuya Bağlı Değil',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _isSocketConnected ? Colors.green[800] : Colors.red[800],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Cihaz Eşleştirme ve Sunucu Ayarları
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Cihaz Eşleştirme Bilgileri',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _deviceIdController,
                      decoration: const InputDecoration(
                        labelText: 'Bu Cihazın Kimlik Kodu (Device ID)',
                        prefixIcon: Icon(Icons.qr_code),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _serverUrlController,
                      decoration: const InputDecoration(
                        labelText: 'Sinyalleşme Sunucusu (IP / URL)',
                        hintText: 'http://192.168.1.50:3000',
                        prefixIcon: Icon(Icons.cloud_queue),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // İzinler Listesi Bilgilendirmesi
            const Text(
              'Gerekli Standart Android İzinleri:',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _buildPermissionTile(Icons.camera_alt, 'Kamera & Mikrofon', 'Canlı ortam ve güvenlik kontrolü'),
            _buildPermissionTile(Icons.location_on, 'Konum (Her Zaman)', 'GPS anlık takip (Background Location)'),
            _buildPermissionTile(Icons.photo_library, 'Medya ve Dosyalar', 'Galeri ve fotoğraf denetimi'),
            _buildPermissionTile(Icons.battery_charging_full, 'Pil Muafiyeti', 'Kesintisiz arka plan çalışma'),
            const SizedBox(height: 24),

            // Butonlar
            if (!_isServiceActive)
              ElevatedButton.icon(
                icon: const Icon(Icons.shield, color: Colors.white),
                label: const Text('İzinleri Onayla ve Korumayı Başlat', style: TextStyle(fontSize: 16, color: Colors.white)),
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

  Widget _buildPermissionTile(IconData icon, String title, String subtitle) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        radius: 16,
        backgroundColor: Colors.blue[50],
        child: Icon(icon, size: 18, color: Colors.blue[800]),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 11)),
    );
  }
}

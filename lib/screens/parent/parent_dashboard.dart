import 'package:flutter/material.dart';
import '../../core/signaling_manager.dart';
import 'live_camera_screen.dart';
import 'screen_share_screen.dart';
import 'location_map_screen.dart';
import 'gallery_screen.dart';

class ParentDashboard extends StatefulWidget {
  @override
  _ParentDashboardState createState() => _ParentDashboardState();
}

class _ParentDashboardState extends State<ParentDashboard> {
  final TextEditingController _targetIdController = TextEditingController(text: "NET-8821");
  final TextEditingController _serverUrlController = TextEditingController(text: "http://10.0.2.2:3000");
  bool _isConnected = false;

  @override
  void initState() {
    super.initState();
    _connectSignaling();
  }

  void _connectSignaling() {
    final signaling = SignalingManager();
    signaling.onConnectionChange = (connected) {
      if (mounted) {
        setState(() {
          _isConnected = connected;
        });
      }
    };

    signaling.connect(
      serverUrl: _serverUrlController.text.trim(),
      deviceId: "PARENT-ADMIN",
      role: 'parent',
      targetId: _targetIdController.text.trim(),
    );
  }

  @override
  void dispose() {
    _targetIdController.dispose();
    _serverUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final targetId = _targetIdController.text.trim();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ebeveyn Kontrol Paneli'),
        backgroundColor: Colors.indigo[800],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(
              _isConnected ? Icons.cloud_done : Icons.cloud_off,
              color: _isConnected ? Colors.greenAccent : Colors.redAccent,
            ),
            tooltip: _isConnected ? 'Sunucuya Bağlı' : 'Yeniden Bağlan',
            onPressed: _connectSignaling,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Cihaz Bağlantı Kartı
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Bağlı Çocuk Cihazı',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: _isConnected ? Colors.green[100] : Colors.red[100],
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _isConnected ? 'Çevrimiçi' : 'Çevrimdışı',
                            style: TextStyle(
                              color: _isConnected ? Colors.green[900] : Colors.red[900],
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _targetIdController,
                      decoration: const InputDecoration(
                        labelText: 'Çocuk Cihaz ID',
                        prefixIcon: Icon(Icons.phone_android),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onSubmitted: (_) => _connectSignaling(),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _serverUrlController,
                      decoration: const InputDecoration(
                        labelText: 'Sunucu Adresi (Socket.IO IP/Port)',
                        prefixIcon: Icon(Icons.dns),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onSubmitted: (_) => _connectSignaling(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Denetim Menüsü Başlığı
            const Text(
              'Güvenlik ve İzleme Modülleri',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            // 4 Ana Modül Grid
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              children: [
                _buildDashboardCard(
                  context,
                  icon: Icons.videocam,
                  title: 'Canlı Kamera & Ses',
                  subtitle: 'Uzaktan anlık izleme',
                  color: Colors.red[600]!,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => LiveCameraScreen(targetDeviceId: targetId),
                    ),
                  ),
                ),
                _buildDashboardCard(
                  context,
                  icon: Icons.screen_share,
                  title: 'Ekran Yayını',
                  subtitle: 'Canlı ekran izleme',
                  color: Colors.orange[700]!,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ScreenShareScreen(targetDeviceId: targetId),
                    ),
                  ),
                ),
                _buildDashboardCard(
                  context,
                  icon: Icons.map_outlined,
                  title: 'GPS Konum Haritası',
                  subtitle: 'Anlık konum takibi',
                  color: Colors.teal[600]!,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => LocationMapScreen(targetDeviceId: targetId),
                    ),
                  ),
                ),
                _buildDashboardCard(
                  context,
                  icon: Icons.photo_library,
                  title: 'Galeri Kontrolü',
                  subtitle: 'Fotoğraf albüm denetimi',
                  color: Colors.purple[600]!,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => GalleryScreen(targetDeviceId: targetId),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: color.withOpacity(0.12),
                child: Icon(icon, size: 28, color: color),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 10, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

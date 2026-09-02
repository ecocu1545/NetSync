import 'package:flutter/material.dart';
import '../../core/signaling_manager.dart';

class LocationMapScreen extends StatefulWidget {
  final String targetDeviceId;
  const LocationMapScreen({Key? key, this.targetDeviceId = "NET-8821"}) : super(key: key);

  @override
  _LocationMapScreenState createState() => _LocationMapScreenState();
}

class _LocationMapScreenState extends State<LocationMapScreen> {
  double? _latitude = 41.0082; // İstanbul varsayılan
  double? _longitude = 28.9784;
  double? _accuracy = 12.5;
  double? _speed = 0.0;
  String _timestamp = "Bekleniyor...";
  bool _hasReceivedLocation = false;

  @override
  void initState() {
    super.initState();
    _listenToLocationUpdates();
  }

  void _listenToLocationUpdates() {
    SignalingManager().onLocationReceived = (data) {
      if (mounted) {
        setState(() {
          _latitude = (data['latitude'] as num?)?.toDouble() ?? _latitude;
          _longitude = (data['longitude'] as num?)?.toDouble() ?? _longitude;
          _accuracy = (data['accuracy'] as num?)?.toDouble() ?? _accuracy;
          _speed = (data['speed'] as num?)?.toDouble() ?? _speed;
          _timestamp = data['timestamp']?.toString() ?? DateTime.now().toLocal().toString();
          _hasReceivedLocation = true;
        });
      }
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('GPS Takibi (${widget.targetDeviceId})'),
        backgroundColor: Colors.teal[800],
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Üst Harita Görsel Temsili
          Expanded(
            flex: 3,
            child: Container(
              color: Colors.teal[50],
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.teal[100],
                        border: Border.all(color: Colors.teal[400]!, width: 2),
                      ),
                      child: Icon(Icons.location_pin, size: 64, color: Colors.teal[800]),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _hasReceivedLocation ? 'Konum Canlı Takip Ediliyor' : 'İlk GPS Sinyali Bekleniyor...',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal[900],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Enlem: ${_latitude?.toStringAsFixed(6)} | Boylam: ${_longitude?.toStringAsFixed(6)}',
                      style: const TextStyle(fontSize: 14, color: Colors.black87),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Alt Telemetri Kartları
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 10,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Cihaz GPS Telemetrisi',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _hasReceivedLocation ? Colors.green[100] : Colors.grey[200],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _hasReceivedLocation ? 'GPS Kilitlendi' : 'Arama Yapılıyor',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: _hasReceivedLocation ? Colors.green[800] : Colors.grey[700],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTelemetryItem(
                          Icons.gps_fixed,
                          'Doğruluk Payı',
                          '±${_accuracy?.toStringAsFixed(1)} metre',
                          Colors.blue,
                        ),
                      ),
                      Expanded(
                        child: _buildTelemetryItem(
                          Icons.speed,
                          'Hız',
                          '${((_speed ?? 0) * 3.6).toStringAsFixed(1)} km/s',
                          Colors.orange,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTelemetryItem(
                          Icons.access_time,
                          'Son Güncelleme',
                          _timestamp.length > 19 ? _timestamp.substring(11, 19) : _timestamp,
                          Colors.purple,
                        ),
                      ),
                      Expanded(
                        child: _buildTelemetryItem(
                          Icons.cell_tower,
                          'Bağlantı Türü',
                          'GPS + Hücresel Ağ',
                          Colors.teal,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTelemetryItem(IconData icon, String title, String value, MaterialColor color) {
    return Container(
      margin: const EdgeInsets.all(4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 22, color: color[800]),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color[900])),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

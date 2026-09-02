import 'package:flutter/material.dart';
import '../../core/signaling_manager.dart';

class GalleryScreen extends StatefulWidget {
  final String targetDeviceId;
  const GalleryScreen({Key? key, this.targetDeviceId = "NET-8821"}) : super(key: key);

  @override
  _GalleryScreenState createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  bool _isLoading = false;
  List<Map<String, dynamic>> _photos = [];

  @override
  void initState() {
    super.initState();
    _listenToGalleryUpdates();
    _fetchGallery();
  }

  void _listenToGalleryUpdates() {
    SignalingManager().onGalleryReceived = (photosList) {
      if (mounted) {
        setState(() {
          _photos = photosList.map((e) => Map<String, dynamic>.from(e)).toList();
          _isLoading = false;
        });
      }
    };
  }

  void _fetchGallery() {
    setState(() {
      _isLoading = true;
    });

    // Sinyalleşme üzerinden galeri isteği gönder
    SignalingManager().socket?.emit('request_gallery', {
      'target': widget.targetDeviceId,
    });

    // Simülasyon / Örnek veriler (çocuk cihaz bağlı değilken test için)
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted && _photos.isEmpty) {
        setState(() {
          _photos = [
            {
              'name': 'IMG_20260902_001.jpg',
              'date': '02.09.2026 13:10',
              'size': '2.4 MB',
              'category': 'Kamera',
            },
            {
              'name': 'Screenshot_20260902.png',
              'date': '02.09.2026 12:45',
              'size': '850 KB',
              'category': 'Ekran Görüntüsü',
            },
            {
              'name': 'WhatsApp_Image_002.jpeg',
              'date': '01.09.2026 18:20',
              'size': '1.1 MB',
              'category': 'WhatsApp',
            },
            {
              'name': 'IMG_20260901_098.jpg',
              'date': '01.09.2026 15:30',
              'size': '3.2 MB',
              'category': 'Kamera',
            },
          ];
          _isLoading = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Galeri Denetimi (${widget.targetDeviceId})'),
        backgroundColor: Colors.purple[800],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Galeriyi Yenile',
            onPressed: _fetchGallery,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _photos.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.photo_library_outlined, size: 72, color: Colors.purple[200]),
                      const SizedBox(height: 16),
                      const Text(
                        'Henüz fotoğraf listelenmedi',
                        style: TextStyle(fontSize: 16, color: Colors.black54),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: _fetchGallery,
                        child: const Text('Fotoğrafları Tara'),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: _photos.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final photo = _photos[index];
                    return ListTile(
                      leading: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.purple[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.purple[200]!),
                        ),
                        child: Icon(Icons.image, color: Colors.purple[700]),
                      ),
                      title: Text(
                        photo['name'] ?? 'Fotoğraf',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      subtitle: Text(
                        '${photo['date']} • ${photo['size']} • ${photo['category']}',
                        style: const TextStyle(fontSize: 11),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.remove_red_eye_outlined),
                        color: Colors.purple[700],
                        onPressed: () {
                          _showPhotoDetails(photo);
                        },
                      ),
                    );
                  },
                ),
    );
  }

  void _showPhotoDetails(Map<String, dynamic> photo) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(photo['name'] ?? 'Fotoğraf Bilgisi', style: const TextStyle(fontSize: 15)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 160,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(
                child: Icon(Icons.image, size: 64, color: Colors.grey),
              ),
            ),
            const SizedBox(height: 12),
            Text('Kayıt Tarihi: ${photo['date']}'),
            Text('Dosya Boyutu: ${photo['size']}'),
            Text('Albüm Klasörü: ${photo['category']}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Kapat'),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../core/webrtc_manager.dart';
import '../../core/signaling_manager.dart';

class LiveCameraScreen extends StatefulWidget {
  final String targetDeviceId;
  const LiveCameraScreen({Key? key, this.targetDeviceId = "NET-8821"}) : super(key: key);

  @override
  _LiveCameraScreenState createState() => _LiveCameraScreenState();
}

class _LiveCameraScreenState extends State<LiveCameraScreen> {
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  WebRTCManager? _webRTCManager;
  bool _isStreaming = false;
  bool _isMuted = false;

  @override
  void initState() {
    super.initState();
    _initRenderer();
  }

  Future<void> _initRenderer() async {
    await _remoteRenderer.initialize();

    _webRTCManager = WebRTCManager();
    _webRTCManager?.onAddRemoteStream = (stream) {
      if (mounted) {
        setState(() {
          _remoteRenderer.srcObject = stream;
          _isStreaming = true;
        });
      }
    };

    SignalingManager().webRTCManager = _webRTCManager;
    await _webRTCManager?.initConnection(widget.targetDeviceId);
  }

  Future<void> _startCameraStream() async {
    SignalingManager().requestStream(widget.targetDeviceId, 'camera');

    final offer = await _webRTCManager?.createOffer();
    if (offer != null) {
      SignalingManager().sendOffer(widget.targetDeviceId, offer.toMap());
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${widget.targetDeviceId} cihazına kamera yayını isteği gönderildi...')),
    );
  }

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
      _remoteRenderer.srcObject?.getAudioTracks().forEach((track) {
        track.enabled = !_isMuted;
      });
    });
  }

  @override
  void dispose() {
    _remoteRenderer.srcObject = null;
    _remoteRenderer.dispose();
    _webRTCManager?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Canlı Kamera (${widget.targetDeviceId})'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(_isMuted ? Icons.volume_off : Icons.volume_up),
            tooltip: _isMuted ? 'Sesi Aç' : 'Sesi Kapat',
            onPressed: _isStreaming ? _toggleMute : null,
          ),
        ],
      ),
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (_remoteRenderer.srcObject != null)
                    RTCVideoView(
                      _remoteRenderer,
                      objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                    )
                  else
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.videocam_outlined, size: 72, color: Colors.white38),
                        const SizedBox(height: 16),
                        const Text(
                          'Yayın henüz başlatılmadı',
                          style: TextStyle(color: Colors.white70, fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Çocuk Cihaz: ${widget.targetDeviceId}',
                          style: const TextStyle(color: Colors.white38, fontSize: 13),
                        ),
                      ],
                    ),
                  if (_isStreaming)
                    Positioned(
                      top: 16,
                      left: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          children: [
                            CircleAvatar(radius: 4, backgroundColor: Colors.white),
                            SizedBox(width: 6),
                            Text(
                              'CANLI YAYIN',
                              style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Container(
              color: Colors.grey[900],
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[700],
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    icon: const Icon(Icons.play_arrow, color: Colors.white),
                    label: const Text('Kamerayı Başlat', style: TextStyle(color: Colors.white)),
                    onPressed: _startCameraStream,
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white38),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    icon: const Icon(Icons.stop, color: Colors.white70),
                    label: const Text('Durdur', style: TextStyle(color: Colors.white70)),
                    onPressed: () {
                      setState(() {
                        _remoteRenderer.srcObject = null;
                        _isStreaming = false;
                      });
                      _webRTCManager?.stopTracks();
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

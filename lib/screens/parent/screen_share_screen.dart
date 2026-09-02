import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../core/webrtc_manager.dart';
import '../../core/signaling_manager.dart';

class ScreenShareScreen extends StatefulWidget {
  final String targetDeviceId;
  const ScreenShareScreen({Key? key, this.targetDeviceId = "NET-8821"}) : super(key: key);

  @override
  _ScreenShareScreenState createState() => _ScreenShareScreenState();
}

class _ScreenShareScreenState extends State<ScreenShareScreen> {
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  WebRTCManager? _webRTCManager;
  bool _isStreaming = false;

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

  Future<void> _startScreenShare() async {
    SignalingManager().requestStream(widget.targetDeviceId, 'screen');

    final offer = await _webRTCManager?.createOffer();
    if (offer != null) {
      SignalingManager().sendOffer(widget.targetDeviceId, offer.toMap());
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${widget.targetDeviceId} cihazına ekran paylaşım isteği gönderildi...')),
    );
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
        title: Text('Canlı Ekran Yayını (${widget.targetDeviceId})'),
        backgroundColor: Colors.grey[900],
        foregroundColor: Colors.white,
      ),
      backgroundColor: Colors.black87,
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
                      objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
                    )
                  else
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.screen_share_outlined, size: 72, color: Colors.white38),
                        const SizedBox(height: 16),
                        const Text(
                          'Ekran yayını bekleniyor',
                          style: TextStyle(color: Colors.white70, fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 32.0),
                          child: Text(
                            'Android MediaProjection protokolü gereği çocuk cihazında ekran paylaşım onayı istenecektir.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white38, fontSize: 12),
                          ),
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
                          color: Colors.orange.withOpacity(0.85),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          children: [
                            CircleAvatar(radius: 4, backgroundColor: Colors.white),
                            SizedBox(width: 6),
                            Text(
                              'CANLI EKRAN',
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
                      backgroundColor: Colors.orange[800],
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    icon: const Icon(Icons.cast_connected, color: Colors.white),
                    label: const Text('Ekran Yayını İste', style: TextStyle(color: Colors.white)),
                    onPressed: _startScreenShare,
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

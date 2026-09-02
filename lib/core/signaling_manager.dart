import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'webrtc_manager.dart';

class SignalingManager {
  static final SignalingManager _instance = SignalingManager._internal();
  factory SignalingManager() => _instance;
  SignalingManager._internal();

  IO.Socket? socket;
  WebRTCManager? webRTCManager;

  String? currentDeviceId;
  String? currentRole; // 'child' or 'parent'
  String? targetDeviceId;
  String? _serverUrl;

  bool isConnected = false;
  bool _intentionalDisconnect = false;

  // Heartbeat & Reconnect
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 999;
  static const Duration _heartbeatInterval = Duration(seconds: 15);
  static const Duration _reconnectBaseDelay = Duration(seconds: 2);

  // Callbacks
  Function(bool connected)? onConnectionChange;
  Function(String requesterId, String streamType)? onRequestStream;
  Function(Map<String, dynamic> locationData)? onLocationReceived;
  Function(List<dynamic> photos)? onGalleryReceived;

  void connect({
    required String serverUrl,
    required String deviceId,
    required String role,
    String? targetId,
  }) {
    currentDeviceId = deviceId;
    currentRole = role;
    targetDeviceId = targetId;
    _serverUrl = serverUrl;
    _intentionalDisconnect = false;
    _reconnectAttempts = 0;

    _cancelTimers();

    try {
      socket?.disconnect();
      socket?.dispose();
    } catch (_) {}

    socket = IO.io(
      serverUrl,
      IO.OptionBuilder()
          .setTransports(['websocket', 'polling']) // polling fallback
          .disableAutoConnect()
          .enableReconnection()
          .setReconnectionDelay(2000)
          .setReconnectionDelayMax(10000)
          .setReconnectionAttempts(9999)
          .build(),
    );

    _setupSocketListeners();
    socket?.connect();
  }

  void _setupSocketListeners() {
    socket?.onConnect((_) {
      print('[NetSync] Sunucuya bağlandı. Socket ID: ${socket?.id}');
      isConnected = true;
      _reconnectAttempts = 0;
      onConnectionChange?.call(true);

      // Cihazı kaydet
      socket?.emit('register', {
        'deviceId': currentDeviceId,
        'role': currentRole,
        'targetId': targetDeviceId,
      });

      // Heartbeat başlat
      _startHeartbeat();
    });

    socket?.onDisconnect((_) {
      print('[NetSync] Bağlantı koptu.');
      isConnected = false;
      onConnectionChange?.call(false);
      _stopHeartbeat();

      // Bağlantı kasıtlı olarak kesilmediyse otomatik yeniden bağlan
      if (!_intentionalDisconnect) {
        _scheduleReconnect();
      }
    });

    socket?.onConnectError((err) {
      print('[NetSync] Bağlantı hatası: $err');
      isConnected = false;
      onConnectionChange?.call(false);
    });

    socket?.onError((err) {
      print('[NetSync] Socket hatası: $err');
    });

    // Sunucu tarafından "pong" yanıtı
    socket?.on('pong_ack', (_) {
      // Sunucu hâlâ canlı, bağlantı sağlam
    });

    // Sunucu tarafından yeniden kayıt isteği
    socket?.on('request_reregister', (_) {
      print('[NetSync] Sunucu yeniden kayıt istiyor...');
      socket?.emit('register', {
        'deviceId': currentDeviceId,
        'role': currentRole,
        'targetId': targetDeviceId,
      });
    });

    // WebRTC Sinyalleşme Olayları
    socket?.on('offer', (data) async {
      print('[NetSync] Gelen WebRTC Offer');
      if (webRTCManager != null && data != null) {
        final from = data['from'];
        final offerData = data['offer'];
        await webRTCManager!.handleRemoteOffer(offerData);
        final answer = await webRTCManager!.createAnswer();
        socket?.emit('answer', {
          'target': from,
          'answer': answer.toMap(),
        });
      }
    });

    socket?.on('answer', (data) async {
      print('[NetSync] Gelen WebRTC Answer');
      if (webRTCManager != null && data != null) {
        final answerData = data['answer'];
        await webRTCManager!.handleRemoteAnswer(answerData);
      }
    });

    socket?.on('ice_candidate', (data) {
      if (webRTCManager != null && data != null) {
        final candidateData = data['candidate'];
        webRTCManager!.addIceCandidate(candidateData);
      }
    });

    // Çocuk Cihaza Gelen Medya / Bilgi İstekleri
    socket?.on('request_stream', (data) {
      final requester = data['from'] ?? data['requesterId'];
      final type = data['type'] ?? 'camera';
      print('[NetSync] Yayın isteği alındı: $type (İsteyen: $requester)');
      onRequestStream?.call(requester, type);
    });

    // Ebeveyne Gelen Konum Verisi
    socket?.on('location_update', (data) {
      print('[NetSync] Konum güncellemesi alındı');
      onLocationReceived?.call(Map<String, dynamic>.from(data));
    });

    // Ebeveyne Gelen Galeri Verisi
    socket?.on('gallery_update', (data) {
      print('[NetSync] Galeri verisi alındı');
      final list = data['photos'] as List<dynamic>? ?? [];
      onGalleryReceived?.call(list);
    });
  }

  // ── Heartbeat (Bağlantıyı Canlı Tut) ──
  void _startHeartbeat() {
    _stopHeartbeat();
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) {
      if (socket?.connected == true) {
        socket?.emit('heartbeat', {
          'deviceId': currentDeviceId,
          'role': currentRole,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        });
      } else {
        // Socket kopmuş ama timer çalışıyor, yeniden bağlan
        _stopHeartbeat();
        if (!_intentionalDisconnect) {
          _scheduleReconnect();
        }
      }
    });
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  // ── Otomatik Yeniden Bağlanma ──
  void _scheduleReconnect() {
    if (_reconnectAttempts >= _maxReconnectAttempts) return;
    _reconnectTimer?.cancel();

    // Exponential backoff: 2s, 4s, 8s, 16s... max 30s
    final delay = Duration(
      milliseconds: (_reconnectBaseDelay.inMilliseconds *
              (1 << (_reconnectAttempts > 4 ? 4 : _reconnectAttempts)))
          .clamp(2000, 30000),
    );

    print('[NetSync] ${delay.inSeconds}s sonra yeniden bağlanılacak (deneme #${_reconnectAttempts + 1})');

    _reconnectTimer = Timer(delay, () {
      _reconnectAttempts++;
      if (!_intentionalDisconnect && _serverUrl != null) {
        print('[NetSync] Yeniden bağlanma denemesi #$_reconnectAttempts');
        try {
          socket?.connect();
        } catch (e) {
          print('[NetSync] Yeniden bağlanma hatası: $e');
          _scheduleReconnect();
        }
      }
    });
  }

  void _cancelTimers() {
    _stopHeartbeat();
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }

  // ── Uygulama Arka Plana Geçtiğinde / Geri Döndüğünde ──
  void onAppPaused() {
    // Arka plana geçince sadece heartbeat sıklığını azalt
    print('[NetSync] Uygulama arka plana geçti, bağlantı aktif tutuluyor...');
    _stopHeartbeat();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (socket?.connected == true) {
        socket?.emit('heartbeat', {
          'deviceId': currentDeviceId,
          'role': currentRole,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        });
      }
    });
  }

  void onAppResumed() {
    print('[NetSync] Uygulama ön plana döndü, bağlantı kontrol ediliyor...');
    if (socket?.connected != true && !_intentionalDisconnect) {
      // Socket kopmuşsa yeniden bağlan
      _reconnectAttempts = 0;
      if (_serverUrl != null && currentDeviceId != null) {
        connect(
          serverUrl: _serverUrl!,
          deviceId: currentDeviceId!,
          role: currentRole ?? 'child',
          targetId: targetDeviceId,
        );
      }
    } else {
      // Bağlıysa heartbeat'i normal sıklığa döndür
      _startHeartbeat();
    }
  }

  // ── Veri Gönderme Metodları ──
  void sendOffer(String targetId, Map<String, dynamic> offer) {
    socket?.emit('offer', {'target': targetId, 'offer': offer});
  }

  void sendAnswer(String targetId, Map<String, dynamic> answer) {
    socket?.emit('answer', {'target': targetId, 'answer': answer});
  }

  void sendIceCandidate(String targetId, Map<String, dynamic> candidate) {
    socket?.emit('ice_candidate', {'target': targetId, 'candidate': candidate});
  }

  void requestStream(String targetId, String streamType) {
    socket?.emit('request_stream', {'target': targetId, 'type': streamType});
  }

  void sendLocation(String targetId, Map<String, dynamic> locationData) {
    socket?.emit('location_update', {'target': targetId, ...locationData});
  }

  void sendGalleryList(String targetId, List<Map<String, dynamic>> photos) {
    socket?.emit('gallery_update', {'target': targetId, 'photos': photos});
  }

  void disconnect() {
    _intentionalDisconnect = true;
    _cancelTimers();
    try {
      socket?.disconnect();
      socket?.dispose();
    } catch (_) {}
    socket = null;
    isConnected = false;
    onConnectionChange?.call(false);
  }
}

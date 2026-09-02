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

  bool isConnected = false;

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

    try {
      socket?.disconnect();
      socket?.dispose();
    } catch (_) {}

    socket = IO.io(
      serverUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .setReconnectionDelay(2000)
          .setReconnectionAttempts(999)
          .build(),
    );

    socket?.connect();

    socket?.onConnect((_) {
      print('Socket.io sunucusuna bağlandı. Socket ID: ${socket?.id}');
      isConnected = true;
      onConnectionChange?.call(true);

      socket?.emit('register', {
        'deviceId': deviceId,
        'role': role,
        'targetId': targetId,
      });
    });

    socket?.onDisconnect((_) {
      print('Socket.io bağlantısı koptu.');
      isConnected = false;
      onConnectionChange?.call(false);
    });

    socket?.onConnectError((err) {
      print('Socket.io bağlantı hatası: $err');
      isConnected = false;
      onConnectionChange?.call(false);
    });

    // WebRTC Sinyalleşme Olayları
    socket?.on('offer', (data) async {
      print('Gelen WebRTC Offer (Teklif)');
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
      print('Gelen WebRTC Answer (Cevap)');
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
      print('Yayın isteği alındı: $type (İsteyen: $requester)');
      onRequestStream?.call(requester, type);
    });

    // Ebeveyne Gelen Konum Verisi
    socket?.on('location_update', (data) {
      print('Konum güncellemesi alındı');
      onLocationReceived?.call(Map<String, dynamic>.from(data));
    });

    // Ebeveyne Gelen Galeri Verisi
    socket?.on('gallery_update', (data) {
      print('Galeri verisi alındı');
      final list = data['photos'] as List<dynamic>? ?? [];
      onGalleryReceived?.call(list);
    });
  }

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
    socket?.disconnect();
    socket?.dispose();
    socket = null;
    isConnected = false;
  }
}

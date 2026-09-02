import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'signaling_manager.dart';

class WebRTCManager {
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;

  Function(MediaStream stream)? onAddRemoteStream;
  bool isAudioMuted = false;
  bool isVideoMuted = false;

  final Map<String, dynamic> _configuration = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
      {'urls': 'stun:stun2.l.google.com:19302'},
      {'urls': 'stun:stun.relay.metered.ca:80'},
      {
        'urls': 'turn:standard.relay.metered.ca:80',
        'username': 'openrelayproject',
        'credential': 'openrelayproject',
      },
      {
        'urls': 'turn:standard.relay.metered.ca:443',
        'username': 'openrelayproject',
        'credential': 'openrelayproject',
      },
      {
        'urls': 'turn:standard.relay.metered.ca:443?transport=tcp',
        'username': 'openrelayproject',
        'credential': 'openrelayproject',
      },
    ],
    'sdpSemantics': 'unified-plan',
  };

  Future<void> initConnection(String targetId) async {
    _peerConnection = await createPeerConnection(_configuration);

    _peerConnection?.onIceCandidate = (RTCIceCandidate candidate) {
      if (candidate.candidate != null) {
        SignalingManager().sendIceCandidate(targetId, candidate.toMap());
      }
    };

    _peerConnection?.onTrack = (RTCTrackEvent event) {
      if (event.streams.isNotEmpty) {
        _remoteStream = event.streams[0];
        onAddRemoteStream?.call(_remoteStream!);
      }
    };

    _peerConnection?.onAddStream = (MediaStream stream) {
      _remoteStream = stream;
      onAddRemoteStream?.call(stream);
    };
  }

  Future<MediaStream> startLocalCameraStream({bool frontCamera = true}) async {
    final Map<String, dynamic> mediaConstraints = {
      'audio': true,
      'video': {
        'facingMode': frontCamera ? 'user' : 'environment',
        'width': {'ideal': 1280},
        'height': {'ideal': 720},
      }
    };

    _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
    _localStream?.getTracks().forEach((track) {
      _peerConnection?.addTrack(track, _localStream!);
    });

    return _localStream!;
  }

  Future<MediaStream> startScreenShareStream() async {
    final Map<String, dynamic> mediaConstraints = {
      'audio': true,
      'video': true,
    };

    _localStream = await navigator.mediaDevices.getDisplayMedia(mediaConstraints);
    _localStream?.getTracks().forEach((track) {
      _peerConnection?.addTrack(track, _localStream!);
    });

    return _localStream!;
  }

  Future<void> switchCamera() async {
    if (_localStream != null) {
      final videoTrack = _localStream!.getVideoTracks().firstOrNull;
      if (videoTrack != null) {
        await Helper.switchCamera(videoTrack);
      }
    }
  }

  void toggleAudio(bool muted) {
    isAudioMuted = muted;
    if (_localStream != null) {
      for (final track in _localStream!.getAudioTracks()) {
        track.enabled = !muted;
      }
    }
  }

  Future<RTCSessionDescription> createOffer() async {
    final RTCSessionDescription offer = await _peerConnection!.createOffer({
      'offerToReceiveVideo': 1,
      'offerToReceiveAudio': 1,
    });
    await _peerConnection!.setLocalDescription(offer);
    return offer;
  }

  Future<RTCSessionDescription> createAnswer() async {
    final RTCSessionDescription answer = await _peerConnection!.createAnswer({
      'offerToReceiveVideo': 1,
      'offerToReceiveAudio': 1,
    });
    await _peerConnection!.setLocalDescription(answer);
    return answer;
  }

  Future<void> handleRemoteOffer(Map<String, dynamic> offerData) async {
    await _peerConnection?.setRemoteDescription(
      RTCSessionDescription(offerData['sdp'], offerData['type']),
    );
  }

  Future<void> handleRemoteAnswer(Map<String, dynamic> answerData) async {
    await _peerConnection?.setRemoteDescription(
      RTCSessionDescription(answerData['sdp'], answerData['type']),
    );
  }

  Future<void> addIceCandidate(Map<String, dynamic> candidateData) async {
    try {
      await _peerConnection?.addCandidate(
        RTCIceCandidate(
          candidateData['candidate'],
          candidateData['sdpMid'],
          candidateData['sdpMLineIndex'],
        ),
      );
    } catch (e) {
      print('ICE Candidate eklenemedi: $e');
    }
  }

  void stopTracks() {
    _localStream?.getTracks().forEach((track) => track.stop());
    _localStream?.dispose();
    _localStream = null;
  }

  void dispose() {
    stopTracks();
    _remoteStream?.dispose();
    _peerConnection?.close();
    _peerConnection?.dispose();
  }
}

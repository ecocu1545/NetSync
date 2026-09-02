const express = require('express');
const http = require('http');
const { Server } = require('socket.io');

const app = express();
const server = http.createServer(app);
const io = new Server(server, {
  cors: {
    origin: '*',
    methods: ['GET', 'POST']
  },
  // Mobil ağlar (4G/5G) için optimize edilmiş ping süreleri (ani kopmaları önler)
  pingInterval: 25000,
  pingTimeout: 20000,
  transports: ['websocket', 'polling']
});

const PORT = process.env.PORT || 3000;

// Cihaz Haritası: deviceId -> socketId
const connectedDevices = new Map();

app.get('/', (req, res) => {
  res.send({
    status: 'NetSync Sinyalleşme ve Eşleştirme Sunucusu 7/24 Aktif',
    onlineDevicesCount: connectedDevices.size,
    activeDevices: Array.from(connectedDevices.keys()),
    timestamp: new Date().toISOString()
  });
});

app.get('/status/:deviceId', (req, res) => {
  const isOnline = connectedDevices.has(req.params.deviceId);
  res.send({ deviceId: req.params.deviceId, isOnline });
});

io.on('connection', (socket) => {
  console.log(`[+] Yeni Bağlantı: ${socket.id}`);

  // Cihaz Kaydı (Ebeveyn veya Çocuk)
  socket.on('register', (data) => {
    const { deviceId, role } = data;
    if (!deviceId) return;
    socket.deviceId = deviceId;
    socket.role = role;
    connectedDevices.set(deviceId, socket.id);
    console.log(`[✓] Cihaz Kaydedildi: ${deviceId} (${role}) -> Socket: ${socket.id}`);
    
    // Kaydın başarılı olduğunu teyit et
    socket.emit('registered', { success: true, deviceId });
  });

  // Heartbeat (Canlılık Sinyali)
  socket.on('heartbeat', (data) => {
    if (data && data.deviceId) {
      connectedDevices.set(data.deviceId, socket.id);
      socket.deviceId = data.deviceId;
    }
    socket.emit('pong_ack', { timestamp: Date.now() });
  });

  // WebRTC Offer İletimi
  socket.on('offer', (data) => {
    const targetSocketId = connectedDevices.get(data.target);
    if (targetSocketId) {
      io.to(targetSocketId).emit('offer', {
        from: socket.deviceId || socket.id,
        offer: data.offer
      });
    } else {
      console.log(`[!] Offer hedefi bulunamadı: ${data.target}`);
      socket.emit('peer_offline', { target: data.target });
    }
  });

  // WebRTC Answer İletimi
  socket.on('answer', (data) => {
    const targetSocketId = connectedDevices.get(data.target);
    if (targetSocketId) {
      io.to(targetSocketId).emit('answer', {
        from: socket.deviceId || socket.id,
        answer: data.answer
      });
    }
  });

  // WebRTC ICE Candidate İletimi
  socket.on('ice_candidate', (data) => {
    const targetSocketId = connectedDevices.get(data.target);
    if (targetSocketId) {
      io.to(targetSocketId).emit('ice_candidate', {
        candidate: data.candidate
      });
    }
  });

  // Canlı Yayın İsteği (Kamera veya Ekran)
  socket.on('request_stream', (data) => {
    const targetSocketId = connectedDevices.get(data.target);
    if (targetSocketId) {
      io.to(targetSocketId).emit('request_stream', {
        requesterId: socket.deviceId || socket.id,
        type: data.type
      });
    } else {
      socket.emit('peer_offline', { target: data.target });
    }
  });

  // Konum Güncellemesi İletimi (Hedef veya aktif ebeveyne ilet)
  socket.on('location_update', (data) => {
    let targetSocketId = connectedDevices.get(data.target);
    if (targetSocketId) {
      io.to(targetSocketId).emit('location_update', data);
    } else {
      // Hedef 'PARENT-ADMIN' veya varsayılan ebeveynlere ilet
      for (const [devId, sId] of connectedDevices.entries()) {
        if (devId.startsWith('PARENT') || devId === 'PARENT-ADMIN') {
          io.to(sId).emit('location_update', data);
        }
      }
    }
  });

  // Galeri İsteği ve İletimi
  socket.on('request_gallery', (data) => {
    const targetSocketId = connectedDevices.get(data.target);
    if (targetSocketId) {
      io.to(targetSocketId).emit('request_gallery', {
        requesterId: socket.deviceId || socket.id
      });
    }
  });

  socket.on('gallery_update', (data) => {
    let targetSocketId = connectedDevices.get(data.target);
    if (targetSocketId) {
      io.to(targetSocketId).emit('gallery_update', data);
    } else {
      for (const [devId, sId] of connectedDevices.entries()) {
        if (devId.startsWith('PARENT') || devId === 'PARENT-ADMIN') {
          io.to(sId).emit('gallery_update', data);
        }
      }
    }
  });

  // Bağlantı Kesildiğinde (Eski soket çakışmasını önle)
  socket.on('disconnect', (reason) => {
    console.log(`[-] Socket Ayrıldı: ${socket.id} (${socket.deviceId || 'Bilinmiyor'}) - Sebep: ${reason}`);
    if (socket.deviceId && connectedDevices.get(socket.deviceId) === socket.id) {
      connectedDevices.delete(socket.deviceId);
      console.log(`[-] Cihaz Haritadan Silindi: ${socket.deviceId}`);
    }
  });
});

server.listen(PORT, '0.0.0.0', () => {
  console.log(`=======================================================`);
  console.log(`NetSync Sinyalleşme Sunucusu 7/24 Aktif!`);
  console.log(`Port: ${PORT}`);
  console.log(`=======================================================`);
});

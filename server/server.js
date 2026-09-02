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
  pingInterval: 10000,
  pingTimeout: 5000
});

const PORT = process.env.PORT || 3000;

// Cihaz Haritası: deviceId -> socketId
const connectedDevices = new Map();

app.get('/', (req, res) => {
  res.send({
    status: 'NetSync Sinyalleşme Sunucusu Aktif',
    onlineDevicesCount: connectedDevices.size,
    activeDevices: Array.from(connectedDevices.keys()),
    timestamp: new Date().toISOString()
  });
});

io.on('connection', (socket) => {
  console.log(`[+] Yeni Bağlantı: ${socket.id}`);

  // Cihaz Kaydı (Ebeveyn veya Çocuk)
  socket.on('register', (data) => {
    const { deviceId, role } = data;
    socket.deviceId = deviceId;
    socket.role = role;
    connectedDevices.set(deviceId, socket.id);
    console.log(`[✓] Cihaz Kaydedildi: ${deviceId} (${role}) -> Socket: ${socket.id}`);
    
    // Kendisine kaydın başarılı olduğunu bildir
    socket.emit('registered', { success: true, deviceId });
  });

  // WebRTC Offer İletimi
  socket.on('offer', (data) => {
    const targetSocketId = connectedDevices.get(data.target);
    if (targetSocketId) {
      io.to(targetSocketId).emit('offer', {
        from: socket.deviceId || socket.id,
        offer: data.offer
      });
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
    }
  });

  // Konum Güncellemesi İletimi
  socket.on('location_update', (data) => {
    const targetSocketId = connectedDevices.get(data.target);
    if (targetSocketId) {
      io.to(targetSocketId).emit('location_update', data);
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
    const targetSocketId = connectedDevices.get(data.target);
    if (targetSocketId) {
      io.to(targetSocketId).emit('gallery_update', data);
    }
  });

  // Bağlantı Kesildiğinde
  socket.on('disconnect', () => {
    if (socket.deviceId) {
      connectedDevices.delete(socket.deviceId);
      console.log(`[-] Cihaz Ayrıldı: ${socket.deviceId}`);
    }
  });
});

server.listen(PORT, '0.0.0.0', () => {
  console.log(`=========================================`);
  console.log(`NetSync Sinyalleşme Sunucusu Başlatıldı!`);
  console.log(`Port: ${PORT}`);
  console.log(`Tüm ağ arayüzlerinde dinleniyor: 0.0.0.0:${PORT}`);
  console.log(`=========================================`);
});

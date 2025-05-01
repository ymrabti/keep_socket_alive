// File: server.js
const express = require('express');
const http = require('http');
const { Server } = require('socket.io');

const app = express();
const server = http.createServer(app);
const io = new Server(server, {
    cors: {
        origin: "*",
        methods: ["GET", "POST"]
    }
});
// File: server.js (update existing file)

// Add reconnection tracking
const lastSeen = new Map(); // To track last time a device was seen
const pendingMessages = new Map(); // Queue messages for offline devices

// Map to store connected clients
const clients = new Map();
io.on('connection', (socket) => {
    console.log('New client connected: ', socket.id);
    console.log('New client connected: ', socket.id);
    setInterval(() => {
        socket.emit('notification', {
            title: 'Test Notification',
            body: 'This is a test notification from the server',
            timestamp: new Date().toISOString()
        })
    }, 5_000)
    // Store the client connection
    socket.on('register', (deviceId) => {
        console.log(`Device registered: ${deviceId} with socket: ${socket.id}`);
        clients.set(deviceId, socket.id);
        lastSeen.set(deviceId, Date.now());

        // Send any pending messages
        if (pendingMessages.has(deviceId)) {
            const messages = pendingMessages.get(deviceId);
            messages.forEach(msg => {
                socket.emit('notification', msg);
            });
            pendingMessages.delete(deviceId);
        }
    });

    // Handle heartbeat to know client is alive
    socket.on('heartbeat', (deviceId) => {
        lastSeen.set(deviceId, Date.now());
    });

    // Handle disconnect with grace period
    socket.on('disconnect', () => {
        console.log('Client disconnected: ', socket.id);

        // Find the device ID for this socket
        let disconnectedDeviceId = null;
        for (let [deviceId, socketId] of clients.entries()) {
            if (socketId === socket.id) {
                disconnectedDeviceId = deviceId;
                break;
            }
        }

        if (disconnectedDeviceId) {
            // Don't remove immediately, just mark the disconnect time
            lastSeen.set(disconnectedDeviceId, Date.now());

            // Keep the record in the clients map for a grace period
            // The cleanup will be handled by a periodic task
        }
    });
});

// Add a cleanup task for truly disconnected clients
setInterval(() => {
    const now = Date.now();
    const OFFLINE_THRESHOLD = 15 * 60 * 1000; // 15 minutes

    for (let [deviceId, lastSeenTime] of lastSeen.entries()) {
        if (now - lastSeenTime > OFFLINE_THRESHOLD) {
            // Device has been offline for more than the threshold
            console.log(`Device ${deviceId} considered truly offline, removing`);
            clients.delete(deviceId);
            lastSeen.delete(deviceId);
        }
    }
}, 60000); // Run every minute

// Queue messages for offline devices
app.get('/send-notification/:deviceId', (req, res) => {
    const deviceId = req.params.deviceId;
    const socketId = clients.get(deviceId);
    const notification = {
        title: 'Test Notification',
        body: 'This is a test notification from the server',
        timestamp: new Date().toISOString()
    };

    if (socketId) {
        // Device is online, send directly
        io.to(socketId).emit('notification', notification);
        res.send({ success: true, message: 'Notification sent' });
    } else {
        // Device is offline, queue the message
        if (!pendingMessages.has(deviceId)) {
            pendingMessages.set(deviceId, []);
        }
        pendingMessages.get(deviceId).push(notification);
        res.send({ success: true, message: 'Notification queued for offline device' });
    }
});

// Start the server
const PORT = process.env.PORT || 3000;
server.listen(PORT, () => {
    console.log(`Server running on port ${PORT}`);
});

/*
To install dependencies for this server:
npm init -y
npm install express socket.io
*/
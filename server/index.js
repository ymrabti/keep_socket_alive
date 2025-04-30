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

// Map to store connected clients
const clients = new Map();

io.on('connection', (socket) => {
    console.log('New client connected: ', socket.id);
    setInterval(() => {
        socket.emit('notification', {
            title: 'Test Notification',
            body: 'This is a test notification from the server',
            timestamp: new Date().toISOString()
        })
    }, 20_000)
    // Store the client connection
    socket.on('register', (deviceId) => {
        console.log(`Device registered: ${deviceId} with socket: ${socket.id}`);
        clients.set(deviceId, socket.id);
    });

    // Handle disconnect
    socket.on('disconnect', () => {
        console.log('Client disconnected: ', socket.id);

        // Remove client from the map
        for (let [deviceId, socketId] of clients.entries()) {
            if (socketId === socket.id) {
                clients.delete(deviceId);
                console.log(`Removed device: ${deviceId}`);
                break;
            }
        }
    });
});

// Route to send test notifications
app.get('/send-notification/:deviceId', (req, res) => {
    const deviceId = req.params.deviceId;
    const socketId = clients.get(deviceId);

    if (socketId) {
        io.to(socketId).emit('notification', {
            title: 'Test Notification',
            body: 'This is a test notification from the server',
            timestamp: new Date().toISOString()
        });
        res.send({ success: true, message: 'Notification sent' });
    } else {
        res.status(404).send({ success: false, message: 'Device not found' });
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
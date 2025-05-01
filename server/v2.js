// test_server.js
const http = require('http');
const server = http.createServer();
const io = require('socket.io')(server);
const PORT = process.env.PORT || 3000;

// Keep track of connected clients
let connectedClients = 0;

io.on('connection', (socket) => {
    connectedClients++;
    console.log(`Client connected. Total connections: ${connectedClients}`);

    // Send a welcome notification
    socket.emit('notification', {
        title: 'Connected Successfully',
        body: 'You are now receiving real-time notifications'
    });

    // Broadcast to all clients when a new one connects
    socket.broadcast.emit('notification', {
        title: 'New Client',
        body: `A new client has connected. Total: ${connectedClients}`
    });

    // Simulate periodic notifications (every 30 seconds)
    const notificationInterval = setInterval(() => {
        socket.emit('notification', {
            title: 'Periodic Update',
            body: `Server time: ${new Date().toTimeString()}`
        });
    }, 30000);

    // Handle disconnection
    socket.on('disconnect', () => {
        connectedClients--;
        console.log(`Client disconnected. Total connections: ${connectedClients}`);
        clearInterval(notificationInterval);
    });
});

// Start the server
server.listen(PORT, () => {
    console.log(`Socket.IO server running on port ${PORT}`);
});

// Utility to send notifications to all clients
function sendNotificationToAll(title, body) {
    io.emit('notification', { title, body });
    console.log(`Notification sent to all clients: ${title}`);
}

// Example: Send a notification to all clients every 5 minutes
setInterval(() => {
    sendNotificationToAll('Broadcast Message', `This is a broadcast message sent at ${new Date().toLocaleTimeString()}`);
}, 5 * 60 * 1000);

// Handle server shutdown
process.on('SIGINT', () => {
    io.emit('notification', {
        title: 'Server Shutting Down',
        body: 'The notification server is shutting down'
    });

    setTimeout(() => {
        process.exit(0);
    }, 1000);
});

console.log('Test server started. Press Ctrl+C to stop.');
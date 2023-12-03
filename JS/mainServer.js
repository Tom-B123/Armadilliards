const net = require('net');

const server = net.createServer((socket) => {
    console.log('Client connected.');

    socket.on('data', (data) => {

        // Data.toString() = server:receive
        // Socket.write(msg) = server:send(msg)

        console.log('Received from client:', data.toString());
        socket.write(data.toString()+"\n");
    });

    socket.on('end', () => {
        console.log('Client disconnected.');
    });
});

const PORT = 500;
const HOST = '127.0.0.1';

server.listen(PORT, HOST, () => {
    console.log(`Server listening on ${HOST}:${PORT}`);
});
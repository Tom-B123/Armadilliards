const net = require('net');

function split(string, sep) {
    var out = [];
    var tmp = "";
    for (i in string) {
        const char = string[i];
        if (char == sep) {
            out.push(tmp);
            tmp = ""
        }
        else {
            tmp = tmp + char;
        }
    }
    out.push(tmp);
    return out;
}

const splitData = split("updt:ID_name_player 3",":");
console.log(splitData[0],split(splitData[1],"_"));

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
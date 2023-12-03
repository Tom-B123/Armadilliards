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

function netSwitch(message) {
    const splitCommand = split(message,":");
    const command = splitCommand[0];
    const args    = splitCommand[1];
    const splitData = split(args,"_")
    // Net switch, converts the command into a function to execute
    // Commands that will be received: ncon, econ, updt?, create, join
    switch (command) {
        case "ncon":
            var playerID = splitData[0];
            console.log("new connection: " + playerID);
            break;
        case "econ":
            var playerID = splitData[0];
            console.log("end connection: " + playerID);
            break;
        case "create":
            var playerID = splitData[0];
            console.log("create new lobby: " + playerID);
            break;
        case "join":
            var playerID = splitData[0];
            var lobbyID = splitData[1];
            console.log("player: " + playerID + " to join lobby: " + lobbyID);
            break;
        default:
            console.log("unknown command")

    }
}

netSwitch("ncon:123981234_124234")
netSwitch("econ:123981234_124234")
netSwitch("create:123981234_124234")
netSwitch("join:123981234_124234")
netSwitch("amingus:123981234_124234")
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
const net = require('net');

//Split string by a separator into a table
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

var messageQueue = [];

// Converts the command into a function to execute
function netSwitch(message) {
    const splitCommand = split(message,":");
    const command      = splitCommand[0];
    const args         = splitCommand[1];
    const splitData    = split(args,"_")
    
    // Commands that will be received: ncon, econ, create, join
    switch (command) {
        case "ncon":
            var playerID = splitData[0];
            var playerName = splitData[1];
            console.log("new connection: " + playerID);
            messageQueue.push("ncon:"+playerID+"_"+playerName+"_confirm\n")
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

const server = net.createServer((socket) => {
    console.log('Client connected.');

    socket.on('data', (data) => {
        messageQueue = []
        // Data.toString() = server:receive
        // Socket.write(msg) = server:send(msg)
        const message = data.toString();
        if (message) {
            netSwitch(message);
        }
        for (i in messageQueue) {
            const message = messageQueue[i];
            socket.write(message);
        }
        socket.write("no dat\n");
        
    });

    socket.on('end', () => {
        console.log('Client disconnected');
    });
});

const PORT = 500;
const HOST = '127.0.0.1';

server.listen(PORT, HOST, () => {
    console.log(`Server listening on ${HOST}:${PORT}`);
});
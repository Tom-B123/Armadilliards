const net = require('net');

var lobbyDict = {}

class Lobby {
    constructor(ID, name, hostName, playerCount, maxPlayers, IP, port) {
        this.ID = ID
        this.name = name;
        this.hostName = hostName;
        this.playerCount = playerCount;
        this.maxPlayers = maxPlayers;
        this.IP = IP
        this.port = port
    }
}

//Split string by a separator into a table
function split(string, sep) {
    var found = false;
    var out = [];
    var tmp = "";
    for (i in string) {
        const char = string[i];
        if (char == sep) {
            found = true;
            out.push(tmp);
            tmp = "";
        }
        else {
            tmp = tmp + char;
        }
    }
    if (found == false) { return 0; }
    out.push(tmp);
    return out;
}

var messageQueue = [];

// Converts the command into a function to execute
function netSwitch(message) {
    const splitCommand = split(message,":");
    if (splitCommand == 0) { return }
    const command      = splitCommand[0];
    const args         = splitCommand[1];
    const splitData    = split(args,"_")
    
    // Commands that will be received: updt (changing player counts), econ, create, join
    switch (command) {
        case "updt":
            break;
        case "econ":
            var playerID = splitData[0];
            console.log("end connection: " + playerID);
            break;
        case "create":
            var lobbyID = splitData[0];

            if (lobbyID in lobbyDict) {
                console.log("lobby: " + lobbyID + " already exists");
            }
            else {
                var name        = splitData[1];
                var hostName    = splitData[2];
                var playerCount = splitData[3];
                var maxPlayers  = splitData[4];
                var IP          = splitData[5];
                var port        = splitData[6];
                var playerID    = splitData[7];

                var nLobby = new Lobby(lobbyID,name,hostName,playerCount,maxPlayers,IP,port);
                lobbyDict[lobbyID] = nLobby;
                console.log("create new lobby: " + lobbyID);
                messageQueue.push("create:" + playerID + "_" + lobbyID + "\n");
            }

            break;
        case "join":
            var playerID = splitData[0];
            var lobbyID  = splitData[1];

            if (lobbyID in lobbyDict) {
                const lobby = lobbyDict[lobbyID];
                const IP    = lobby.IP;
                const port  = lobby.port;

                messageQueue.push("join:" + playerID + "_" + lobbyID + "_" + IP + "_" + port + "_\n");
                console.log("player: " + playerID + " to join lobby: " + lobbyID );
            }
            else {
                console.log("unable to join lobby: " + lobbyID);
            }

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
        socket.write("\n");
        
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
const net = require('net');

let lobbyDict = {};

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

function isLobby(ID) {
    return ID in lobbyDict;
}

//Split string by a separator into a table
function split(string, sep) {
    let found = false;
    let out = [];
    let tmp = "";
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

let messageQueue = [];

// Converts the command into a function to execute
function netSwitch(message) {
    const splitCommand = split(message,":");
    if (splitCommand  == 0) { return }
    const command      = splitCommand[0];
    const args         = splitCommand[1];
    const splitData    = split(args,"_")
    
    // Commands that will be received: 
    // updt (changing player counts),
    // econ (cleanly exit a player),
    // create (create a new lobby object),
    // join (send data to join a server),
    // clse (cleanly delete a lobby object)
    switch (command) {
        //using {} with 'let' to keep variables local to each case
        case "updt": {
            const lobbyID = splitData[0];
            if (!isLobby(lobbyID)) {
                console.log("invalid lobby name");
                break;
            }

            const field   = splitData[1];
            const value   = splitData[2];
            console.log("updated: " + field + " to " + value + " in " + lobbyID)
            break;
        }
        case "econ": {
            const playerID = splitData[0];
            console.log("end connection: " + playerID);
            break;
        }
        case "create": {
            const lobbyID = splitData[0];

            if (isLobby(lobbyID)) {
                console.log("lobby: " + lobbyID + " already exists");
                break;
            }

            const name        = splitData[1];
            const hostName    = splitData[2];
            const playerCount = splitData[3];
            const maxPlayers  = splitData[4];
            const IP          = splitData[5];
            const port        = splitData[6];
            const playerID    = splitData[7];

            const nLobby = new Lobby(lobbyID,name,hostName,playerCount,maxPlayers,IP,port);
            lobbyDict[lobbyID] = nLobby;
            console.log("create new lobby: " + lobbyID);
            messageQueue.push("create:" + playerID + "_" + lobbyID + "\n");

        break;
    }
    case "join": {
        const lobbyID  = splitData[1];

        if (!isLobby(lobbyID)) {
            console.log("unable to join lobby: " + lobbyID);
            break;
        }

        const playerID = splitData[0];
        const lobby = lobbyDict[lobbyID];
        const IP    = lobby.IP;
        const port  = lobby.port;

        messageQueue.push("join:" + playerID + "_" + lobbyID + "_" + IP + "_" + port + "_\n");
        console.log("player: " + playerID + " to join lobby: " + lobbyID );

        break;
    }
        case "clse": {
            const lobbyID = splitData[0];
            if (!isLobby(lobbyID)) {
                console.log("invalid lobby name");
                break;
            }
            console.log("closing lobby: " + lobbyID)
            break;
        }
        default:
            console.log("unknown command")
    }
}

const server = net.createServer((socket) => {
    console.log('Client connected');

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

    socket.on("error", (error) => {
        if (error.code == "ECONNRESET") {
            console.log("client closed unexpectedly");
        }
    })
});

const PORT = 500;
const HOST = '127.0.0.1';

server.listen(PORT, HOST, () => {
    console.log(`Server listening on ${HOST}:${PORT}`);
});
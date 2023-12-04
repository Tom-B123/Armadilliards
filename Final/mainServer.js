const net = require("net");

let lobbyIDs  = [];
let lobbyDict = {};

class Lobby {
    constructor(ID, name, hostName, playerCount, maxPlayers, IP, port) {
        this.ID          = ID
        this.name        = name;
        this.hostName    = hostName;
        this.playerCount = playerCount;
        this.maxPlayers   = maxPlayers;
        this.IP          = IP;
        this.port        = port;
    }

    // Gets info as a csv string
    getInfo() {
        let msg = "uplobs:"
        msg += this.ID + "_";
        msg += this.name + "_";
        msg += this.hostName + "_";
        msg += this.IP + "_";
        msg += this.port + "_";
        msg += this.playerCount + "_";
        msg += this.maxPlayers + "_\n";
        return msg;
    }

    setName(name)               {this.name = name;}
    setHostName(hostName)       {this.hostName = hostName;}
    setPlayerCount(playerCount) {this.playerCount = playerCount;}
    setMaxPlayers(maxPlayers)   {this.maxPlayers = maxPlayers;}
    setIP(IP)                   {this.IP = IP;}
    setPort(port)               {this.port = port;}
}

function isLobby(ID) {
    return ID in lobbyDict;
}

// Lua uplobs message
//server:send("all","uplobs:"..ID.."_"..name.."_"..hostName.."_"..IP.."_"..port.."_"..ID.."_"..playerCount.."_"..maxPlayers)
function getUplobs() {
    for (const ID of lobbyIDs) {
        const lobby = lobbyDict[ID];
        const msg = lobby.getInfo();
        updateQueue.push(msg);
    }
   
}

//Split string by a separator into a table
function split(string, sep) {
    let found = false;
    let out   = [];
    let tmp   = "";
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
let updateQueue = [];

function updateLobby(ID,field,value) {
    if (!isLobby(ID)) { return; }

    let lobby = lobbyDict[ID];
    switch (field) {
        case "name":
            lobby.setName(value);
            break;

        case "host name":
            lobby.setHostName(value);
            break;

        case "player count":
            lobby.setPlayerCount(value);
            break;

        case "max players":
            lobby.setMaxPlayers(value);
            break;

        case "IP":
            lobby.setIP(value);
            break;

        case "port":
            lobby.setPort(value);
            break;
            
        default:
            console.log("invalid field");
    }
}

// Converts the command into a function to execute
function netSwitch(message,client) {
    const splitCommand = split(message,":");
    if (splitCommand  == 0) { return; }
    const command      = splitCommand[0];
    const args         = splitCommand[1];
    const splitData    = split(args,"_");
    
    // Using {} with 'let' / 'const' to keep variables local to each case
    // Commands that will be received: 
    //     updt (changing player counts),
    //     econ (cleanly exit a player),
    //     create (create a new lobby object),
    //     join (send data to join a server),
    //     clse (cleanly delete a lobby object)

    switch (command) {
        case "updt": {
            const lobbyID = splitData[0];
            if (!isLobby(lobbyID)) {
                console.log("invalid lobby name");
                break;
            }

            const field = splitData[1];
            const value = splitData[2];

            console.log("updated: " + field + " to " + value + " in " + lobbyID);

            updateLobby(lobbyID,field,value);

            break;
        }

        case "econ": {
            const playerID = splitData[0];
            send([client],"econ:" + playerID);
            // remove playerID from player IDs
            closeClient(client);
            break;
        }

        case "create": {
            const lobbyID = splitData[0];

            if (isLobby(lobbyID)) {
                console.log("lobby: " + lobbyID + " already exists");
                break;
            }

            const lobbyName  = splitData[1];
            const hostID     = splitData[2]
            const hostName   = splitData[3];
            const IP         = splitData[4];
            const port       = splitData[5];
            const maxPlayers = splitData[6];

            const nLobby = new Lobby(lobbyID,lobbyName,hostName,0,maxPlayers,IP,port);
            lobbyDict[lobbyID] = nLobby;
            lobbyIDs.push(lobbyID);
            console.log("create new lobby: " + lobbyID);
            messageQueue.push("create:" + hostID + "_" + lobbyID + "_" + lobbyName + "_" + IP + "_" + port + "_" + maxPlayers + "_" + "\n");
        break;
    }

    case "join": {
        const lobbyID  = splitData[1];

        if (!isLobby(lobbyID)) {
            console.log("unable to join lobby: " + lobbyID);
            break;
        }

        const playerID = splitData[0];
        const lobby    = lobbyDict[lobbyID];
        const IP       = lobby.IP;
        const port     = lobby.port;

        messageQueue.push("join:" + playerID + "_" + IP + "_" + port + "_\n");
        console.log("player: " + playerID + " to join lobby: " + lobbyID );

        break;
    }

    case "clse": {
        const lobbyID = splitData[0];
        if (!isLobby(lobbyID)) {
            console.log("invalid lobby name");
            break;
        }
        console.log("closing lobby: " + lobbyID);
        break;
    }
    default:
        console.log("unknown command")
    }
}

const clients = new Set();

function send(clientsToReceive,msg) {
    if (clientsToReceive == "all") {
        clientsToReceive = clients
    }
    for (const client of clientsToReceive) {
        client.write(msg);
    }
}

function closeClient(socket) {
    socket.end();
    clients.delete(socket);
}

const server = net.createServer((socket) => {
    console.log("Client connected");

    clients.add(socket);

    socket.on("update lobbies", () => {
        for (i in updateQueue) {
            const msg = updateQueue[i];
            socket.write(msg);
        }
        updateQueue = [];
    })

    socket.on("data", (data) => {
        messageQueue = []

        const message = data.toString();
        if (message) {
            netSwitch(message,socket);
        }
        // process commands sent by clients
        for (const message of messageQueue) {
            send("all",message);
        }
        // sending update messages
        for (const message of updateQueue) {
            send("all",message);
        }
        if (updateQueue) {
            updateQueue = [];
        }
        send("all","no dat\n");
    });

    socket.on("end", () => {
        console.log("Client disconnected");
        clients.delete(socket)
    });

    socket.on("error", (error) => {
        if (error.code == "ECONNRESET") {
            console.log("client closed unexpectedly");
            clients.delete(socket)
        }
    })
});

const PORT = 500;
const HOST = "127.0.0.1";

server.listen(PORT, HOST, () => {
    console.log(`Server listening on ${HOST}:${PORT}`);
});

function update() {
    getUplobs();
}

setInterval(update,1000);
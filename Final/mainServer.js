const net      = require("net");

let lobbyIDs  = [];
let lobbyDict = {};
let portDict  = {};

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

//Remove a lobby from dict and list
function removeLobby(ID) {
    let ind = -1;
    for (i in lobbyIDs) {
        const lobbyID = lobbyIDs[i];
        if (lobbyID == ID) {
            ind = i;
        }
    }
    if (ind > -1) {
        delete lobbyDict[ID];
        if (lobbyIDs.length <= 1) {
            lobbyIDs = [];
        }
        lobbyIDs.splice(ind, 1); 
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

//Update lobby based on the fiven field and value
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
            console.log(message);
            const lobbyID = splitData[0];
            // remove playerID from player ID

            console.log(lobbyID);
            if (lobbyID) {
                console.log("client was hosting lobby: " + lobbyID);
                netSwitch("clse:" + lobbyID + "_\n",client)
                delete hostDict[client];
            }
            if (client) { closeClient(client);} 

            console.log("Client disconnected. Current count: " + clients.size);
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
            let   port       = splitData[5];
            const maxPlayers = splitData[6];

            // If that IP already uses a port, use the next available port
            if (IP in portDict) {
                const ports = portDict[IP];
                port       += ports.length;
            }

            else { portDict[IP] = []; }
            portDict[IP].push(port);

            const nLobby       = new Lobby(lobbyID,lobbyName,hostName,0,maxPlayers,IP,port);
            lobbyDict[lobbyID] = nLobby;
            lobbyIDs.push(lobbyID);
            console.log("create new lobby: " + lobbyID);

            //Store the lobbyID for unexpected closure of the client's connection
            hostDict[client]   = lobbyID

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
        removeLobby(lobbyID);
        messageQueue.push("clse:" + lobbyID + "_\n");
        break;
    }
    default:
        console.log("unknown command");
    }
}

const clients  = new Set();
let   hostDict = {};

function send(clientsToReceive,msg) {
    if (clientsToReceive == "all") {
        clientsToReceive = clients;
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

    socket.setTimeout(0);

    clients.add(socket);

    console.log("Client connected. Current count: " + clients.size);

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
        console.log("Client disconnected. Current count: " + clients.size);
        clients.delete(socket);
    });

    socket.on("error", (error) => {
        if (error.code == "ECONNRESET") {
            console.log("client closed unexpectedly");
            const lobbyID = hostDict[socket];
            //If the player is a host, perform additional logic
            if (lobbyID) { netSwitch("econ:" + lobbyID + "_\n",socket); }

            //Else, close the player's socket object
            else {
                clients.delete(socket);
                console.log("Client disconnected. Current count: " + clients.size);
                closeClient(socket);
            }
        }
    });
});

const PORT = 500;
const HOST = "0.0.0.0";

server.listen(PORT, HOST, () => {
    console.log(`Server listening on ${HOST}:${PORT}`);
});

function update() {
    getUplobs();
}

setInterval(update,1000);
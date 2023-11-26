Socket = require("socket")

--splits a string by the seperator into a table of substrings
local function split (inputstr, sep)
    if sep == nil then
        sep = "%s"
    end
    local t={}
    for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
        table.insert(t, str)
    end
    return t
end

--gets an ID of a length, using the os.time as a seed
local function calculateID(length)
    local seed = Socket.gettime() * 10000
    math.randomseed(seed)
    return tostring(math.random(0,10^length - 1))
end

--500 = main port, 1000+ = lobby ports
local mainIP = Socket.dns.toip(Socket.dns.gethostname( ))
local mainPort = 500

--Server class, handles connections from clients and sending / receiving data
Server = {}
Server.__index = Server

function Server:new(port)
    local object = {}
    setmetatable(object,Server)
    object.server = assert(Socket.bind("*",port))
    object.server:settimeout(0)
    object.clients = {}
    return object
end

function Server:update()
    local nClient = self.server:accept()
    if nClient then
        nClient:settimeout(0)
        table.insert(self.clients, nClient)
    end
end

function Server:send(clients,message)
    if clients == "all" then clients = self.clients end
    for i,client in ipairs(clients) do
        client:send(message.."\n")
    end
end

function Server:receive(clients)
    if clients == "all" then clients = self.clients end
    local out = {}
    -- local newPlayerIDs = {}
    for i,client in ipairs(clients) do
        local data,err = client:receive()
        if data then
            table.insert(out, data)
            --uses a substring for less performance impact of splitting every single incoming message
            -- if string.sub(data,1,4) == "ncon" then
            --     local splitData = split(data,":")
            --     local ID = splitData[2]
            --     table.insert(newPlayerIDs, {client,ID})
            -- end
        elseif err == "closed" then
            client:close()
            table.remove(clients, i)
        end
    end
    return out
end

function Server:close()
    self.server:close()
end

--Client class, handles connecting to servers and sending / receiving data
Client = {}
Client.__index = Client

function Client:new(IP,port)
    local object = {}
    setmetatable(object,Client)
    local client = assert(Socket.connect(IP, port))
    client:settimeout(0)
    object.client = client
    object.IP = IP
    object.port = port
    return object
end

function Client:send(message)
    self.client:send(message .. "\n")
end

function Client:receive()
    local data, err = self.client:receive()
    if data then
        return data
    elseif err == "closed" then
        self.client:close()
    end
end

function Client:close()
    self.client:close()
end

--Lobby class, adds to the server class with more functionality
Lobby = {}
Lobby.__index = Lobby

function Lobby:new(name,port,IP,hostName,maxPlayers)
    local object = {}
    setmetatable(object,Lobby)
    object.name = name
    object.port = port
    object.IP = IP
    object.hostName = hostName

    object.playerCount = 0
    object.maxPlayers = maxPlayers
    object.clients = {}
    object.playersDict = {}

    object.server = Server:new(port)

    return object
end

function Lobby:endConnection(ID)
    local clientToRemove = self.playersDict[ID]
    local ind = 0
    for i, client in ipairs(self.clients) do
        if client == clientToRemove then ind = i end
    end
    if ind then
        table.remove(self.clients,ind)
        self.playersDict[ID] = nil
    end
end

function Lobby:hostMain()
    local nLobby = Lobby:new("__main lobby__", mainPort, mainIP,"main host",-1)
    return nLobby
end

function Lobby:send(clients,message)
    self.server:send(clients,message)
end

function Lobby:receive(clients)
    local data = self.server:receive(clients)
    return data
    -- for i,clientPair in ipairs(newClients) do
    --     local client,ID = clientPair[1],clientPair[2]
    --     self.playersDict[ID] = client
    -- end
    
end

function Lobby:update()
    self.server:update()
    self.playerCount = #self.server.clients
end

function Lobby:close()
    self.server:close()
end


function Lobby:create(client,name,port,IP,hostName)
    --create a new inactive lobby object
    --send back to client
end

--Player class, adds to the server class with more functionality
Player = {}
Player.__index = Player

function Player:new(IP,port)
    local object = {}
    setmetatable(object,Player)
    object.name = "new player"
    object.ID = ""
    object.IP = Socket.dns.toip(Socket.dns.gethostname( ))
    object.ready = false
    object.team = "team 1"
    if IP and port then object.client = Client:new(IP,port)
    else object.client = Client:new(mainIP,mainPort) end
    return object
end

function Player:send(message)
    self.client:send(message)
end

function Player:receive()
    return self.client:receive()
end

function Player:close()
    self.client:close()
end

function Player:connectToMain()
    --Send messages before closing
    self:close()
    self.client = Client:new(mainPort,mainIP)
end

function Player:join(lobbyID)
    self:send("join:"..self.ID.."_"..lobbyID)
end

function Player:create(lobby)
    --sends data to server for making a lobby
    self:send("create:"..lobby.."_"..self.IP.."_"..self.name)
end

function Player:tryConnect()
    local function nClient()
        return self:new()
    end
    local success,client = pcall(nClient)
    if success then
        print("successfully connected to main server")
        return client
    else
        print("error connecting to main server")
        return false
    end
end

--LobbyPlayer table, uses the player ID to get other player data
LobbyPlayer = {
    IDTable = {},
    nameDict = {},
    readyDict = {},
    teamDict = {}
}

function LobbyPlayer:new(ID)
    table.insert(self.IDTable,ID)
end

function LobbyPlayer:getIDs()
    return self.IDTable
end

function LobbyPlayer:removeID(ID)
    --remove all values attributed to that ID
end

function LobbyPlayer:getName(ID)
    --returns the player name, or nil
    local name = self.nameDict[ID]
    return name
end

function LobbyPlayer:setName(ID,name)
   self.nameDict[ID] = name
end

function LobbyPlayer:getTeam(ID)
    --returns the player name, or nil
    local team = self.teamDict[ID]
    return team
end

function LobbyPlayer:setTeam(ID,team)
    self.teamDict[ID] = team
end

function LobbyPlayer:getReady(ID)
    --returns the player name, or nil
    local isReady = self.readyDict[ID]
    return isReady
end

function LobbyPlayer:setReady(ID,ready)
    self.readyDict[ID] = ready
end

--Joinable lobby table, gets lobby data via the lobby ID
JoinableLobby = {
    IDTable = {},
    nameDict = {},
    playerCountDict = {},
    maxPlayersDict = {},
    IPDict = {},
    portDict = {},
    hostIDDict = {}
}

function JoinableLobby:new(ID)
    if not ID then ID = calculateID(6) end
    table.insert(self.IDTable,ID)
    return ID
end

function JoinableLobby:clear()
    self.IDTable = {}
    self.nameDict = {}
    self.playerCountDict = {}
    self.maxPlayersDict = {}
    self.IPDict = {}
    self.portDict = {}
    self.hostIDDict = {}
end

function JoinableLobby:getAll(ID)
    return  self:getName(ID), self:getHostID(ID), self:getIP(ID),
            self:getPort(ID), self:getPlayerCount(ID), self:getMaxPlayers(ID)
end

function JoinableLobby:getName(ID)
    return self.nameDict[ID]
end

function JoinableLobby:setName(ID,name)
    self.nameDict[ID] = name
end

function JoinableLobby:getHostID(ID)
    return self.hostIDDict[ID]
end

function JoinableLobby:setHostID(ID,hostID)
    self.hostIDDict[ID] = hostID
end

function JoinableLobby:getIP(ID)
    return self.IPDict[ID]
end

function JoinableLobby:setIP(ID,IP)
    self.IPDict[ID] = IP
end

function JoinableLobby:getPort(ID)
    return self.portDict[ID]
end

function JoinableLobby:setPort(ID,port)
    self.portDict[ID] = port
end

function JoinableLobby:getPlayerCount(ID)
    return self.playerCountDict[ID]
end

function JoinableLobby:setPlayerCount(ID,playerCount)
    self.playerCountDict[ID] = playerCount
end

function JoinableLobby:getMaxPlayers(ID)
    return self.maxPlayersDict[ID]
end

function JoinableLobby:setMaxPlayers(ID,maxPlayers)
    self.maxPlayersDict[ID] = maxPlayers
end

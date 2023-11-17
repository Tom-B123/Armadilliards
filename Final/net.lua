Socket = require("socket")

Server = {}
Server.__index = Server

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

local mainIp = Socket.dns.toip(Socket.dns.gethostname( )) 
local mainPort = 500

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
    local newPlayerIDs = {}
    for i,client in ipairs(clients) do
        local data,err = client:receive()
        if data then
            out[i] = data
            --uses a substring for less performance impact of splitting every single incoming message
            if string.sub(data,1,4) == "ncon" then
                print("server found new connection")
                local splitData = split(data,":")
                local id = splitData[2]
                table.insert(newPlayerIDs, {client,id})
            end
        elseif err == "closed" then
            client:close()
            table.remove(clients, i)
        end
    end
    return out, newPlayerIDs
end

function Server:close()
    self.server:close()
end

Client = {}
Client.__index = Client

function Client:new(port, ip)
    local object = {}
    setmetatable(object,Client)
    local client = assert(Socket.connect(ip, port))
    client:settimeout(0)
    object.client = client
    object.ip = ip
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

Lobby = {}
Lobby.__index = Lobby

function Lobby:new(name,port,ip,hostName)
    local object = {}
    setmetatable(object,Lobby)
    object.name = name
    object.port = port
    object.ip = ip
    object.hostName = hostName

    object.playerCount = 0
    object.clients = {}
    object.playersDict = {}

    object.server = Server:new(port)

    return object
end

function Lobby:endConnection(id)
    --remove player from connected players table
end

function Lobby:hostMain()
    local nLobby = Lobby:new("__main lobby__", mainPort, mainIp,"main host")
    return nLobby
end

function Lobby:send(clients,message)
    self.server:send(clients,message)
end

function Lobby:receive(clients)
    local data, newClients = self.server:receive(clients)
    for i,clientPair in ipairs(newClients) do
        local client,id = clientPair[1],clientPair[2]
        self.playersDict[id] = client
    end
    return data
end

function Lobby:update()
    self.server:update()
    self.playerCount = #self.server.clients
end

function Lobby:close()
    self.server:close()
end

function Lobby:join(client,name)
    --get the lobby of valid
    --send the lobby to the client
    --increment player count
end

function Lobby:create(client,name,port,ip,hostName)
    --create a new inactive lobby object
    --send back to client
end

Player = {}
Player.__index = Player

function Player:new()
    local object = {}
    setmetatable(object,Player)
    object.name = "new player"
    object.id = ""
    object.ip = Socket.dns.toip(Socket.dns.gethostname( ))
    object.client = Client:new(mainPort,mainIp)
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
    self.client = Client:new(mainPort,mainIp)
end

function Player:join(lobby)
    --sends data to server for joining a lobby
    self:send("join:"..lobby)
end

function Player:create(lobby)
    --sends data to server for making a lobby
    self:send("create:"..lobby.."_"..self.ip.."_"..self.name)
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

LobbyPlayer = {
    IDTable = {},
    NameDict = {},
    ReadyDict = {},
    TeamDict = {}
}

function LobbyPlayer:new(id)
    table.insert(self.IDTable,id)
end

function LobbyPlayer:getIDs()
    return self.IDTable
end

function LobbyPlayer:removeID(id)
    --remove all values attributed to that ID
end

function LobbyPlayer:getName(id)
    --returns the player name, or nil
    local name = self.NameDict[id]
    return name
end

function LobbyPlayer:setName(id,name)
   self.NameDict[id] = name
end

function LobbyPlayer:getTeam(id)
    --returns the player name, or nil
    local team = self.TeamDict[id]
    return team
end

function LobbyPlayer:setTeam(id,team)
    self.TeamDict[id] = team
end

function LobbyPlayer:getReady(id)
    --returns the player name, or nil
    local isReady = self.ReadyDict[id]
    return isReady
end

function LobbyPlayer:setReady(id,ready)
    self.ReadyDict[id] = ready
end


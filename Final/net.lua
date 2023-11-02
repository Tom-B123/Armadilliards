local socket = require("socket")
Server = {}
Server.__index = Server

local mainIp = socket.dns.toip(socket.dns.gethostname( )) 
local mainPort = 1000

function Server:new(port)
    local object = {}
    setmetatable(object,Server)
    object.server = assert(socket.bind("*",port))
    object.clients = {}
    return object
end

function Server:update()
    local nClient = self.server:accept()
    if nClient then
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
    for i,client in ipairs(clients) do
        local data,err = client:receive()
        if data then out[i] = data
        elseif err == "closed" then
            client:close()
            table.remove(clients, i)
        end
    end
    return out
end

Client = {}
Client.__index = Server

function Client:new(port, ip)
    local object = {}
    setmetatable(object,Client)
    object.client = assert(socket.connect(ip, port))
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

Lobby = {}
Lobby.__index = Server

function Lobby:new(name,port,ip,hostName,isActive,maxPlayers)
    local object = {}
    setmetatable(object,Lobby)
    object.name = name
    object.port = port
    object.ip = ip
    object.hostName = hostName
    object.isActive = isActive
    object.playerCount = 1
    if maxPlayers < 2 then maxPlayers = 2
    elseif maxPlayers > 8 then maxPlayers = 8 end
    object.maxPlayers = maxPlayers
    if isActive then
        object.server = Server:new(port)
    else
        --Add to lobbies table
    end
    return object
end

function Lobby:send(clients,message)
    self.server:send(clients,message)
end

function Lobby:receive(clients)
    self.server:receive(clients)
end

function Lobby:update()
    self.server:update()
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
Player.__index = Server

function Player:new(name)
    local object = {}
    setmetatable(object,Player)
    object.name = name
    object.client = Client:new(mainPort,mainIp)
    return object
end

function Player:connectToMain()
    --connect to the main lobby
end

function Player:getInfo()
    --return name,port,ip,player name
end

function Player:join(lobby)
    --requests server to join the lobby
end

function Player:create(lobby)
    --requests server to become a host of a new lobby.
end

function Player:tryConnect()
    local function nClient()
        return self:new("new player")
    end
    local nPlayer = pcall(nClient)
    if nPlayer == nil then
        print("error connecting to server")
        return false
    end
    return nPlayer
end
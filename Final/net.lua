local socket = require("socket")
Server = {}
Server.__index = Server

local mainIp = socket.dns.toip(socket.dns.gethostname( )) 
local mainPort = 500

function Server:new(port)
    local object = {}
    setmetatable(object,Server)
    object.server = assert(socket.bind("*",port))
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
    for i,client in ipairs(clients) do
        local data,err = client:receive()
        if data then out[i] = data
        elseif err == "closed" then
            client:close()
            table.remove(clients, i)
            print(#self.clients)
        end
    end
    return out
end

function Server:close()
    self.server:close()
end

Client = {}
Client.__index = Client

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

function Client:close()
    self.client:close()
end

Lobby = {}
Lobby.__index = Lobby

function Lobby:new(name,port,ip,hostName,isActive,maxPlayers)
    local object = {}
    setmetatable(object,Lobby)
    object.name = name
    object.port = port
    object.ip = ip
    object.hostName = hostName
    object.isActive = isActive
    object.playerCount = 1
    object.clients = {}
    if maxPlayers > 8 then maxPlayers = 8 
    elseif maxPlayers == -1 then 
        maxPlayers = 10^6 
        object.playerCount = 0
    end
    
    object.maxPlayers = maxPlayers
    if isActive then
        object.server = Server:new(port)
    else
        --Add to lobbies table
    end
    return object
end


function Lobby:hostMain()
    local nLobby = Lobby:new("__main lobby__", mainPort, mainIp,"main host",true,-1)
    return nLobby
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

function Player:new(name)
    local object = {}
    setmetatable(object,Player)
    object.name = name
    object.ip = socket.dns.toip(socket.dns.gethostname( ))
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
        return self:new("new player")
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
local socket = require("socket")

Lobby = {}

Lobby.__index = Lobby

--Create a new lobby
function Lobby:new(name,port)
    local object = {}
    setmetatable(Lobby,object)
    object.name = name
    object.clients = {}
    object.server = assert(socket.bind("*",port))
    return object
end

--Update connections coming into a lobby.
function Lobby:updateConnections()
    local newClient = self.server:accept()
    if newClient then
        table.insert(self.clients,newClient)
    end
end

--Send to clients connected to a lobby.
function Lobby:sendToClient(client)
    if client == "all" then
        for i,clientToSend in ipairs(self.clients) do
            clientToSend:send(tostring(i).."\n")
        end
    end
end

--Receive from all clients of a lobby.
function Lobby:receiveFromClient()
    local dataOut = {}
    for i,clientToReceive in ipairs(self.clients) do
        local data,err = clientToReceive:receive()
        if data then dataOut[i] = data
        elseif err == "closed" then
            clientToReceive:close()
            table.remove(self.clients,i)
        end
    end
    return dataOut
end

--The server that online players attempt to connect to.
local MainLobby = {server = assert(socket.bind("*",500))}

MainLobby.server:settimeout(0)
--A list of all online players.
local players = {}
--A list of all active lobby servers. 
--Displayed to the clients in the players list.
local lobbies = {}

lobbies[1] = Lobby:new("my lobby",1000)

function love.keypressed(key)
	if key == "escape" then
	  love.event.quit()
	end
end


--Updates the players list of connected clients.
function MainLobby:updateConnections()
    local newClient = self.server:accept()
    if newClient then
        table.insert(players,newClient)
    end
end

--Sends data to clients
function MainLobby:sendToClient(client)
    if client == "all" then
        for i,clientToSend in ipairs(players) do
            clientToSend:send(tostring(i).."\n")
        end
    end
end


--receives data from all clients
function MainLobby:receiveFromClient()
    local dataOut = {}
    for i,clientToReceive in ipairs(players) do
        local data,err = clientToReceive:receive()
        if data then dataOut[i] = data
        elseif err == "closed" then
            clientToReceive:close()
            table.remove(players,i)
        end
    end
    return dataOut
end

function love.load()
end

function love.update()
    MainLobby:updateConnections()
    MainLobby:sendToClient("all")
end

function love.draw()
    local data = MainLobby:receiveFromClient()
    if data then
        for i, message in ipairs(data) do
            love.graphics.print(message,0,i*15)
        end
    end
end
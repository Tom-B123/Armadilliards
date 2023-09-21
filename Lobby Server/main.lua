local socket = require("socket")

Lobby = {}

Lobby.__index = Lobby

--Create a new lobby
function Lobby:new(name,port)
    local object = {}
    setmetatable(object,Lobby)
    object.name = name
    object.clients = {}
    object.server = assert(socket.bind("*",port))
    object.server:settimeout(0)
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
            clientToSend:send(self.name..":"..tostring(i).."\n")
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



--A list of all online players.
local players = {}
--A list of all active lobby servers,
--Displayed to the clients in the players list.
local lobbies = {}
--The server that online players attempt to connect to.
lobbies[1] = Lobby:new("Main Lobby",500)

lobbies[2] = Lobby:new("my lobby",1000)

function love.keypressed(key)
	if key == "escape" then
	  love.event.quit()
	end
end

function love.load()
end

function love.update()
    for i, lobby in ipairs(lobbies) do
        lobby:updateConnections()
        lobby:sendToClient("all")
    end
end

function love.draw()
    for x, lobby in ipairs(lobbies) do
        local data = lobby:receiveFromClient()
        if data then
            for y, message in ipairs(data) do
                love.graphics.print(message,x*50,y*20)
            end
        end
    end
end
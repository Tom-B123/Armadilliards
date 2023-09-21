local socket = require("socket")
--The server that online players attempt to connect to.
local MainLobby = {server = assert(socket.bind("*",500))}

MainLobby.server:settimeout(0)
--A list of all online players.
local players = {}
--A list of all active lobby servers. 
--Displayed to the clients in the players list.
local lobbies = {}

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
            clientToSend:send("you are client number _"..i.."\n")
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
            love.graphics.print(message)
        end
    end
end
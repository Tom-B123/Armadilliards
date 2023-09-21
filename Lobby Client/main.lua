local socket = require("socket")
--The client of players, that will be connected to lobbies.
local client = assert(socket.connect("localhost",500))
--The identifier of the client
local clientID = nil
--the last message recieved.
local serverMessage = ""

client:settimeout(0)

--Send message to server
local function sendToServer(data)
    client:send(data .. "\n")
end

--Read message from server
local function receiveFromServer()
    local data, err = client:receive()
    if data then
        return data
    elseif err == "closed" then
        client:close()
    end
end


function love.update()
    
    serverMessage = receiveFromServer()
    clientID = "1"
    if clientID then 
        sendToServer("hello server, I am the client number "..clientID)
    end
end


function love.draw()
    local data = serverMessage
    if data then love.graphics.print(data) end
end
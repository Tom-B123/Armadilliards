local socket = require("socket")
--The client of players, that will be connected to lobbies.
local client = assert(socket.connect("localhost",500))
--The identifier of the client
local clientID = nil
--the last message recieved.
local serverMessage = ""

client:settimeout(0)

function love.keypressed(key)
	if key == "escape" then
	  love.event.quit()
	end
end

function love.quit()
    -- Cleanup when quitting the application
    client:close()
end

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
    if serverMessage then clientID = serverMessage
    else clientID = "0" end
    
    if clientID then 
        sendToServer("hello server, I am the client number "..clientID)
    end
end


function love.draw()
    local data = serverMessage
    if data then love.graphics.print(data) end
end
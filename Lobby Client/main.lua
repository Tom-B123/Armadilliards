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
    client:close()
end

--split strings by a separator
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
    if serverMessage then 
        local splitMessage = split(serverMessage,":")
        clientID = splitMessage[2]
    else clientID = "0" end
    
    if clientID then 
        sendToServer("client:"..clientID)
    end
end


function love.draw()
    local data = serverMessage
    if data then love.graphics.print(data) end
end
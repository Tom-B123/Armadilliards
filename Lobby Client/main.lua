local socket = require("socket")

local client = assert(socket.connect("localhost",500))

client:settimeout(0)

local function sendToServer(data)
    client:send(data .. "\n")
end

local function receiveFromServer()
    
    local data, err = client:receive()
    if data then
        return data
    elseif err == "closed" then
        client:close()
    end
end

function love.update()
end

function love.draw()
    local data = receiveFromServer()
    love.graphics.print(data)
end
Socket = require("socket")

local mainIP = "127.0.0.1"
local mainPort = 500

local client = assert(Socket.connect(mainIP,mainPort))

local msg = ""

function love.update()
    client:send("hello!")
    local data,err = client:receive()
    if data then msg = data end
end

function love.draw()
    love.graphics.print(msg)
end
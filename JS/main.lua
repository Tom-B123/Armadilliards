Socket = require("socket")

local mainIP = "127.0.0.1"
local mainPort = 500

local client = assert(Socket.connect(mainIP,mainPort))



function love.update()
    client:send("hello!")
end

function love.draw()
end
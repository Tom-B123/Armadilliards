local socket = require("socket")
--The server that hosting players attempt to connect to
local clientServer = assert(socket.bind("*",500))

clientServer:settimeout(0)
--A list of all hosting players.
local hosts = {}

function love.load()
end
function love.update()
end
function love.draw()
end
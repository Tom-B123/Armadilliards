Socket = require("socket")

--Returns a psudo-random string of numbers, with set length
local function calculateID(length,salt)
    local seed = Socket.gettime() * 10000
    if salt then seed = seed + salt end
    math.randomseed(seed)
    local out = tostring(math.random(0,10^length - 1))
    while #out < length do
        out = "0"..out
    end
    return out
end

local ID = calculateID(6)

local mainIP = "127.0.0.1"
local mainPort = 500

local client = assert(Socket.connect(mainIP,mainPort))

local msg = ""

function love.update()
    client:send("ncon:ID")
    local data,err = client:receive()
    if data then msg = data end
end

function love.draw()
    love.graphics.print(msg)
end

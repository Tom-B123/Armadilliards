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

local messages = {}

local function process(data)
    if data then table.insert(messages,data) end
end

function love.update()
    messages = {}
    client:send("ncon:ID")
    local data,err = client:receive()
    while data do
        process(data)
        data,err = client:receive()
    end
    if data then msg = data end
end

function love.draw()
    for i,message in ipairs(messages) do
        love.graphics.print(message,0,i*20)
    end
end

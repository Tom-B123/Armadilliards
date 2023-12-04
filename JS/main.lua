--Ctrl + alt + L activates run on save!!!!!
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

local ID = calculateID(8,1)
local name = "new player"

local lobbyID = calculateID(6,2)

local IP = Socket.dns.toip(Socket.dns.gethostname( ))
local mainIP = "127.0.0.1"
local mainPort = 500

local client = assert(Socket.connect(mainIP,mainPort))

local messages = {}

local function process(data)
    if data and data ~= "no dat" then table.insert(messages,data) end
end

function love.keypressed(key)
    if key == "c" then client:send("create:"..lobbyID.."_".."new lobby".."_"..name.."_"..(0).."_"..(8).."_"..IP.."_"..(1000).."_") end
    if key == "j" then client:send("join:"..ID.."_"..lobbyID.."_") end
end

function love.update()
    messages = {}
    client:send("\n")

    local data,err = client:receive()
    if data then process(data) end
end

function love.draw()
    love.graphics.print("hosting: "..lobbyID.."_".."new lobby".."_"..name.."_"..(0).."_"..(8).."_"..IP.."_"..(1000))
    for i,message in ipairs(messages) do
        love.graphics.print(message,0,i*20)
    end
end

local socket = require("socket")
-- require("button")

local client
local server = nil

local message = ""

math.randomseed(os.clock())
local playerName = math.random(1,1000)

local players = {}
local playersDict = {}

local messageLog = {}

local lState
local state = "browsing"

function players:new(name)
    local object = {}
    object.name = name
    object.team = "team 1"
    object.ready = "not ready"
    playersDict[name] = object
    table.insert(players,object)
end

local function sendToServer(data)
    client:send(data .. "\n")
end

--Reads message from server
local function receiveFromServer()
    local data, err = client:receive()
    if data then
        return data
    elseif err == "closed" then
        client:close()
    end
end

local function attemptToConnect()
    client = assert(socket.connect("localhost",1000))
end

if pcall(attemptToConnect) then
    message = "successfully connected"
else
    message = "timed out"
end
function love.keypressed(key)
    if key == "escape" then
        love.event.quit()
    end
end

function love.update()
end

function love.draw()
    love.graphics.print(message)
end
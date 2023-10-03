local socket = require("socket")
-- require("button")

local client
local server = nil

local clients = {}

local message = {}

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

local function sendToClient(client,data)
    if client == "all" then
        for i,clientToSend in ipairs(clients) do
            clientToSend:send(data.."\n")
        end
    else
        if data then client:send(data.."\n") end
    end
end

local function receiveFromClients()
    local out = {}
    for i,client in ipairs(clients) do
        local data,err = client:receive()
        table.insert(out,data)
        if err == "closed" then
            client:close()
            table.remove(clients,i)
        end
    end
    return out
end

local function updateConnections()
    if server == nil then return end
    local newClient = server:accept()
    if newClient then
        table.insert(clients,newClient)
    end
end

local function attemptToConnect()
    client = assert(socket.connect("localhost",1000))
end

if pcall(attemptToConnect) then
    --if there is a server:
    client:settimeout(0)
    message = {"I am a client"}
else
    --else, host one
    server = assert(socket.bind("*",1000))
    server:settimeout(0)
    message = {"I am a server"}
end

function love.keypressed(key)
    if key == "escape" then
        love.event.quit()
    end
end

function love.update()
    message = {"msg1","msg2"}
    if client then 
        sendToServer("plyr:"..playerName)
        message = {receiveFromServer()}
    elseif server then
        updateConnections()
        sendToClient("all","plyr:"..playerName)
        message = receiveFromClients()
    end
end

function love.draw()
    for i ,msg in ipairs(message) do
        love.graphics.print(msg,0,20*i)
    end
end
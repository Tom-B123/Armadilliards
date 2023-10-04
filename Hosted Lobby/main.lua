local socket = require("socket")
-- require("button")

local client
local server = nil

local clients = {}

local message = ""

math.randomseed(os.clock())
local playerName = math.random(1,1000000)

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

function players:remove(name)
    for i = 1,#players do
        local player = players[i]
        if name == player.name then
            players[i] = nil
        end
    end
    playersDict[name] = nil
end

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

local function contains(table,item)
    for i,obj in ipairs(table) do
        if obj == item then
            return true
        end
    end
    return false
end

local function containsPlayer(table,name)
    for i,obj in ipairs(table) do
        if obj.name == name then
            return true
        end
    end
    return false
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
else
    --else, host one
    server = assert(socket.bind("*",1000))
    server:settimeout(0)
    players:new(playerName)
end

local function exit()
    sendToServer("exit:"..playerName)
end

function love.keypressed(key)
    if key == "escape" then
        if client then exit()
        elseif server then love.event.quit()
        end
    end
end

function love.update()
    if client then
        sendToServer("plyr:"..playerName)

        repeat
            local data = receiveFromServer()
            if data then
                local commandData = split(data,":")
                if commandData[1] == "plyr" then
                    local nPlayerName = commandData[2]
                    if not containsPlayer(players,nPlayerName) then
                        players:new(nPlayerName)
                    end
                elseif commandData[1] == "exit" then
                    local nPlayerName = commandData[2]
                    message = nPlayerName
                    if nPlayerName == playerName then
                        love.event.quit()
                    end
                end
            end
        until data == nil
    elseif server then
        updateConnections()
        for i,player in ipairs(players) do
            sendToClient("all","plyr:"..player.name)
        end
        local data = receiveFromClients()
        if data then
            for i,client in ipairs(data) do
                local commandData = split(client,":")
                if commandData[1] == "plyr" then
                    local nPlayerName = commandData[2]
                    if not containsPlayer(players,nPlayerName) then
                        players:new(nPlayerName)
                    end
                elseif commandData[1] == "exit" then
                    local nPlayerName = commandData[2]
                    message = nPlayerName
                    sendToClient("all","exit:"..nPlayerName)
                    -- players:remove(nPlayerName)
                end
            end
        end
    end
end



function love.draw()
    for i ,player in ipairs(players) do
        love.graphics.print(player.name,0,20*i)
    end
    love.graphics.print(tostring(message == tostring(playerName)),200,0)
end

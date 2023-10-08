local socket = require("socket")
-- require("button")

--To do: unblock players after a fixed interval (in ticks or in real time) 

local tick = 1

local gameState = "lobby"

local client
local server = nil

local clients = {}

local message = ""

math.randomseed(os.clock())
local playerName = math.random(1,1000000)

local players = {}
local playersDict = {}
local playersBallDict = {}
local blockedPlayers = {}

local Ball  = {}
local balls = {}
local playerBall
local ballNum

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

function players:refresh()
    for i = 1,#players do
        -- playersDict[players[i].name] = nil
        players[i] = nil
    end
    if server then players:new(playerName) end
end

Ball.__index = Ball

function Ball:new(x,y,team)
    local object = {}
    setmetatable(object,Ball)
    object.x = x
    object.y = y
    object.team = team
    return object
end

function Ball:draw(focusedBall)
    local offset = {x = 400-focusedBall.x,y = 300-focusedBall.y}
    local colour = {1,1,1}
    if self.team == "team 1" then colour = {0,0,1} end

    love.graphics.setColor(colour)
    love.graphics.circle("fill",self.x + offset.x,self.y + offset.y,20)
end

function Ball:move(x,y)
    self.x = self.x + x
    self.y = self.y + y
end

local function drawBalls(focusedBall)
    for i, ball in ipairs(balls) do
        ball:draw(focusedBall)
    end
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
    --debug text for messages, sends the key pressed to all other players
    else
        if gameState == "lobby" then
            if key == "return" and server then
                gameState = "game"
                for i = 1, #players do
                    table.insert(balls,Ball:new(i*50,i*50,"team 1"))
                end
                for i,player in ipairs(players) do
                    playersBallDict[player.name] = balls[i]
                    if player.name == playerName then
                        playerBall = balls[i]
                    else
                        --Tell the client how many balls there are, and the player's ball index
                        sendToClient("all","asgn:"..i.."_"..#balls)
                    end
                end
                -- sendToClient("all","gmst:game")
            elseif client then
                sendToServer("msg:"..playerName.."_"..key)
            elseif server then
                sendToClient("all","msg:"..playerName.."_"..key)
                table.insert(messageLog,playerName..": "..key)
            end
        end
    end
end

--process the data recieved by the client
local function processClientData(data)
    local quit = false
    if data then
        local commandData = split(data,":")
        if commandData[1] == "plyr" then
            local nPlayer = commandData[2]
            local nPlayerData = split(nPlayer,"_")
            local nPlayerName = nPlayerData[1]
            if not containsPlayer(players,nPlayerName) then
                players:new(nPlayerName)
            end
        elseif commandData[1] == "exit" then
            local nPlayerName = commandData[2]
            message = nPlayerName
            if nPlayerName == tostring(playerName) then
                love.event.quit()
            else 
                table.insert(messageLog,nPlayerName.." has left")
                players:refresh()
            end
        elseif commandData[1] == "msg" then
            local messageData = split(commandData[2],"_")
            table.insert(messageLog,messageData[1]..": "..messageData[2])
        elseif commandData[1] == "gmst" then
            gameState = commandData[2]
        elseif commandData[1] == "updt" then
            for i,ball in ipairs(balls) do
                local ballData = split(commandData[2],"_")
                ball.x = ballData[2*i-1]
                ball.y = ballData[2*i]
            end
        elseif commandData[1] == "asgn" then
            local ballData = split(commandData[2],"_")
            for i = 1,tonumber(ballData[2]) do
                table.insert(balls,Ball:new(i*50,i*50,"team 1"))
            end
            playerBall = balls[tonumber(ballData[1])]
            gameState = "game"
        end
    end
    return quit
end

--process the data recieved by the server
local function processServerData(data)
    if data then
        for i,client in ipairs(data) do
            local commandData = split(client,":")
            if commandData[1] == "plyr" then
                local nPlayer = commandData[2]
                local nPlayerData  = split(nPlayer,"_")
                local nPlayerName  = nPlayerData[1]
                local nPlayerReady = nPlayerData[2]
                local nPlayerTeam  = nPlayerData[3]
                if not contains(blockedPlayers,nPlayerName) then
                    --create a new player if the name hasn't been seen before
                    if not containsPlayer(players,nPlayerName) then
                        players:new(nPlayerName)
                    --if extra info is given, update it
                    elseif nPlayerTeam and nPlayerReady then
                        local oldPlayer = playersDict[nPlayerName]
                        oldPlayer.ready = nPlayerReady
                        oldPlayer.team = nPlayerTeam
                    end
                end
            elseif commandData[1] == "exit" then
                local nPlayerName = commandData[2]
                message = nPlayerName
                sendToClient("all","exit:"..nPlayerName)
                players:refresh()
                table.insert(blockedPlayers,nPlayerName)
                table.insert(messageLog,nPlayerName.." has left")
            elseif commandData[1] == "msg" then
                sendToClient("all",client)
                local messageData = split(commandData[2],"_")
                table.insert(messageLog,messageData[1]..": "..messageData[2])
            elseif commandData[1] == "plin" then
                local inputData = split(commandData[2],"_")
                if inputData[1] == "move" then
                    balls[2]:move(inputData[2],inputData[3])
                end
            end
        end
    end
end

--processes all incoming data for the client or the server
local function processReqeusts()
    if client then
        local quit = false
        if gameState == "lobby" then
            local clientPlayer = playersDict[playerName]
            --if a player object exists for the client's player, send all details to the host
            if clientPlayer then
                sendToServer("plyr:"..clientPlayer.name.."_"..clientPlayer.ready.."_"..clientPlayer.team)
            --otherwise, just send the player name for confirmation from the host, which will then lead to a player object being made
            else
                sendToServer("plyr:"..playerName)
            end
        end
        repeat
            local data = receiveFromServer()
            quit = processClientData(data)
        until data == nil or quit

    elseif server then
        updateConnections()
        if gameState == "lobby" then
            for i,player in ipairs(players) do
                sendToClient("all","plyr:"..player.name.."_"..player.ready.."_"..player.team)
            end
        elseif gameState == "game" then
            local message = "updt:"
            for i,ball in ipairs(balls) do
                message = message..ball.x.."_"..ball.y.."_"
            end
            sendToClient("all",message)
        end
        local data = receiveFromClients()
        processServerData(data)
    end
end

local function drawLobby()
    love.graphics.setColor(1,1,1)
    for i, message in ipairs(messageLog) do
        local y = 500 - #messageLog * 20
        love.graphics.print(message,400,y + i*20)
    end
    for i, player in ipairs(players) do
        love.graphics.print("name: "..player.name.." ready: "..player.ready.." team: "..player.team,0,20*i)
    end
end

local function processPlayerInputs()
    local x,y = 0,0
    if love.keyboard.isDown("w") then y = y - 1 end
    if love.keyboard.isDown("a") then x = x - 1 end
    if love.keyboard.isDown("s") then y = y + 1 end
    if love.keyboard.isDown("d") then x = x + 1 end
    if server then
        playerBall:move(x,y)
    elseif client then
        sendToServer("plin:move_"..ballNum.."_"..x.."_"..y)
    end
    
end

function love.update(dt)

    processReqeusts()
    
    if gameState == "game" then
        processPlayerInputs()
    end
end

function love.draw()
    
    if gameState == "lobby" then
        drawLobby()
    elseif gameState == "game" then
        drawBalls(playerBall)
    end
end

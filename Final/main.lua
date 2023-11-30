require("lists")
require("switch")
require("button")
require("net")
require("util")
require("solver")

local player = nil
local lobbyToCreate = {name = "new lobby",IP = Socket.dns.toip(Socket.dns.gethostname( )), port = 1000, maxPlayers = 8}

local toClosePlayer = false
local toConnectPlayer = nil
local server = nil

local canQuit = false
local tick = 0

local messageLog = {}

local monoSpace = love.graphics.newFont("cour.ttf",15)
love.graphics.setFont(monoSpace)

local editingText = nil
local editingIndex = 1

local state = {"main menu"}
local lState = {nil}
--Order of states, used to overlap menues ontop of eachother
local order = 1
--hardcoded limit on orders, only 4 menues can overlap at once
local maxOrder = 4
--Stores all buttons within tables, corresponding to their order.
local buttons = {}

for i = 1,maxOrder do
    buttons[i] = {}
end

--To run every frame a state is active.
local stateSwitch = Switch:new()
--To run the first frame a state is active
local newStateSwitch = Switch:new()
--To draw every frame a state is active.
local drawStateSwitch = Switch:new()
--Convert message to function
local netSwitch = Switch:new()

local function newMessage(sender,message)
    --Append the name of the sender onto the message
    local name = LobbyPlayer:getName(sender)
    if name then table.insert(messageLog,name..": "..message) end
end

local function drawMessages()
    for i,message in ipairs(messageLog) do
        local topPos = 550 - #messageLog * 20
        love.graphics.print(message,100,topPos + i*20)
    end
end

local function clearMessages()
    messageLog = {}
end

--Detect if the player clicks any buttons of the current order
local function updateButtons()
    for i,button in ipairs(buttons[order]) do
        button:update()
    end
end

local function drawButtons(ord)
    for j,button in ipairs(buttons[ord]) do
        button:draw()
    end
end

local function newButton(ord,text,colour,x1,y1,x2,y2,command,params)
    local nButton = Button:new(text,colour,0,x1,y1,x2,y2,command,params)
    table.insert(buttons[ord],nButton)
end

--Clears existing buttons on the current order (for when state changes and buttons need to change)
local function clearButtons()
    buttons[order] = {}
end

local function getNewState()
    if state[order] ~= lState[order] then return state[order] end
end

local function getState(ord)
    return state[ord]
end

--Apply editing text to the player name
local function changePlayerName()
    if not player then return end
    if editingText == "" then editingText = "new player" end
    player.name = editingText
    editingText = nil
    state[2] = nil
    lState[2] = nil
    order = 1
    player:send("updt:"..player.ID.."_name_"..player.name)
end

--Apply editing text to message, and send to other players
local function sendMessage(message)
    if not message then message = editingText end
    if player and not server then
        player:send("msg:"..player.ID.."_"..message)
    end
    if player and server then
        server:send("all","msg:"..player.ID.."_"..message)
        newMessage(player.ID,message)
    end
    editingText = nil
    state[2] = nil
    lState[2] = nil
    order = 1
end

--Apply editing text to the lobby name
local function changeLobbyName()
    if not player then return end
    if editingText == "" then editingText = "new lobby" end
    lobbyToCreate.name = editingText
    editingText = nil
    state[4] = nil
    lState[4] = nil
    order = 3
end

--Pass received data into netSwitch
local function processReceived()
    local function process(data)
        for i,message in ipairs(data) do
            local splitData = Util:split(message,":")
            local key,args = splitData[1],splitData[2]
            if key ~= "no dat" then 
                netSwitch:case(key,args)
            end
        end
    end
    local data
    if server then
        data = server:receive("all")
        process(data)
    elseif player then
        data = {player:receive()}
        while data do
            process(data)
            data = player:receive()
            if data then data = {data}
            end
        end
    end
end

--Checks if every player in the lobby is ready
local function playersAllReady()
    for i,ID in ipairs(LobbyPlayer:getIDs()) do
        if not LobbyPlayer:getReady(ID) then return false end
    end
    return true
end

--Applies vx and vy to the ball, at a set speed.
local function applyMove(ball,vx,vy)
    local speed = 0.4
    if ball then
        ball.vx = ball.vx + vx * speed
        ball.vy = ball.vy + vy * speed
    end
end

--============================================================================================--
--============================================================================================--

--Adding cases to the switch statements
stateSwitch:addCase("hosting main",function()
    if not server then return end
    if tick % 120 == 0 then
        for i,ID in ipairs(JoinableLobby.IDTable) do
            local name, hostID, IP, port, playerCount, maxPlayers = JoinableLobby:getAll(ID)
            local hostName = LobbyPlayer:getName(hostID)
            server:send("all","uplobs:"..name.."_"..hostName.."_"..hostID.."_"..
            IP.."_"..port.."_"..ID.."_"..playerCount.."_"..maxPlayers)
        end
    elseif tick % 2 == 0 then
        server:update()
    end
    server:send("all","no dat")
    processReceived()
end)

stateSwitch:addCase("searching for lobby",function()
    if not player then return end
    processReceived()
end)

stateSwitch:addCase("hosting lobby",function()
    if not server then return end
    processReceived()
    if tick % 120 == 0 then
        for i,ID in ipairs(LobbyPlayer:getIDs()) do
            local name = LobbyPlayer:getName(ID)
            local ready = LobbyPlayer:getReady(ID)
            local team = LobbyPlayer:getTeam(ID)
            server:send("all","updt:"..ID.."_name_"..name)
            server:send("all","updt:"..ID.."_ready_"..tostring(ready))
            server:send("all","updt:"..ID.."_team_".."_"..team)
        end
    elseif tick % 2 == 0 then
        server:update()
    else
        server:send("all","no dat")
    end
end)

stateSwitch:addCase("connecting to lobby",function()
    if not player then return end
    processReceived()
end)

stateSwitch:addCase("in lobby",function()
    if not player then return end
    processReceived()
end)

stateSwitch:addCase("in game",function(dt)
    if not player then return end
    processReceived()

    if not editingText then
        local x,y = Util:processGameInputs()

        if x ~= 0 or y ~= 0 then
            player:send("plin:"..player.ID.."_"..x.."_"..y)
        end
    end
end)

stateSwitch:addCase("hosting game",function(dt)
    if not server then return end
    server:send("all","no dat")
    processReceived()

    World:update(dt)
    local balls = World.balls
    if not editingText then
        local nx,ny = Util:processGameInputs()
        applyMove(balls[1],nx,ny)
    end
    if tick % 1 == 0 then
        server:send("all","upgm:"..World:getUpgm())
    end
end)

--============================================================================================--
--============================================================================================--

newStateSwitch:addCase("main menu",function()
    clearButtons()
    newButton(1,"click to start",{1,1,1},300,300,500,350,function()
        state[1] = "gamemode select"
    end)
    lState[1] = state[1]
end)

newStateSwitch:addCase("gamemode select",function()
    clearButtons()
    newButton(1,"multiplayer",{1,1,1},300,100,500,150,function()
        state[1] = "connecting to server"
    end)
    newButton(1,"settings",{1,1,1},300,300,500,350,function()
        state[2] = "user settings"
        order = 2
    end)
    newButton(1,"back",{1,1,1},300,500,500,550,function()
        state[1] = "main menu"
    end)
    lState[1] = state[1]
end)


newStateSwitch:addCase("connecting to server",function()
    clearButtons()
    local nPlayer = Player:tryConnect()
    if not nPlayer then
        lState[1] = "connecting to server"
        state[1] = "hosting main"
        server = Lobby:hostMain()
    else
        lState[1] = "connecting to server"
        state[1] = "searching for lobby"

        player = nPlayer
        player.ID = Util:calculateID(8)
        player:send("ncon:"..player.ID.."_"..player.name)
    end
end)

newStateSwitch:addCase("hosting main",function()
    clearButtons()
    if server then
        newButton(1,"close main server",{1,0,0},50,50,750,250,function()
            state[1] = "gamemode select"
            server:close()
        end)
        lState[1] = "hosting main"
    else
        lState[1] = "connecting to server"
        state[1] = "connection error"
    end
end)

newStateSwitch:addCase("connection error",function()
    clearButtons()
    print("connection error")
    newButton(1,"retry",{1,1,1},300,375,500,425,function()
        state[1] = "connecting to server"
    end)
    newButton(1,"back",{1,1,1},300,450,500,500,function()
        state[1] = "gamemode select"
    end)
    lState[1] = state[1]
end)

newStateSwitch:addCase("user settings",function()
    clearButtons()
    newButton(2,"configure settings",{1,1,1},300,300,500,350,function()
        order = 3
        state[3] = "configure game settings"
        lState[3] = nil
    end)
    newButton(2,"back",{1,1,1},300,375,500,425,function()
        state[2] = nil
        lState[2] = nil
        order = 1
    end)
    newButton(2,"quit",{1,1,1},300,450,500,500,function()
        love.event.quit()
    end)
    lState[2] = state[2]
end)

newStateSwitch:addCase("configure game settings",function()
    newButton(3,"back",{1,1,1},300,375,500,425,function()
        --arbitrary values so user settings can open above any menu
        state[3] = nil
        lState[3] = nil
        order = 2
    end)
    lState[3] = state[3]
end)

newStateSwitch:addCase("searching for lobby",function()
    if not player then return end
    clearButtons()
    
    --no text, the player name is drawn separatly above the button
    newButton(1,"",{1,1,1},300,25,500,75,function()
        state[2] = "editing player name"
        lState[2] = nil
        order = 2
    end)
    newButton(1,"Create new lobby",{1,1,1},300,400,500,450,function()
        lState[2] = nil
        state[2] = "lobby creation"
        order = 2
    end)
    newButton(1,"back",{1,1,1},300,475,500,525,function()
        player:send("econ:"..player.ID)
    end)
    lState[1] = state[1]
end)

newStateSwitch:addCase("editing player name",function()
    if not player then return end
    clearButtons()
    
    editingText = player.name
    editingIndex = #editingText + 1
    newButton(2,"cancel",{1,0,0},300,80,398,105,function()
        state[2] = nil
        lState[2] = nil
        order = 1
        editingText = nil
    end)
    newButton(2,"confirm",{0,1,0},402,80,500,105,function()
        changePlayerName()
    end)
    lState[2] = state[2]
end)

newStateSwitch:addCase("lobby creation",function()
    if not player then return end
    clearButtons()
    newButton(2,"back",{1,1,1},300,300,500,350,function()
        state[2] = nil
        lState[2] = nil
        state[1] = "searching for lobby"
        order = 1
    end)
    newButton(2,"Lobby settings",{1,1,1},300,375,500,425,function()
        lState[3] = nil
        state[3] = "lobby settings"
        order = 3
    end)
    newButton(2,"Create",{1,1,1},300,450,500,500,function()
        
    player:send("create:"..
        player.ID.."_"..
        lobbyToCreate.name.."_"..
        lobbyToCreate.IP.."_"..
        lobbyToCreate.port.."_"..
        lobbyToCreate.maxPlayers
    )
    end)
    lState[2] = state[2]
end)

newStateSwitch:addCase("lobby settings",function()
    clearButtons()
    --no text, lobby name drawn above text
    newButton(3,"",{1,1,1},300,300,500,350,function()
        lState[4] = nil
        state[4] = "editing lobby name"
        order = 4
    end)
    newButton(3,"max players",{1,1,1},300,375,500,425,function()
        --change number of max players (2,4,8?)
    end)
    newButton(3,"back",{1,1,1},300,450,500,500,function()
        state[3] = nil
        lState[3] = nil
        order = 2
    end)
    lState[3] = state[3]
end)

newStateSwitch:addCase("editing lobby name",function()
    if not player then return end
    clearButtons()
    
    editingText = lobbyToCreate.name
    editingIndex = #editingText + 1
    newButton(4,"cancel",{1,0,0},300,355,398,380,function()
        state[4] = nil
        lState[4] = nil
        order = 3
        editingText = nil
    end)
    newButton(4,"confirm",{0,1,0},402,355,500,380,function()
        changeLobbyName()
    end)
    lState[4] = state[4]
end)

newStateSwitch:addCase("hosting lobby",function()
    if not (player and server) then return end

    clearButtons()

    LobbyPlayer:clear()
    LobbyPlayer:new(player.ID)
    LobbyPlayer:setName(player.ID,player.name)
    LobbyPlayer:setReady(player.ID,true)
    LobbyPlayer:setTeam(player.ID,"team 1")

    newButton(1,"start",{1,1,1},600,500,750,550,function()
        if playersAllReady() then
            server:send("all","start:")
            state[1] = "hosting game"
            lState[1] = nil
            order = 1
        else
            sendMessage("ready up")
        end
    end)

    lState[1] = state[1]
end)

newStateSwitch:addCase("connecting to lobby",function()
    if not player then return end
    
    player:send("ncon:"..player.ID.."_"..player.name)
    lState[1] = state[1]
end)

newStateSwitch:addCase("in lobby",function()
    if not player then return end
    
    clearButtons()
    
    newButton(1,"ready",{1,1,1},600,500,750,550,function()
        local ready = LobbyPlayer:getReady(player.ID)
        LobbyPlayer:setReady(player.ID,not ready)
        player:send("updt:"..player.ID.."_ready_"..tostring(not ready))
    end)

    lState[1] = state[1]
end)

newStateSwitch:addCase("editing message",function()
    clearButtons()

    editingText = ""
    editingIndex = 1

    newButton(2,"send",{1,1,1},450,400,500,450,function()
        sendMessage()
    end)

    lState[2] = state[2]
end)

newStateSwitch:addCase("hosting game",function()
    if not server then return end
    clearButtons()

    World:newBall(50,50,true)
    World:newBall(150,50,true)
    World:newBall(50,150,true)
    World:newBall(150,150,true)
    World:newBall(300,75,false)

    World:generateIDs()

    World:assign(LobbyPlayer:getIDs())

    print("asgn:"..World:getAsgn())

    lState[1] = state[1]
end)

newStateSwitch:addCase("in game",function()
    if not player then return end
    clearButtons()

    lState[1] = state[1]
end)

newStateSwitch:addCase("end screen",function()
    clearButtons()

    newButton(2,"Return to lobby",{1,1,1},300,200,500,250,function()
        if server then
            state[2] = nil
            lState[2] = nil
            lState[1] = nil
            state[1] = "hosting lobby"
            order = 1
        else
            state[2] = nil
            lState[2] = nil
            lState[1] = nil
            state[1] = "in lobby"
            order = 1
        end
    end)

    lState[2] = state[2]
end)

--============================================================================================--
--============================================================================================--

drawStateSwitch:addCase("main menu",function()
    love.graphics.print("This is the main menu",300,100)
    drawButtons(1)
end)

drawStateSwitch:addCase("gamemode select",function()
    love.graphics.print("Leaderboard",300,50)
    drawButtons(1)
end)

drawStateSwitch:addCase("connecting to server",function()
    drawButtons(1)
end)

drawStateSwitch:addCase("connection error",function()
    drawButtons(1)
    love.graphics.print("connection error",300,100)
end)

drawStateSwitch:addCase("hosting main",function()
    if not server then return end
    drawButtons(1)
    love.graphics.setColor(1,1,1)
    love.graphics.print("You are now the main host",300,500)
    
    love.graphics.print("player Count: "..server.playerCount,300,400)
end)

drawStateSwitch:addCase("user settings",function()
    love.graphics.setColor(0.5,0.5,0.5)
    love.graphics.rectangle("fill",250,250,300,300)
    drawButtons(order)
end)

drawStateSwitch:addCase("configure game settings",function()
    love.graphics.setColor(0.5,0.5,0.5)
    love.graphics.rectangle("fill",250,250,300,300)
    drawButtons(order)
end)

drawStateSwitch:addCase("searching for lobby",function()
    if not player then return end
    drawButtons(1)
    --Drawing the player name onto the edit player name button
    
    local playerNameText
    if editingText and getState(2) == "editing player name" then playerNameText = editingText
    else playerNameText = player.name end
    if playerNameText then love.graphics.print(playerNameText,300,25) end
end)

drawStateSwitch:addCase("editing player name",function()
    drawButtons(2)
    if tick % 30 > 30 / 2 then
        love.graphics.setColor(0.4,0.4,0.4,0.7)
        love.graphics.rectangle("fill",300 - 2.5 + (editingIndex-1)*9,25,5,17.5)
    end
end)

drawStateSwitch:addCase("lobby creation",function()
    love.graphics.setColor(0.5,0.5,0.5)
    love.graphics.rectangle("fill",250,250,300,300)
    drawButtons(2)
end)

drawStateSwitch:addCase("lobby settings",function()
    love.graphics.setColor(0.5,0.5,0.5)
    love.graphics.rectangle("fill",250,250,300,300)
    drawButtons(3)

    local LobbyNameText
    if editingText and getState(4) == "editing lobby name" then LobbyNameText = editingText
    else LobbyNameText = lobbyToCreate.name end
    if LobbyNameText then love.graphics.print(LobbyNameText,300,300) end
end)

drawStateSwitch:addCase("editing lobby name",function()
    drawButtons(4)
    if tick % 30 > 30 / 2 then
        love.graphics.setColor(0.4,0.4,0.4,0.7)
        love.graphics.rectangle("fill",300 - 2.5 + (editingIndex-1)*9,300,5,17.5)
    end
end)

drawStateSwitch:addCase("hosting lobby",function()
    drawMessages()
    drawButtons(1)
    for i, ID in ipairs(LobbyPlayer:getIDs()) do
        local name, ready, team = 
        LobbyPlayer:getName(ID), LobbyPlayer:getReady(ID), LobbyPlayer:getTeam(ID)

        if name and ready and team then
            love.graphics.print(name,0,20*i)
            love.graphics.print(tostring(ready),200,20*i)
            love.graphics.print(team,400,20*i)
        end
    end
end)

drawStateSwitch:addCase("connecting to lobby",function()
    love.graphics.print("connecting to lobby...",100,100)
end)

drawStateSwitch:addCase("in lobby",function()
    drawMessages()
    drawButtons(1)
    for i, ID in ipairs(LobbyPlayer:getIDs()) do
        local name, ready, team = 
        LobbyPlayer:getName(ID), LobbyPlayer:getReady(ID), LobbyPlayer:getTeam(ID)

        if name and ready ~= nil and team then
            love.graphics.print(name,0,20*i)
            love.graphics.print(tostring(ready),200,20*i)
            love.graphics.print(team,400,20*i)
        end
    end
end)

drawStateSwitch:addCase("editing message",function()
    drawButtons(2)
    if editingText then love.graphics.print(editingText,50,400) end
    if tick % 30 > 30 / 2 then
        love.graphics.setColor(0.4,0.4,0.4,0.7)
        love.graphics.rectangle("fill",50 - 2.5 + (editingIndex-1)*9,400,5,17.5)
    end
end)

drawStateSwitch:addCase("in game",function()
    drawMessages()
    World:draw()
end)

drawStateSwitch:addCase("hosting game",function()
    drawMessages()
    World:draw()
end)

drawStateSwitch:addCase("end screen",function()
    love.graphics.setColor(1,1,1)
    love.graphics.rectangle("fill",200,200,400,300)
    drawMessages()
    drawButtons(2)
end)


--============================================================================================--
--============================================================================================--

--Send a message to players, relays this message to other players as the server
netSwitch:addCase("msg",function(args)
    local splitData = Util:split(args,"_")
    local sender = splitData[1]
    local message = splitData[2]

    if server then server:send("all","msg:"..sender.."_"..message) end

    newMessage(sender,message)
end)

--New connection, sends initial information about the player
netSwitch:addCase("ncon",function(args)
    if server then
        local splitData = Util:split(args,"_")

        local ID = splitData[1]
        local name = splitData[2]

        LobbyPlayer:new(ID)
        LobbyPlayer:setName(ID,name)
        LobbyPlayer:setReady(ID,false)
        LobbyPlayer:setTeam(ID,"team 1")
        
        server:send("all","ncon:"..ID.."_"..name.."_confirm")
    end

    if player then
        local splitData = Util:split(args,"_")

        local ID, name, conf = splitData[1],splitData[2],splitData[3]

        if conf == "confirm" then
            if ID == player.ID then
                --On confirmation, make a LobbyPlayer object with player's details
                LobbyPlayer:clear()
                LobbyPlayer:new(player.ID)
                LobbyPlayer:setName(player.ID,player.name)
                LobbyPlayer:setReady(player.ID,false)
                LobbyPlayer:setTeam(player.ID,"team 1")
                if getState(1) == "connecting to lobby" then
                    lState[1] = nil
                    state[1] = "in lobby"
                end
            end
        end
    end
end)

--End connection with main server
netSwitch:addCase("econ",function(args)
    if server then
        local ID = args
        server:send("all","econ:"..ID)
        --end the connection with client
        --LobbyPlayer:removeID(ID)
    elseif player then
        local ID = args
        if ID == player.ID then
            toClosePlayer = false
            state[1] = "gamemode select"
            lState[1] = nil

            JoinableLobby:clear()

            clearMessages()
        end
    end
end)

--Update player info, for when player changes ready state or name
netSwitch:addCase("updt",function(args)
    local splitData = Util:split(args,"_")
    --sender ID
    local ID = splitData[1]
    local field = splitData[2]
    local value = splitData[3]

    if not LobbyPlayer:getName(ID) then LobbyPlayer:new(ID) end

    if field == "name" then LobbyPlayer:setName(ID,value)
    elseif field == "ready" then LobbyPlayer:setReady(ID,value)
    elseif field == "team" then LobbyPlayer:setTeam(ID,value)
    end
end)

--Request and confirm joining a new lobby
netSwitch:addCase("join",function(args)
    if server then
        local splitData = Util:split(args,"_")
        local playerID,lobbyID = splitData[1], splitData[2]

        print("player: "..playerID.." ("..LobbyPlayer:getName(playerID)..") ".." wants to join lobby: "..lobbyID)
        
        local IP = JoinableLobby:getIP(lobbyID)
        local port = JoinableLobby:getPort(lobbyID)

        server:send("all","join:"..playerID.."_"..IP.."_"..port)
    elseif player then
        local splitData = Util:split(args,"_")
        local ID,IP,port = splitData[1], splitData[2],splitData[3]

        if ID == player.ID then
            lState[1] = nil
            state[1] = "connecting to lobby"
            order = 1

            local nPlayer = Player:new(IP,port)
            nPlayer.name = player.name
            nPlayer.ID = player.ID

            toConnectPlayer = nPlayer
        end
    end
end)

--Create a new lobby and confirm creation
netSwitch:addCase("create",function(args)
    if server then
        local splitData = Util:split(args,"_")
        local hostID, lobbyName, IP, port, maxPlayers = 
        splitData[1], splitData[2], splitData[3], splitData[4], splitData[5]
        
        --If ports are already in use on that IP, use the next port
        local existingPorts = JoinableLobby:getPortsByIP(IP)
        if existingPorts then
            port = tonumber(existingPorts[#existingPorts]) + 1
            
        end

        print(IP.." hosting a lobby on port: "..port)

        local ID = JoinableLobby:new()
        JoinableLobby:setName(ID,lobbyName)
        JoinableLobby:setHostID(ID,hostID)
        JoinableLobby:setIP(ID,IP)
        JoinableLobby:setPort(ID,port)
        JoinableLobby:setPlayerCount(ID,0)
        JoinableLobby:setMaxPlayers(ID,maxPlayers)
        
        server:send("all","create:"..hostID.."_"..ID.."_"..lobbyName.."_"..IP.."_"..port.."_"..maxPlayers)
    elseif player then
        local splitData = Util:split(args,"_")
        local hostID, lobbyID, lobbyName, IP, port, maxPlayers = 
        splitData[1], splitData[2], splitData[3], splitData[4], splitData[5], splitData[6]

        if player.ID == hostID then
            state[1] = "hosting lobby"
            state[2] = nil
            lState[2] = nil
            order = 1

            --Host has both a server and player object
            server = Lobby:new(lobbyName,port,IP,player.ID,maxPlayers)

            local nPlayer = Player:new(IP,port)
            nPlayer.name = player.name
            nPlayer.ID = player.ID

            toConnectPlayer = nPlayer
        end
    end
end)

--Update lobby list
netSwitch:addCase("uplobs",function(args)
    if not player then return end

    local splitData = Util:split(args,"_")
    local lobbyName, hostName, hostID, IP, port, lobbyID, playerCount, maxPlayers = 
    splitData[1], splitData[2], splitData[3], splitData[4], splitData[5], splitData[6], splitData[7], splitData[8]

    --Sets the player name to display, as it may not be known
    if not LobbyPlayer:getName(hostID) then
        LobbyPlayer:new(hostID)
        LobbyPlayer:setName(hostID,hostName)
    end

    --Uses getName arbitrarily, dictionary lookup will give nil only if the ID isn't stored
    if not JoinableLobby:getName(lobbyID) then

        JoinableLobby:new(lobbyID)
        JoinableLobby:setName(lobbyID,lobbyName)
        JoinableLobby:setHostID(lobbyID,hostID)
        JoinableLobby:setIP(lobbyID,IP)
        JoinableLobby:setPort(lobbyID,port)
        JoinableLobby:setPlayerCount(lobbyID,playerCount)
        JoinableLobby:setMaxPlayers(lobbyID,8)

        local y = #JoinableLobby.IDTable * 40
        newButton(1,"lobby name: "..lobbyName.." host name: "..hostName.." count: "..playerCount.."/"..maxPlayers,{1,1,1},100,100 + y,700,135 + y,function()
            player:join(lobbyID)
        end)
    else
        JoinableLobby:setPlayerCount(lobbyID, playerCount)
    end
end)

--Start a new game
netSwitch:addCase("start",function(args)
    state[1] = "in game"
    lState[1] = nil
    order = 1
end)

--Asign ball ID to a player
netSwitch:addCase("asgn",function(args)
    if not player then return end

    local splitData = Util:split(args)

    for i = 1,#splitData / 2 do
        local playerID,ballID = splitData[i*2-1],splitData[i*2]
        if player.ID == playerID then
            player.ballID = ballID
        end
    end
end)

--Take player input from clients
netSwitch:addCase("plin",function(args)
    if not server then return end

    local splitData = Util:split(args,"_")
    local ID,x,y = splitData[1], splitData[2], splitData[3]

    local ballID = LobbyPlayer:getBallID(ID)
    local ball = World:getByID(ballID)

    applyMove(ball,x,y)
end)

--Update gamestate
netSwitch:addCase("upgm",function(args)
    if not player then return end

    local splitData = Util:split(args,"_")
    --Changes = {{ID1,x1,y1},{ID2,x2,y2},{ID3,x3,y3}}
    local changes = {}

    for i,msg in ipairs(splitData) do
        local ind = i - 1
        if changes[math.floor(ind/3)+1] == nil then changes[math.floor(ind/3)+1] = {} end
        changes[math.floor(ind/3)+1][(ind%3) + 1] = msg
    end

    for i, change in ipairs(changes) do
        local ID,x,y = change[1],change[2],change[3]
        if ID and x and y then
            local ball = World:getByID(ID)
            if ball then
                ball.x = x
                ball.lx = x
                ball.y = y
                ball.ly = y
            else
                local nball = World:newBall(x,y,true)
                World:assignID(nball,ID,0)
            end
            -- do World:getByID(ID) when IDs are consistent between players
        end
    end
end)

netSwitch:addCase("endgm",function(args)
    local splitData = Util:split(args,"_")
    print(args)
    local winningTeam = ""
    local maxScore = 0
    for i = 1,#splitData/2 do
        local team,score = splitData[2*1-1],splitData[2*i]
        if score > maxScore then
            maxScore = score
            winningTeam = team
        end
    end
    state[2] = "end screen"
    lState[2] = nil
    order = 2
    newMessage("The winner is: "..winningTeam.." with "..maxScore.." points")
end)

function love.textinput(t)
    if not editingText then return end
    if not player then return end
    if t == nil or t == ":" or t == "_" then return end

    --Adds text at the editing index and incriments the index
    editingText = string.sub(editingText,1,editingIndex-1)..t..string.sub(editingText,editingIndex,#editingText)
    editingIndex = editingIndex + 1
end

--Handle keyboard inputs
function love.keypressed(key)
    if state == "hosting game" and server and key == "escape" then
        local msg = "endgm:"
        for i = 1,4 do
            local score = Util:calculateID(4,i)
            msg = msg.."team"..i.."_"..score
            if i < 4 then msg = msg.."_" end
        end
        server:send("all",msg)
    end
    if editingText and player then
        if key == "escape" then
            state[order] = nil
            lState[order] = nil
            order = order - 1
            editingText = nil
        
        elseif key == "return" then
            if getState(2) == "editing player name" then changePlayerName()
            elseif getState(2) == "editing message" then sendMessage()
            elseif getState(4) == "editing lobby name" then changeLobbyName()
            end
        
        elseif key == "delete" then
            --Delete everything after the index when ctrl + delete
            if love.keyboard.isDown("lctrl") or love.keyboard.isDown("rctrl") then
                editingText = string.sub(editingText,1,editingIndex-1)
            --Deletes the text at the editing index
            elseif editingIndex <= #editingText then
                editingText = string.sub(editingText,1,editingIndex-1)..string.sub(editingText,editingIndex+1,#editingText)
            end
        
        elseif key == "backspace" then
            --Delete everything before the index when ctrl + backspace
            if love.keyboard.isDown("lctrl") or love.keyboard.isDown("rctrl") then
                editingText = string.sub(editingText,editingIndex,#editingText)
                editingIndex = 1
            --Deletes the text before the editing index and decriments the index
            elseif editingIndex > 1 then
                editingText = string.sub(editingText,1,editingIndex-2)..string.sub(editingText,editingIndex,#editingText)
                editingIndex = editingIndex - 1
            end
        
            --Move the index left or right until there is no space left
        elseif key == "left" then
            if editingIndex > 1 then 
                editingIndex = editingIndex - 1
            end
        
        elseif key == "right" then
            if editingIndex < #editingText + 1 then
                editingIndex = editingIndex + 1
            end
        
        end
    
    elseif key == "escape" then
        --If in a menu, esc closes that menu
        if order > 1 then
            state[order] = nil
            lState[order] = nil
            order = order - 1
        --If not in a menu, esc opens options
        else
            order = 2
            lState[2] = nil
            state[2] = "user settings"
        end
    elseif key == "t" and (state[1] == "in lobby" or state[1] == "hosting lobby" or state[1] == "in game" or state[1] == "hosting game") then
        lState[2] = nil
        state[2] = "editing message"
        order = 2
    elseif state == "main menu" then
        state[1] = "gamemode select"
    end
end

function love.quit()
    --return true to prevent quitting?
    if player then
        player:send("econ:"..player.ID)
        return not canQuit
    end
    -- return true
end

function love.load()
    love.keyboard.setKeyRepeat(true)
end

--Process each frame
function love.update(dt)

    if state[order] == nil then
        order = 1
    end

    updateButtons()

    --Loop through all state changes this frame
    local nState = getNewState()
    while nState do
        newStateSwitch:case(nState)
        nState = getNewState()
    end

    for i = 1,maxOrder do
        stateSwitch:case(getState(i),dt)
    end

    if toClosePlayer then
        player = nil
        toClosePlayer = false
    end

    if toConnectPlayer then
        player = toConnectPlayer
        toConnectPlayer = nil
    end

    tick = tick + 1
end

--Draw each frame
function love.draw()
    for i = 1,maxOrder do
        drawStateSwitch:case(getState(i))
    end
    love.graphics.setColor(1,1,1)
    love.graphics.print(state[order])
end

require("lists")
require("switch")
require("button")
require("net")
require("util")
require("solver")

local player = nil
--Default values for creating a lobby
local lobbyToCreate = {name = "new lobby", maxPlayers = 8}

local toRemoveIDs     = {}
local toConnectMain   = false
local toClosePlayer   = false
local toConnectPlayer = nil
--Used when exiting a server, sets a delay of n ticks before changing state to confirm exit.
local toChangeState   = nil
local tempTick        = 0

local server = nil

--number of ticks between each lobby refresh
local refreshRate = 120

local canQuit     = false
local tick        = 0

local messageLog  = {}

local monoSpace   = love.graphics.newFont("cour.ttf",15)
love.graphics.setFont(monoSpace)

local editingText  = nil
local editingIndex = 1

local state    = {"main menu"}
local lState   = {nil}
--Order of states, used to overlap menues ontop of eachother
local order    = 1
--hardcoded limit on orders, only 4 menues can overlap at once
local maxOrder = 4
--Stores all buttons within tables, corresponding to their order.
local buttons  = {}

for i = 1,maxOrder do
    buttons[i] = {}
end

--To run every frame a state is active.
local stateSwitch     = Switch:new()
--To run the first frame a state is active
local newStateSwitch  = Switch:new()
--To draw every frame a state is active.
local drawStateSwitch = Switch:new()
--Convert message to function
local netSwitch       = Switch:new()

local function newMessage(sender,message)
    --Append the name of the sender onto the message
    local name = LobbyPlayer:getName(sender)
    if sender == "server" then name = "server" end
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

local function removeButton(ord,dButton)
    local ind = -1
    for i,button in ipairs(buttons[ord]) do
        if button == dButton then ind = i end
    end
    if ind > -1 then
        table.remove(buttons[ord],ind)
    end
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
    return nButton
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
    player.name    = editingText
    editingText    = nil
    state[2]       = nil
    lState[2]      = nil
    order          = 1
    -- player:send("updt:"..player.ID.."_name_"..player.name)
end

--Apply editing text to message, and send to other players
local function sendMessage(message)
    if not message then message = editingText end
    if player and not server then
        player:send("msg:"..player.ID.."_"..message.."_\n")
    end
    if player and server then
        server:send("all","msg:"..player.ID.."_"..message.."_\n")
        newMessage(player.ID,message)
    end
    editingText = nil
    state[2]    = nil
    lState[2]   = nil
    order       = 1
end

--Apply editing text to the lobby name
local function changeLobbyName()
    if not player then return end
    if editingText    == "" then editingText = "new lobby" end
    lobbyToCreate.name = editingText
    editingText        = nil
    state[4]           = nil
    lState[4]          = nil
    order              = 3
end

--Pass received data into netSwitch
local function processReceived()
    local function process(data)
        for i,message in ipairs(data) do
            local splitData = Util:split(message,":")
            local key,args  = splitData[1],splitData[2]
            if args then
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
        if not (LobbyPlayer:getReady(ID) and LobbyPlayer:getInLobby(ID))  then return false end
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

--Returns true if the player is in a lobby / in game
local function inLobby()
    return (state[1] == "in lobby" or state[1] == "hosting lobby" or state[1] == "in game" or state[1] == "hosting game")
end

--============================================================================================--
--============================================================================================--

--Adding cases to the switch statements

stateSwitch:addCase("searching for lobby",function()
    if not player then return end

    player:send("no dat\n")

    processReceived()
end)

stateSwitch:addCase("hosting lobby",function()
    if not (server and player) then return end
    processReceived()
    if tick % refreshRate == 0 then
        server:sendUpdateMessage()
        player:send("updt:"..server.ID.."_player count_"..server.playerCount.."_\n")
    elseif tick % 2       == 0 then
        server:update()
    else
        server:send("all","no dat".."_\n")
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

    if order == 1 and not editingText then
        local x,y = Util:processGameInputs()

        if x ~= 0 or y ~= 0 then
            player:send("plin:"..player.ID.."_"..x.."_"..y.."_\n")
        end
    end
end)

stateSwitch:addCase("hosting game",function(dt)
    if not server then return end
    server:send("all","no dat".."_\n")
    processReceived()

    World:update(dt)

    local balls = World.balls
    if order == 1 and not editingText then
        local nx,ny = Util:processGameInputs()
        applyMove(balls[1],nx,ny)
    end

    if tick % refreshRate == 0 then
        server:sendUpdateMessage()
    end
    if tick % 1 == 0 then
        local gameState = World:getUpgm()
        for i, ball in ipairs(gameState) do
            server:send("all",ball)
        end
    end

    if love.keyboard.isDown("y") and order == 1 then
        local msg = "endgm:"

        for i = 1,4 do
            local score = Util:calculateID(4,i)
            msg = msg.."team"..i.."_"..score
            if i < 4 then msg = msg.."_" end
        end

        server:send("all",msg.."_\n")
        state[2]  = "end screen"
        lState[2] = nil
        order     = 2

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
        order    = 2
    end)
    newButton(1,"back",{1,1,1},300,500,500,550,function()
        state[1] = "main menu"
    end)
    lState[1] = state[1]
end)

newStateSwitch:addCase("connecting to server",function()
    clearButtons()
    print("connecting to main")
    local nPlayer = Player:tryConnect()
    if not nPlayer then
        lState[1] = "connecting to server"
        state[1]  = "connection error"
    else
        lState[1] = "connecting to server"
        state[1]  = "searching for lobby"

        player    = nPlayer
        player.ID = Util:calculateID(8)
        -- player:send("ncon:"..player.ID.."_"..player.name)
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
    lState[1]    = state[1]
end)

newStateSwitch:addCase("user settings",function()
    clearButtons()
    newButton(2,"configure settings",{1,1,1},300,300,500,350,function()
        order     = 3
        state[3]  = "configure game settings"
        lState[3] = nil
    end)
    newButton(2,"back",{1,1,1},300,375,500,425,function()
        state[2]  = nil
        lState[2] = nil
        order     = 1
    end)
    newButton(2,"quit",{1,1,1},300,450,500,500,function()
        love.event.quit()
    end)
    lState[2] = state[2]
end)

newStateSwitch:addCase("configure game settings",function()
    newButton(3,"back",{1,1,1},300,375,500,425,function()
        --arbitrary values so user settings can open above any menu
        state[3]  = nil
        lState[3] = nil
        order     = 2
    end)
    lState[3] = state[3]
end)

newStateSwitch:addCase("searching for lobby",function()
    if not player then return end
    clearButtons()
    
    JoinableLobby:clear()
    --no text, the player name is drawn separatly above the button
    newButton(1,"",{1,1,1},300,25,500,75,function()
        state[2]  = "editing player name"
        lState[2] = nil
        order     = 2
    end)
    newButton(1,"Create new lobby",{1,1,1},300,400,500,450,function()
        lState[2] = nil
        state[2]  = "lobby creation"
        order     = 2
    end)
    newButton(1,"back",{1,1,1},300,475,500,525,function()
        player:send("econ:"..player.ID.."_\n")
        toChangeState = "gamemode select"
        tempTick      = 30
    end)
    lState[1] = state[1]
end)

newStateSwitch:addCase("editing player name",function()
    if not player then return end
    clearButtons()
    
    editingText  = player.name
    editingIndex = #editingText + 1
    newButton(2,"cancel",{1,0,0},300,80,398,105,function()
        state[2]    = nil
        lState[2]   = nil
        order       = 1
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
        state[2]  = nil
        lState[2] = nil
        state[1]  = "searching for lobby"
        order     = 1
    end)
    newButton(2,"Lobby settings",{1,1,1},300,375,500,425,function()
        lState[3] = nil
        state[3]  = "lobby settings"
        order     = 3
    end)
    newButton(2,"Create",{1,1,1},300,450,500,500,function()
        local lobbyID = Util:calculateID(6)
        local IP      = Socket.dns.toip(Socket.dns.gethostname( ))
        local port    = 1000
        player:send("create:"..
            lobbyID.."_"..
            lobbyToCreate.name.."_"..
            player.ID.."_"..
            player.name.."_"..
            IP.."_"..
            port.."_"..
            lobbyToCreate.maxPlayers.."_\n"
        )
    end)
    lState[2] = state[2]
end)

newStateSwitch:addCase("lobby settings",function()
    clearButtons()
    --no text, lobby name drawn above text
    newButton(3,"",{1,1,1},300,300,500,350,function()
        lState[4] = nil
        state[4]  = "editing lobby name"
        order     = 4
    end)
    newButton(3,"max players",{1,1,1},300,375,500,425,function()
        --change number of max players (2,4,8?)
    end)
    newButton(3,"back",{1,1,1},300,450,500,500,function()
        state[3]  = nil
        lState[3] = nil
        order     = 2
    end)
    lState[3] = state[3]
end)

newStateSwitch:addCase("editing lobby name",function()
    if not player then return end
    clearButtons()
    
    editingText  = lobbyToCreate.name
    editingIndex = #editingText + 1
    newButton(4,"cancel",{1,0,0},300,355,398,380,function()
        state[4]    = nil
        lState[4]   = nil
        order       = 3
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

    if lState[1] ~= "in game"  then
        LobbyPlayer:clear()
        LobbyPlayer:new(player.ID)
        LobbyPlayer:setName(player.ID,player.name)
        LobbyPlayer:setReady(player.ID,true)
        LobbyPlayer:setInLobby(player.ID,true)
        LobbyPlayer:setTeam(player.ID,"team 1")
    end

    newButton(1,"start",{1,1,1},600,500,750,550,function()
        if playersAllReady() then
            server:send("all","start:".."_\n")
            state[1]  = "hosting game"
            lState[1] = nil
            order     = 1
            --Clears all existing balls
            World:clear()
        else
            sendMessage("ready up")
        end
    end)

    lState[1] = state[1]
end)

newStateSwitch:addCase("connecting to lobby",function()
    if not player then return end

    player:send("ncon:"..player.ID.."_"..player.name.."_\n")
    lState[1] = state[1]
end)

newStateSwitch:addCase("in lobby",function()
    if not player then return end
    
    clearButtons()

    newButton(1,"ready",{1,1,1},600,500,750,550,function()
        local ready = LobbyPlayer:getReady(player.ID)
        LobbyPlayer:setReady(player.ID,not ready)
        player:send("updt:"..player.ID.."_ready_"..tostring(not ready).."_\n")
    end)

    lState[1] = state[1]
end)

newStateSwitch:addCase("editing message",function()
    clearButtons()

    editingText  = ""
    editingIndex = 1

    newButton(2,"send",{1,1,1},450,400,500,450,function()
        sendMessage()
    end)

    lState[2] = state[2]
end)

newStateSwitch:addCase("hosting game",function()
    if not (server and player) then return end
    clearButtons()
    
    LobbyPlayer:setInLobby(player.ID,false)
    -- server:send("all","updt:"..player.ID.."_in lobby_false")

    World:newBall(50,50,true)
    World:newBall(150,50,true)
    World:newBall(50,150,true)
    World:newBall(150,150,true)
    World:newBall(300,75,false)

    World:generateIDs()

    World:assign(LobbyPlayer:getIDs())

    lState[1] = state[1]
end)

newStateSwitch:addCase("in game",function()
    if not player then return end
    clearButtons()

    lState[1] = state[1]
end)

newStateSwitch:addCase("end screen",function()
    if not player then return end
    clearButtons()

    newButton(2,"Return to lobby",{1,1,1},300,200,500,250,function()
        --Last state set to in game to stop Ids being dropped
        LobbyPlayer:setInLobby(player.ID,true)
        if server then
            state[2]  = nil
            lState[2] = nil
            lState[1] = "in game"
            state[1]  = "hosting lobby"
            order     = 1
            server:send("all","updt:"..player.ID.."_in lobby_true_\n")
        else
            state[2]  = nil
            lState[2] = nil
            lState[1] = "in game"
            state[1]  = "in lobby"
            order     = 1
            player:send("updt:"..player.ID.."_in lobby_true_\n")
        end
    end)

    lState[2] = state[2]
end)

newStateSwitch:addCase("lobby pause screen",function()
    if not player then return end
    clearButtons()

    newButton(2,"back",{1,1,1},300,200,500,250, function()
        state[2]  = nil
        lState[2] = nil
        order     = 1
    end)

    if server then
        newButton(2,"close lobby",{1,1,1},300,275,500,325, function()
            --Close the lobby and kick every player from the lobby, v complicated
        end)
    else
        newButton(2,"exit lobby",{1,1,1},300,275,500,325, function()
            player:send("econ:"..player.ID.."_\n")
        end)
    end
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
        local name  = LobbyPlayer:getName(ID)
        local ready = LobbyPlayer:getReady(ID)
        local lobby = LobbyPlayer:getInLobby(ID)
        local team  = LobbyPlayer:getTeam(ID)

        if name and ready ~= nil and team then
            love.graphics.print(name,0,20*i)
            love.graphics.print(tostring(ready),200,20*i)
            love.graphics.print(tostring(lobby),300,20*i)
            love.graphics.print(team,400,20*i)
        end
    end
end)

drawStateSwitch:addCase("connecting to lobby",function( )
    love.graphics.print("connecting to lobby...",100,100)
end)

drawStateSwitch:addCase("in lobby",function()
    drawMessages()
    drawButtons(1)
    for i, ID in ipairs(LobbyPlayer:getIDs()) do
        local name  = LobbyPlayer:getName(ID)
        local ready = LobbyPlayer:getReady(ID)
        local lobby = LobbyPlayer:getInLobby(ID)
        local team  = LobbyPlayer:getTeam(ID)

        if name and ready ~= nil and team then
            love.graphics.print(name,0,20*i)
            love.graphics.print(tostring(ready),200,20*i)
            love.graphics.print(tostring(lobby),300,20*i)
            love.graphics.print(team,400,20*i)
        end
    end
end)

drawStateSwitch:addCase("editing message",function()
    drawButtons(2)
    if editingText        then love.graphics.print(editingText,50,400) end
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
    love.graphics.setColor(0.5,0.5,0.5)
    love.graphics.rectangle("fill",200,200,400,300)
    love.graphics.setColor(1,1,1)
    drawButtons(2)
end)

drawStateSwitch:addCase("lobby pause screen",function()
    love.graphics.setColor(1,1,1)
    drawButtons(2)
end)

--============================================================================================--
--============================================================================================--

--Send a message to players, relays this message to other players as the server
netSwitch:addCase("msg",function(args)
    local splitData = Util:split(args,"_")
    local sender    = splitData[1]
    local message   = splitData[2]

    if server then server:send("all","msg:"..sender.."_"..message.."_\n") end

    newMessage(sender,message)
end)

netSwitch:addCase("kick",function(args)
    if not player then return end
    local splitData = Util:split(args,"_")
    local playerID  = splitData[1]

    player:send("econ:"..playerID.."_\n")

end)

--New connection, sends initial information about the player
netSwitch:addCase("ncon",function(args)
    if server then
        print("new connection")
        local splitData = Util:split(args,"_")

        local ID   = splitData[1]
        local name = splitData[2]

        print("confirmed connection")
        LobbyPlayer:new(ID)
        LobbyPlayer:setName(ID,name)
        LobbyPlayer:setReady(ID,false)
        LobbyPlayer:setInLobby(ID,true)
        LobbyPlayer:setTeam(ID,"team 1")
        
        local y = #LobbyPlayer:getIDs() * 20
        local nButton   = newButton(1,"kick",{1,1,1},450,y,500, y + 17.5)

        nButton.command = function()
            server:send("all","kick:"..ID.."_\n")
            removeButton(1,nButton)
        end

        server:send("all","ncon:"..ID.."_"..name.."_confirm_\n")
    end

    if player then
        local splitData = Util:split(args,"_")

        local ID   = splitData[1]
        local name = splitData[2]
        local conf = splitData[3]

        if conf == "confirm" and ID == player.ID then
            --On confirmation, make a LobbyPlayer object with player's details
            LobbyPlayer:clear()
            LobbyPlayer:new(player.ID)
            LobbyPlayer:setName(player.ID,player.name)
            LobbyPlayer:setReady(player.ID,false)
            LobbyPlayer:setInLobby(player.ID,true)
            LobbyPlayer:setTeam(player.ID,"team 1")
            if getState(1) == "connecting to lobby" then
                lState[1]  = nil
                state[1]   = "in lobby"
            end
        end
    end
end)

--End connection with main server
netSwitch:addCase("econ",function(args)
    print("econ:",args)
    if server then
        local splitData = Util:split(args,"_")
        local ID        = splitData[1]
        server:send("all","econ:"..ID.."_".."false".."_\n")
        table.insert(toRemoveIDs,ID)
    elseif player then
        local splitData = Util:split(args,"_")
        local playerID  = splitData[1]
        local isMain    = splitData[2]

        if playerID    == player.ID then
            toClosePlayer = false

            if Util:toBool(isMain) then
                
            else
                state[1]      = "searching for lobby"
                toConnectMain = true
            end
            lState[2] = nil
            state[2]  = nil
            lState[1] = nil

            JoinableLobby:clear()
            LobbyPlayer:clear()

            clearMessages()
        else
            table.insert(toRemoveIDs,playerID)
        end
    end
end)

--Update player info, for when player changes ready state or name
netSwitch:addCase("updt",function(args)
    local splitData = Util:split(args,"_")
    --sender ID
    local ID    = splitData[1]
    local field = splitData[2]
    local value = splitData[3]

    if not LobbyPlayer:getName(ID) then LobbyPlayer:new(ID) end

    if field     == "name"         then LobbyPlayer:setName(ID,value)
    elseif field == "ready"        then LobbyPlayer:setReady(ID,value)
    elseif field == "in lobby"     then LobbyPlayer:setInLobby(ID,value)
    elseif field == "team"         then LobbyPlayer:setTeam(ID,value)
    end
end)

--Request and confirm joining a new lobby
netSwitch:addCase("join",function(args)
    if not player then return end
    local splitData  = Util:split(args,"_")
    local ID   = splitData[1]
    local IP   = splitData[2]
    local port = splitData[3]

    if ID == player.ID then
        player:send("econ:"..player.ID.."_\n")
        toChangeState   = "connecting to lobby"
        tempTick        = 30

        local nPlayer   = Player:new(IP,port)
        nPlayer.name    = player.name
        nPlayer.ID      = player.ID

        toConnectPlayer = nPlayer
    end
end)

--Create a new lobby and confirm creation
netSwitch:addCase("create",function(args)
    if not player then return end
    local splitData   = Util:split(args,"_")

    local hostID      = splitData[1]
    local lobbyID     = splitData[2]
    local lobbyName   = splitData[3]
    local IP          = splitData[4]
    local port        = splitData[5]
    local maxPlayers  = splitData[6]

    if player.ID     == hostID then

        --Host has both a server and player object, player object is kept
        toChangeState = "hosting lobby"
        tempTick      = 30

        server        = Lobby:new(lobbyID,lobbyName,port,IP,player.ID,maxPlayers)

    end
end)

--Update lobby list
netSwitch:addCase("uplobs",function(args)
    if not player then return end

    local splitData   = Util:split(args,"_")

    local lobbyID     = splitData[1]
    local lobbyName   = splitData[2]
    local hostName    = splitData[3]
    local IP          = splitData[4]
    local port        = splitData[5]
    local playerCount = splitData[6]
    local maxPlayers  = splitData[7]

    if not JoinableLobby:has(lobbyID) then

        JoinableLobby:new(lobbyID)
        JoinableLobby:setName(lobbyID,lobbyName)
        JoinableLobby:setHostName(lobbyID,hostName)
        JoinableLobby:setIP(lobbyID,IP)
        JoinableLobby:setPort(lobbyID,port)
        JoinableLobby:setPlayerCount(lobbyID,playerCount)
        JoinableLobby:setMaxPlayers(lobbyID,8)

        local y = #JoinableLobby.IDTable * 40
        local nButton = newButton(1,"lobby name: "..lobbyName.." host name: "..hostName.." count: "..playerCount.."/"..maxPlayers,{1,1,1},100,100 + y,700,135 + y,function()
            player:join(lobbyID)
        end)
        LobbyButton:new(lobbyID,nButton)
    else
        JoinableLobby:setPlayerCount(lobbyID, playerCount)
        local button = LobbyButton:setText(lobbyID,"lobby name: "..lobbyName.." host name: "..hostName.." count: "..playerCount.."/"..maxPlayers)
    end
end)

--Start a new game
netSwitch:addCase("start",function(args)
    if not player then return end
    --Remove any graphics from menus, eg pause menu
    state[2]  = nil
    lState[2] = nil
    state[1]  = "in game"
    lState[1] = nil
    order     = 1
    LobbyPlayer:setInLobby(player.ID,false)
    player:send("updt:"..player.ID.."_in lobby_false".."_\n")
    --Clears all existing balls
    World:clear()
end)

--Asign ball ID to a player
netSwitch:addCase("asgn",function(args)
    if not player then return end

    local splitData = Util:split(args)

    for i = 1,#splitData / 2 do
        local playerID = splitData[i*2-1]
        local ballID   = splitData[i*2]
        if player.ID         == playerID then
            player.ballID     = ballID
        end
    end
end)

--Take player input from clients
netSwitch:addCase("plin",function(args)
    if not server then return end

    local splitData = Util:split(args,"_")

    local ID        = splitData[1]
    local x         = splitData[2]
    local y         = splitData[3]

    local ballID    = LobbyPlayer:getBallID(ID)
    local ball      = World:getByID(ballID)

    applyMove(ball,x,y)
end)

--Update gamestate
netSwitch:addCase("upgm",function(args)
    if not player then return end

    local splitData = Util:split(args,"_")
    --Changes = {{ID1,x1,y1},{ID2,x2,y2},{ID3,x3,y3}}
    local changes   = {}

    for i,msg in ipairs(splitData) do
        local ind   = i - 1
        if changes[math.floor(ind/3)+1] == nil then
            changes[math.floor(ind/3)+1] = {}
        end
        changes[math.floor(ind/3)+1][(ind%3) + 1] = msg
    end

    for i, change in ipairs(changes) do
        local ID        = change[1]
        local ascX      = change[2]
        local ascY      = change[3]
        if ID and ascX and ascY then
            local ball  = World:getByID(ID)
            local x,y   = Util:HexToCoord(ascX,ascY)
            if ball then
                ball.x  = x
                ball.lx = x
                ball.y  = y
                ball.ly = y
            else
                local nball = World:newBall(x,y,true)
                World:assignID(nball,ID,0)
            end
        end
    end
end)

--End game and display the end screen
netSwitch:addCase("endgm",function(args)
    local splitData   = Util:split(args,"_")
    local winningTeam = ""
    local maxScore    = 0
    for i = 1,#splitData/2 do
        local team  = splitData[2*1-1]
        local score = tonumber(splitData[2*i])
        if score and score > maxScore then
            maxScore     = score
            winningTeam  = team
        end
    end
    state[2]  = "end screen"
    lState[2] = nil
    order     = 2
    newMessage("server","The winner is: "..winningTeam.." with "..maxScore.." points")
end)

--============================================================================================--
--============================================================================================--

--Handles keyboard inputs for writing text
function love.textinput(t)
    if not editingText then return end
    if not player      then return end
    if t == nil or t == ":" or t == "_" then return end

    --Adds text at the editing index and incriments the index
    editingText  = string.sub(editingText,1,editingIndex-1)..t..string.sub(editingText,editingIndex,#editingText)
    editingIndex = editingIndex + 1
end

--Handle keyboard inputs
function love.keypressed(key)
    if editingText and player then
        if key == "escape"    then
            state[order]  = nil
            lState[order] = nil
            order         = order - 1
            editingText   = nil
        
        elseif key == "return" then
            if getState(2)     == "editing player name" then changePlayerName()
            elseif getState(2) == "editing message"     then sendMessage()
            elseif getState(4) == "editing lobby name"  then changeLobbyName()
            end
        
        elseif key == "delete" then
            --Delete everything after the index when ctrl + delete
            if love.keyboard.isDown("lctrl") or love.keyboard.isDown("rctrl") then
                editingText  = string.sub(editingText,1,editingIndex-1)

            --Deletes the text at the editing index
            elseif editingIndex <= #editingText then
                editingText  = string.sub(editingText,1,editingIndex-1)..string.sub(editingText,editingIndex+1,#editingText)
            end

        elseif key == "backspace" then
            --Delete everything before the index when ctrl + backspace
            if love.keyboard.isDown("lctrl") or love.keyboard.isDown("rctrl") then
                editingText  = string.sub(editingText,editingIndex,#editingText)
                editingIndex = 1

            --Deletes the text before the editing index and decriments the index
            elseif editingIndex > 1 then
                editingText  = string.sub(editingText,1,editingIndex-2)..string.sub(editingText,editingIndex,#editingText)
                editingIndex = editingIndex - 1
            end

            --Move the index left or right until there is no space left
        elseif key == "left"    then
            if editingIndex > 1 then 
                editingIndex = editingIndex - 1
            end

        elseif key == "right" then
            if editingIndex < #editingText + 1 then
                editingIndex = editingIndex + 1
            end
        
        end
    
    elseif key == "escape" then
        --If in an offline state
        if not inLobby() and state[1] ~= "end screen" then
            --If in a menu, esc closes that menu
            if order > 1   then
                state[order]  = nil
                lState[order] = nil
                order         = order - 1

            --If not in a menu, esc opens options
            else
                order         = 2
                lState[2]     = nil
                state[2]      = "user settings"
            end
        --If in and online state
        else
            if order > 1 then
                state[order]  = nil
                lState[order] = nil
                order         = order - 1
            else
                order         = 2
                lState[2]     = nil
                state[2]      = "lobby pause screen"
            end
        end
    elseif key == "t" and inLobby() and state[2] ~= "end screen" then
        lState[2] = nil
        state[2]  = "editing message"
        order     = 2
    end
end

function love.quit()
    --return true to prevent quitting?
    if player then
        player:send("econ:"..player.ID.."_\n")
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
        nState   = getNewState()
    end

    for i = 1,maxOrder do
        stateSwitch:case(getState(i),dt)
    end

    if toClosePlayer   then
        player          = nil
        toClosePlayer   = false
    end

    if toConnectPlayer then
        player          = toConnectPlayer
        toConnectPlayer = nil
    end

    if toConnectMain and player then
        player:connectToMain()
        toConnectMain   = false
    end

    --Allows for delays in changing state
    if toChangeState and tempTick == 1 then
        lState[1]     = nil
        state[1]      = toChangeState
        state[2]      = nil
        state[3]      = nil
        toChangeState = nil
        order         = 1
    end

    for i,ID in ipairs(toRemoveIDs) do
        LobbyPlayer:removeID(ID)
    end

    tick = tick + 1
    if tempTick > 0    then tempTick = tempTick - 1 end
end

--Draw each frame
function love.draw()
    for i = 1,maxOrder do
        drawStateSwitch:case(getState(i))
    end
end

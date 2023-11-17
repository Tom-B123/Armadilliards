require("lists")
require("switch")
require("button")
require("net")

local player = nil
local server = nil

--Long and Short ID, for on main server and small lobbies?

local canQuit = false
local tick = 0

local messageLog = {}

local buttons = {}

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

local function calculateID(length)
    local seed = Socket.gettime() * 10000
    math.randomseed(seed)
    return tostring(math.random(0,10^length - 1))
end

local function newMessage(message)
    table.insert(messageLog,message)
end

local function drawMessages()
    for i,message in ipairs(messageLog) do
        local topPos = 500 - #messageLog * 20
        love.graphics.print(message,100,topPos + i*20)
    end
end

local function clearMessages()
    messageLog = {}
end

local function updateButtons()
    for i,button in ipairs(buttons) do
        button:update()
    end
end

local function drawButtons()
    for i,button in ipairs(buttons) do
        button:draw()
    end
end

local function newButton(text,colour,x1,y1,x2,y2,command,params)
    local nButton = Button:new(text,colour,0,x1,y1,x2,y2,command,params)
    table.insert(buttons,nButton)
end

local function clearButtons()
    buttons = {}
end

local function drawLobbies(offset)
    for i, ID in ipairs(JoinableLobby.lobbies) do
        local lobby = JoinableLobby.lobbiesDict[ID]
        local hostName = LobbyPlayer:getName(lobby.hostID)
        love.graphics.print(lobby.name.." "..lobby.ID.." "..hostName,100,i*20 + 100 + offset)
    end
end

local tempState = nil
local state = "main menu"
local lState = nil

local function getNewState()
    if state ~= lState then return state end
end

local function getState()
    return state
end

--To run every frame a state is active.
local stateSwitch = Switch:new()
--To run the first frame a state is active
local newStateSwitch = Switch:new()
--To draw every frame a state is active.
local drawStateSwitch = Switch:new()
--Convert message to function
local netSwitch = Switch:new()

local function processReceived()
    local data
    if server then
        data = server:receive("all")
    elseif player then
        data = {player:receive()}
    end
    for i,message in ipairs(data) do
        if message ~= "no dat" then print(message) end
        local splitData = split(message,":")
        local key,args = splitData[1],splitData[2]
        netSwitch:case(key,args)
    end
end

--Adding cases to the switch statements
stateSwitch:addCase("hosting main",function()
    if server and tick % 2 == 0 then
        server:update()
    end
    if server then
        server:send("all","no dat")
        processReceived()
    end
end)

stateSwitch:addCase("searching for lobby",function()
    if player then
        processReceived()
        player:send("no dat")
    end
end)

stateSwitch:addCase("lobby settings",function()
    if player then
        processReceived()
        player:send("no dat")
    end
end)

newStateSwitch:addCase("main menu",function()
    clearButtons()
    print("menu")
    newButton("click to start",{1,1,1},100,300,300,350,function()
        state = "gamemode select"
    end)
    lState = state
end)

newStateSwitch:addCase("gamemode select",function()
    clearButtons()
    print("gamemode select")
    newButton("multiplayer",{1,1,1},100,300,300,350,function()
        state = "connecting to server"
    end)
    newButton("settings",{1,1,1},100,375,300,425,function()
        tempState = state
        state = "settings"
    end)
    newButton("back",{1,1,1},100,450,300,500,function()
        state = "main menu"
    end)
    lState = state
end)


newStateSwitch:addCase("connecting to server",function()
    clearButtons()
    print("connecting to server")
    local nPlayer = Player:tryConnect()
    if not nPlayer then
        lState = "connecting to server"
        state = "hosting main"
        server = Lobby:hostMain()
    else
        lState = "connecting to server"
        state = "searching for lobby"

        player = nPlayer
        player.ID = calculateID(8)
        player:send("ncon:"..player.ID.."_"..player.name)
    end
end)

newStateSwitch:addCase("hosting main",function()
    clearButtons()
    if server then
        print("hosting main")
        newButton("close main server",{1,0,0},50,50,750,250,function()
            state = "gamemode select"
            server:close()
        end)
        lState = "hosting main"
    else
        lState = "connecting to server"
        state = "connection error"
    end
end)

newStateSwitch:addCase("connection error",function()
    clearButtons()
    print("connection error")
    newButton("retry",{1,1,1},100,375,300,425,function()
        state = "connecting to server"
    end)
    newButton("back",{1,1,1},100,450,300,500,function()
        state = "gamemode select"
    end)
    lState = state
end)

newStateSwitch:addCase("settings",function()
    clearButtons()
    print("settings")
    newButton("configure settings",{1,1,1},100,325,300,375,function()
        --Settings for the player to alter
        print("configuring settings")
    end)
    newButton("back",{1,1,1},100,400,300,450,function()
        if tempState then state = tempState end
    end)
    newButton("quit",{1,1,1},100,475,300,525,function()
        love.event.quit()
    end)
    lState = state
end)

newStateSwitch:addCase("searching for lobby",function()
    clearButtons()
    print("searching for lobby")
    newButton("player name",{1,1,1},100,25,300,75,function()
        --Edit player name
        print("editing player name")
    end)
    newButton("Create new lobby",{1,1,1},100,150,300,200,function()
        state = "lobby settings"
    end)
    newButton("back",{1,1,1},100,225,300,275,function()
        if player then
            --End connection with main server
            player:send("econ:"..player.ID)
        end
    end)
    lState = state
end)

newStateSwitch:addCase("lobby settings",function()
    clearButtons()
    print("lobby settings")
    newButton("back",{1,1,1},100,25,300,75,function()
        state = "searching for lobby"
    end)
    newButton("Lobby settings",{1,1,1},100,150,300,200,function()
        --Settings for the lobby, eg max player count
        print("editing lobby settings")
    end)
    newButton("Create",{1,1,1},100,225,300,275,function()
        if player then
            player:send("create:"..player.ID.."_new server_server IP_server port_8")
        end
    end)
    lState = state
end)

drawStateSwitch:addCase("main menu",function()
    love.graphics.print("This is the main menu",100,100)
    drawButtons()
end)

drawStateSwitch:addCase("gamemode select",function()
    love.graphics.print("Leaderboard",100,100)
    drawButtons()
end)

drawStateSwitch:addCase("connecting to server",function()
    drawButtons()
end)

drawStateSwitch:addCase("connection error",function()
    drawButtons()
    love.graphics.print("connection error",100,100)
end)

drawStateSwitch:addCase("hosting main",function()
    drawMessages()
    drawButtons()
    love.graphics.setColor(1,1,1)
    love.graphics.print("You are now the main host",100,500)
    if server then
        love.graphics.print("player Count: "..server.playerCount,50,400)
    end
end)

drawStateSwitch:addCase("settings",function()
    drawButtons()
end)

drawStateSwitch:addCase("searching for lobby",function()
    love.graphics.print("Lobbies list",100,100)
    drawLobbies(0)
    drawMessages()
    drawButtons()
end)

drawStateSwitch:addCase("lobby settings",function()
    drawButtons()
end)

netSwitch:addCase("msg",function(args)
    newMessage(args)
end)

netSwitch:addCase("ncon",function(args)
    if server then
        local splitData = split(args,"_")

        local ID = splitData[1]
        local name = splitData[2]

        print("new connection of ID: "..ID.." and name: "..name)

        LobbyPlayer:new(ID)
        LobbyPlayer:setName(ID,name)
        LobbyPlayer:setReady(ID,false)
        --automatically assigned team set here
        LobbyPlayer:setTeam(ID,"team 1")

        server:send("all","ncon:"..ID.."_"..name.."_confirm")

    elseif player then
        local splitData = split(args,"_")

        local ID, name, conf = splitData[1],splitData[2],splitData[3]

        if conf == "confirm" then

            LobbyPlayer:new(ID)
            LobbyPlayer:setName(ID,name)
            LobbyPlayer:setReady(ID,false)
            --automatically assigned team set here
            LobbyPlayer:setTeam(ID,"team 1")

            if ID == player.ID then
                print("confirmed connection")
            else
                newMessage("a new player has connected to the main server")
            end
        end
    end
end)

netSwitch:addCase("econ",function(args)
    if server then
        local ID = args
        server:send("all","econ:"..ID)
        --end the connection with client
        LobbyPlayer:removeID(ID)
    elseif player then
        local ID = args
        if ID == player.ID then
            print("confirmed end connection")
            player:close()
            state = "gamemode select"
        else
            newMessage("a player has left the main server")
        end
    end
end)

netSwitch:addCase("updt",function(args)
    local splitData = split(args,"_")
    --sender ID
    local ID = splitData[1]
    local field = splitData[2]
    local value = splitData[3]

    if field == "name" then LobbyPlayer:setName(ID,value)
    elseif field == "ready" then LobbyPlayer:setReady(ID,value)
    elseif field == "team" then LobbyPlayer:setTeam(ID,value)
    end
end)

netSwitch:addCase("join",function(args)
    if server then
        local splitData = split(args,"_")
        local lobbyID, playerID = splitData[1], splitData[2]
        --get info from lobby ID and send data to the player
    elseif player then
        --Connect to the hosted lobby server
    end
end)

netSwitch:addCase("create",function(args)
    if server then
        local splitData = split(args,"_")
        local hostID, lobbyName, IP, port, maxPlayers = 
        splitData[1], splitData[2], splitData[3], splitData[4], splitData[5]
        --Make a new joinable lobby object in the lobbies list, calculating a lobby ID
        server:send("all","create:"..hostID.."_"..lobbyName.."_"..IP.."_"..port.."_"..maxPlayers)
    elseif player then
        local splitData = split(args,"_")
        local hostID, lobbyName, IP, port, maxPlayers = 
        splitData[1], splitData[2], splitData[3], splitData[4], splitData[5]

        if player.ID == hostID then state = "searching for lobbies" end

        local splitData = split(args,"_")
        local hostID, lobbyID, conf = 
        splitData[1], splitData[2], splitData[3]
        if conf and hostID == player.ID then
            --create a hosted lobby object and host a server
        end
    end
end)

--Handle keyboard inputs
function love.keypressed(key)
    if key == "escape" then
        tempState = state
        state = "settings"
    end

    if state == "main menu" then
        state = "gamemode select"
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

--Process each frame
function love.update()

    local IDs = LobbyPlayer:getIDs()

    updateButtons()

    --Loop through all state changes this frame
    local nState = getNewState()
    while nState do
        newStateSwitch:case(nState)
        nState = getNewState()
    end

    stateSwitch:case(getState())

    tick = tick + 1
end

--Draw each frame
function love.draw()
    drawStateSwitch:case(getState())
    love.graphics.setColor(1,1,1)
    love.graphics.print(state)
end
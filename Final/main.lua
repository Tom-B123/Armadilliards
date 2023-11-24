require("lists")
require("switch")
require("button")
require("net")

local player = nil
local toClosePlayer = false
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
--Order of states, used to stack menues ontop of eachother whilst the buttons and data of lower
--order states is preserved.
local order = 1
--Stores all buttons within tables, corresponding to their order.
local buttons = {}

--hardcoded limit on orders
for i = 1,3 do
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
        local topPos = 550 - #messageLog * 20
        love.graphics.print(message,600,topPos + i*20)
    end
end

local function clearMessages()
    messageLog = {}
end

local function drawLobbies(offset)
    for i, ID in ipairs(JoinableLobby.lobbies) do
        local lobby = JoinableLobby.lobbiesDict[ID]
        local hostName = LobbyPlayer:getName(lobby.hostID)
        love.graphics.print(lobby.name.." "..lobby.ID.." "..hostName,100,i*20 + 100 + offset)
    end
end

local function validKey(key)
    if key == "space" then return " " end
    if #key > 1 then
        return nil
    end
    local asc = string.byte(key)
    if (48 <= asc and asc <= 57) or (97 <= asc and asc <= 122) then
        return key
    end
end

--Only update active buttons
local function updateButtons()
    for i,button in ipairs(buttons[order]) do
        button:update()
    end
end

local function drawButtons(ord)
    --draws buttons of a specific order
    for j,button in ipairs(buttons[ord]) do
        button:draw()
    end
end

local function newButton(ord,text,colour,x1,y1,x2,y2,command,params)
    local nButton = Button:new(text,colour,0,x1,y1,x2,y2,command,params)
    table.insert(buttons[ord],nButton)
end

local function clearButtons()
    buttons[order] = {}
end

local playerNameButton

local function getNewState()
    if state[order] ~= lState[order] then return state[order] end
end

local function getState(ord)
    return state[ord]
end

local function changePlayerName()
    if editingText == "" then editingText = "new player" end
    if not player then return end
    player.name = editingText
    editingText = nil
    state[2] = nil
    lState[2] = nil
    order = 1
    player:send("updt:"..player.ID.."_name_"..player.name)
end

local function processReceived()
    local function process(data)
        for i,message in ipairs(data) do
            local splitData = split(message,":")
            local key,args = splitData[1],splitData[2]
            local sArgs = args
            if sArgs == nil then sArgs = " " end
            if key ~= "no dat" then 
                print("newSwitch:Case("..key..","..sArgs..")")
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
        if tick % 120 == 0 then
            player:send("uplobs:")
        end
    end
end)

newStateSwitch:addCase("main menu",function()
    clearButtons()
    print("menu")
    newButton(1,"click to start",{1,1,1},300,300,500,350,function()
        state[1] = "gamemode select"
    end)
    lState[1] = state[1]
end)

newStateSwitch:addCase("gamemode select",function()
    clearButtons()
    print("gamemode select")
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
    print("connecting to server")
    local nPlayer = Player:tryConnect()
    if not nPlayer then
        lState[1] = "connecting to server"
        state[1] = "hosting main"
        server = Lobby:hostMain()
    else
        lState[1] = "connecting to server"
        state[1] = "searching for lobby"

        player = nPlayer
        player.ID = calculateID(8)
        player:send("ncon:"..player.ID.."_"..player.name)
        print("sending nCon")
    end
end)

newStateSwitch:addCase("hosting main",function()
    clearButtons()
    if server then
        print("hosting main")
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
    print("user settings")
    newButton(2,"configure settings",{1,1,1},300,300,500,350,function()
        order = 3
        state[3] = "configure game settings"
        lState[3] = nil
    end)
    newButton(order,"back",{1,1,1},300,375,500,425,function()
        --arbitrary values so user settings can open above any menu
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
    newButton(order,"back",{1,1,1},300,375,500,425,function()
        --arbitrary values so user settings can open above any menu
        state[order] = nil
        lState[order] = nil
        order = order - 1
    end)
    lState[order] = state[order]
end)

newStateSwitch:addCase("searching for lobby",function()
    clearButtons()
    print("searching for lobby")
    if player then
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
                --End connection with main server
            player:send("econ:"..player.ID)
        end)
    end
    lState[1] = state[1]
end)

newStateSwitch:addCase("editing player name",function()
    clearButtons()
    if player then
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
    end
    lState[2] = state[2]
end)

newStateSwitch:addCase("lobby creation",function()
    clearButtons()
    print("lobby creation")
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
        if player then
            player:send("create:"..player.ID.."_new server_server IP_server port_8")
        end
    end)
    lState[2] = state[2]
end)

newStateSwitch:addCase("lobby settings",function()
    clearButtons()
    print("lobby settings")
    newButton(3,"back",{1,1,1},300,300,500,350,function()
        state[3] = nil
        lState[3] = nil
        order = 2
    end)
    lState[3] = state[3]
end)

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
    drawMessages()
    drawButtons(1)
    love.graphics.setColor(1,1,1)
    love.graphics.print("You are now the main host",300,500)
    if server then
        love.graphics.print("player Count: "..server.playerCount,300,400)
    end
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
    drawMessages()
    drawButtons(1)
    --Drawing the player name onto the edit player name button
    if player then
        local playerNameText
        if editingText then playerNameText = editingText
        else playerNameText = player.name end
        if playerNameText then love.graphics.print(playerNameText,300,25) end
    end
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
end)

netSwitch:addCase("msg",function(args)
    newMessage(args)
end)

netSwitch:addCase("ncon",function(args)
    if server then
        local splitData = split(args,"_")

        local ID = splitData[1]
        local name = splitData[2]

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

            if ID == player.ID then
                print("confirmed connection")
                LobbyPlayer:new(ID)
                LobbyPlayer:setName(ID,name)
                LobbyPlayer:setReady(ID,false)
                --automatically assigned team set here
                LobbyPlayer:setTeam(ID,"team 1")

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
        --LobbyPlayer:removeID(ID)
    elseif player then
        local ID = args
        if ID == player.ID then
            print("confirmed end of connection")
            toClosePlayer = false
            state[1] = "gamemode select"
            lState[1] = nil
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
    print(field.." to "..value)
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
        
        local nLobby = JoinableLobby:new(lobbyName,hostID,IP,port,nil,0,maxPlayers)
        
        server:send("all","create:"..hostID.."_"..nLobby.ID.."_"..IP.."_"..port.."_"..maxPlayers)
    elseif player then
        local splitData = split(args,"_")
        local hostID, lobbyID, IP, port, maxPlayers = 
        splitData[1], splitData[2], splitData[3], splitData[4], splitData[5]

        --Host a new joinable server

        if player.ID == hostID then
            state[1] = "searching for lobby"
            state[2] = nil
            lState[2] = nil
            order = 1
        end
    end
end)

netSwitch:addCase("uplobs",function(args)
    if server then
        for i,ID in ipairs(JoinableLobby.lobbies) do
            local lobby = JoinableLobby.lobbiesDict[ID]
            local hostName = LobbyPlayer:getName(lobby.hostID)
            server:send("all","uplobs:"..lobby.name.."_"..hostName.."_"..lobby.hostID.."_"..
            lobby.IP.."_"..lobby.port.."_"..lobby.ID.."_"..lobby.playerCount.."_"..lobby.maxPlayers)
        end
    elseif player then
        local splitData = split(args,"_")
        local lobbyName, hostName, hostID, IP, port, lobbyID, playerCount, maxPlayers = 
        splitData[1], splitData[2], splitData[3], splitData[4], splitData[5], splitData[6], splitData[7], splitData[8]

        --Sets the player name to display, as it may not be known
        if not LobbyPlayer:getName(hostID) then
            LobbyPlayer:new(hostID)
            LobbyPlayer:setName(hostID,hostName)
        end

        --Adds and updates the info to display for the lobby
        if not JoinableLobby.lobbiesDict[lobbyID] then
            JoinableLobby:new(lobbyName,hostID,IP,port,lobbyID,playerCount,8)
            local y = #JoinableLobby.lobbies * 40
            newButton(1,"lobby name: "..lobbyName.." host name: "..hostName.." count: "..playerCount.."/"..maxPlayers,{1,1,1},100,100 + y,700,135 + y,function()
                print(lobbyName..hostID..IP..port..lobbyID..playerCount)
            end)
        else
            JoinableLobby.lobbiesDict[lobbyID].playerCount = playerCount
        end
    end
end)

function love.textinput(t)
    if editingText and player then
        if t ~= nil then
            --Adds text at the editing index and incriments the index
            editingText = string.sub(editingText,1,editingIndex-1)..t..string.sub(editingText,editingIndex,#editingText)
            editingIndex = editingIndex + 1
        end
    end
end

--Handle keyboard inputs
function love.keypressed(key)
    if editingText and player then
        if key == "escape" then
            state[2] = nil
            lState[2] = nil
            order = 1
            editingText = nil
        elseif key == "return" then
            changePlayerName()
        elseif key == "delete" and editingText then
            --Delete everything after the index when ctrl + delete
            if love.keyboard.isDown("lctrl") or love.keyboard.isDown("rctrl") then
                editingText = string.sub(editingText,1,editingIndex-1)
            --Deletes the text at the editing index
            elseif editingIndex <= #editingText then
                editingText = string.sub(editingText,1,editingIndex-1)..string.sub(editingText,editingIndex+1,#editingText)
            end
        elseif key == "backspace" and editingText then
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
            if editingIndex > 1 then editingIndex = editingIndex - 1 end
        elseif key == "right" then
            if editingIndex < #editingText + 1 then editingIndex = editingIndex + 1 end
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
function love.update()

    if state[order] == nil then
        order = 1
    end

    local IDs = LobbyPlayer:getIDs()

    updateButtons()

    --Loop through all state changes this frame
    local nState = getNewState()
    while nState do
        newStateSwitch:case(nState)
        nState = getNewState()
    end

    for i = 1,3 do
        stateSwitch:case(getState(i))
    end

    if toClosePlayer then 
        player = nil
        toClosePlayer = false
    end

    tick = tick + 1
end

--Draw each frame
function love.draw()
    for i = 1,3 do
        drawStateSwitch:case(getState(i))
    end
    love.graphics.setColor(1,1,1)
    love.graphics.print(state[order])
end

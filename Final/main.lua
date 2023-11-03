require("lists")
require("switch")
require("button")
require("net")

local player = nil
local lobby = nil

local tick = 0

local messageLog = {}

local buttons = {}

local function newMessage(message)
    table.insert(messageLog,message)
end

local function drawMessages()
    if type(messageLog[1]) == "table" then
        for i,source in ipairs(messageLog) do
            for j,message in ipairs(source) do
                love.graphics.print(message,50 + j*100,i*20 + 400)
            end
        end
    else
        for i,message in ipairs(messageLog) do
            love.graphics.print(message,50,i*20 + 400)
        end
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

--Adding cases to the switch statements
stateSwitch:addCase("hosting main",function()
    if lobby and tick % 2 == 0 then
        lobby:update()
        lobby:send("all","welcome to the lobby!")
        
    end
    if lobby then
        local data = lobby:receive("all")
        if data then
            newMessage(data)
        end
    end
end)

stateSwitch:addCase("searching for lobby",function()
    if player then
        player:send("I am a player!")
        local data = player:receive()
        if data then newMessage(data) end
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
        --Connect to the lobby selection server
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
        lobby = Lobby:hostMain()
    else
        lState = "connecting to server"
        state = "searching for lobby"
        player = nPlayer
    end
end)

newStateSwitch:addCase("hosting main",function()
    clearButtons()
    if lobby then
        print("hosting main")
        newButton("close main server",{1,0,0},50,50,750,250,function()
            state = "gamemode select"
            lobby:close()
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
            player:close()
            player = nil
        end
        state = "gamemode select"
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
    drawButtons()
    love.graphics.setColor(1,1,1)
    love.graphics.print("You are now the main host",100,500)
    drawMessages()
    if lobby then
        love.graphics.print("player Count: "..lobby.playerCount,50,400)
    end
end)

drawStateSwitch:addCase("settings",function()
    drawButtons()
end)

drawStateSwitch:addCase("searching for lobby",function()
    love.graphics.print("Lobbies list",100,100)
    drawMessages()
    drawButtons()
end)

drawStateSwitch:addCase("lobby settings",function()
    drawButtons()
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

--Process each frame
function love.update()

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
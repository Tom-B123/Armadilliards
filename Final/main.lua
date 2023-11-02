require("lists")
require("switch")
require("button")
require("net")

local buttons = {}

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
stateSwitch:addCase("main menu",function()
end)

stateSwitch:addCase("gamemode select",function()
end)

newStateSwitch:addCase("main menu",function()
    clearButtons()
    print("change to menu")
    newButton("click to start",{1,1,1},100,300,300,350,function()
        state = "gamemode select"
    end)
    lState = state
end)

newStateSwitch:addCase("gamemode select",function()
    clearButtons()
    print("change to gamemode select")
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
    newButton("connecting",{1,1,1},100,100,200,200,function() end)
    local nPlayer = Player:tryConnect()
    if not nPlayer then
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
    print("change to settings")
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
    print("change to searching for lobby")
    newButton("player name",{1,1,1},100,25,300,75,function()
        --Edit player name
        print("editing player name")
    end)
    newButton("Create new lobby",{1,1,1},100,150,300,200,function()
        state = "lobby settings"
    end)
    newButton("back",{1,1,1},100,225,300,275,function()
        state = "gamemode select"
    end)
    lState = state
end)

newStateSwitch:addCase("lobby settings",function()
    clearButtons()
    print("change to lobby settings")
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
    love.graphics.print("connecting to server...",100,100)
end)

drawStateSwitch:addCase("connection error",function()
    drawButtons()
    love.graphics.print("connection error",100,100)
end)

drawStateSwitch:addCase("settings",function()
    drawButtons()
end)

drawStateSwitch:addCase("searching for lobby",function()
    love.graphics.print("Lobbies list",100,100)
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

    local nState = getNewState()
    while nState do
        newStateSwitch:case(nState)
        nState = getNewState()
    end

    stateSwitch:case(getState())
end

--Draw each frame
function love.draw()
    drawStateSwitch:case(getState())
    love.graphics.print(state)
end
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

local state = "main menu"
local lState = nil

local function getNewState()
    if state ~= lState then return state end
end

local function getState()
    return state
end

local stateSwitch = Switch:new()
local newStateSwitch = Switch:new()
local drawStateSwitch = Switch:new()

stateSwitch:addCase("main menu",function()
end)

stateSwitch:addCase("gamemode select",function()
end)

stateSwitch:addCase("paused",function()
end)

newStateSwitch:addCase("main menu",function()
    clearButtons()
    print("change to menu")
    newButton("click to start",{1,1,1},100,100,300,150,function()
        state = "gamemode select"
        
    end)
end)

newStateSwitch:addCase("gamemode select",function()
    clearButtons()
    print("change to gamemode select")
    newButton("click to pause",{1,1,1},100,300,300,350,function()
        state = "paused"
    end)
end)

newStateSwitch:addCase("paused",function()
    clearButtons()
    print("paused")
    newButton("click to unpause",{1,1,1},100,300,300,350,function()
        state = "gamemode select"
    end)
end)

drawStateSwitch:addCase("main menu",function()
    love.graphics.print("",100,100)
    drawButtons()
end)

drawStateSwitch:addCase("gamemode select",function()
    love.graphics.print("press space to pause",100,100)
    drawButtons()
end)

drawStateSwitch:addCase("paused",function() 
    love.graphics.print("press space to unpause",100,100)
    drawButtons()
end)

function love.keypressed(key)
    if key == "escape" then love.event.quit() end

    if state == "main menu" then
        state = "gamemode select"
    elseif key == "space" then
        if state == "gamemode select" then
            state = "paused"
        else
            state = "gamemode select"
        end
    end
end

function love.update()

    updateButtons()

    newStateSwitch:case(getNewState())

    stateSwitch:case(getState())
    
    lState = state
end

function love.draw()
    drawStateSwitch:case(getState())
    love.graphics.print(state)
end
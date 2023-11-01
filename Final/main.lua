require("lists")
require("switch")
require("button")
require("net")

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

newStateSwitch:addCase("main menu",function() 
    print("change to menu") 
end)

newStateSwitch:addCase("gamemode select",function() 
    print("change to gamemode") 
end)

newStateSwitch:addCase("paused",function() 
    print("paused") 
end)

drawStateSwitch:addCase("main menu",function()
    love.graphics.print("press any key to continue",100,100)
end)

drawStateSwitch:addCase("gamemode select",function()
    love.graphics.print("press space to pause",100,100)
end)

drawStateSwitch:addCase("paused",function() 
    love.graphics.print("press space to unpause",100,100)
end)

function love.keypressed(key)
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

    newStateSwitch:case(getNewState())

    stateSwitch:case(getState())
    
    lState = state
end

function love.draw()
    drawStateSwitch:case(getState())
    love.graphics.print(state)
end
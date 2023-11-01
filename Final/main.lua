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

stateSwitch:addCase("main menu",function() 
    print("menu") 
end)

stateSwitch:addCase("gamemode select",function() 
    print("gamemode") 
end)

local newStateSwitch = Switch:new()

newStateSwitch:addCase("main menu",function() 
    print("change to menu") 
end)

newStateSwitch:addCase("gamemode select",function() 
    print("change to gamemode") 
end)

newStateSwitch:addCase("paused",function() 
    print("paused") 
end)

local drawStateSwitch = Switch:new()

drawStateSwitch:addCase("main menu",function() 
    love.graphics.print("main menu graphics",100,100) 
end)

drawStateSwitch:addCase("gamemode select",function() 
    love.graphics.print("gamemode select graphics",100,100) 
end)

drawStateSwitch:addCase("paused",function() 
    love.graphics.print("paused graphics",100,100) 
end)

function love.keypressed(key)
    if state == "main menu" then
        state = "gamemode select"
    else
        state = "paused"
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
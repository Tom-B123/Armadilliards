require("lists")
require("switch")
require("button")
require("net")

local state = "main menu"
local lState = state

local function getNewState()
    if state ~= lState then return state end
end

local function getState()
    return state
end

local stateSwitch = Switch:new()
stateSwitch:addCase("main menu",function() print("menuuuuu") end)
stateSwitch:addCase("gamemode select",function() print("gamemooooooode") end)
function love.keypressed(key)
    state = "gamemode select"
end

function love.update()

end

function love.draw()
    love.graphics.print(state)
end
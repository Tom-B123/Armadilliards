require("lists")
require("switch")
require("button")
require("net")

local state = "main"
local lState = state

local function getNewState()
    if state ~= lState then return state end
end

local function getState()
    return state
end



function love.update()

end

function love.draw()
end
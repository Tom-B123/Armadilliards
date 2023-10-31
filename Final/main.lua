require("lists")
require("switch")

local switch = Switch:new()
switch:addCase("data",function() love.graphics.print("data") end)

function love.update()
end

function love.draw()
    switch:case("data")
end
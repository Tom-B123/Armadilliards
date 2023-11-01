require("lists")
require("switch")
require("button")
require("net")

local switch = Switch:new()
switch:addCase("data",function() love.graphics.print("data") end)

function love.update()
end

function love.draw()
    switch:case("data")
    love.graphics.print(root.val,0,root.val/10)
    root = root.prev
end
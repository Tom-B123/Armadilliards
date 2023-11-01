require("lists")
require("switch")
require("button")

local switch = Switch:new()
switch:addCase("data",function() love.graphics.print("data") end)

local root = Node:new(10)
local nRoot = root

for i = 2,100 do
    nRoot:add(root,i*10)
    nRoot = nRoot.next
end

function love.update()
end

function love.draw()
    switch:case("data")
    love.graphics.print(root.val,0,root.val/10)
    root = root.prev
end
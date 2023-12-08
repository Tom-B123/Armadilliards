local drawBall = {}

local tick = 0

local ind  = 0

local ball       = love.graphics.newImage("Assets/ball.png")
local blankSheet = love.graphics.newImage("Assets/blank.png")

local blankQuads = {}

for y = 0,3 do
    for x = 0,7 do
        local quad = love.graphics.newQuad(x*32,y*32,32,32,32*8,32*4)
        table.insert(blankQuads,quad)
    end
end

function drawBall:draw(r)
    love.graphics.setColor(math.sin(ind/10),math.cos(ind/5),math.sin(ind/17))
    love.graphics.draw(ball,100,100,0,2,2,16,16)
    love.graphics.setColor(1,1,1)
    love.graphics.draw(blankSheet,blankQuads[1+ind%32],100,100,0,2,2,16,16)
    tick = tick + 1
    if tick % 4 == 0 then
        ind  = ind  + 1
    end
end

return drawBall
local ballQuads = {}

local numberQuads = {}

local ballSheet = love.graphics.newImage("balls sheet.png")

local numberSheet = love.graphics.newImage("numbers sheet.png")

local teamBall = love.graphics.newImage("team ball.png")

local positions = {}

local angle = math.pi / 15

for i = 0,15 do
    positions[i] = -80*math.cos(angle*i) + 80 - 20
end

for i = 1,32 do
    local quad = love.graphics.newQuad((i-1)*32,0,32,32,ballSheet)
    ballQuads[#ballQuads+1] = quad
end

for i = 1,15 do
    local quad = love.graphics.newQuad((i-1)*32,0,32,32,numberSheet)
    numberQuads[#numberQuads+1] = quad
end

local tick = 0
local colour = {0,0,0}

function love.update()
    tick = tick + 1
    colour = {0,0,1}
end

function love.draw()
    love.graphics.setColor(colour)
    love.graphics.draw(teamBall,0,0,0,0.5,0.5)
    love.graphics.setColor(1,1,1)
    local i = (math.floor(tick / 2) % (15))+1
    love.graphics.draw(numberSheet,numberQuads[i],positions[i],80-16)
    
end
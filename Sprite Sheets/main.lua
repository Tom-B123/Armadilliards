local ballImages = {}



local spritesheet = love.graphics.newImage("balls sheet.png")

for i = 1,32 do
    local quad = love.graphics.newQuad((i-1)*32,0,32,32,spritesheet)
    ballImages[#ballImages+1] = quad
end

local tick = 0

function love.update()
    tick = tick + 1
end

function love.draw()
    love.graphics.draw(spritesheet,ballImages[(tick%32)+1])
end
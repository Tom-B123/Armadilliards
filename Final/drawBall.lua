local drawBall = {}

local blankSheet = love.graphics.newImage("Assets/blank.png")

function drawBall:draw()
    love.graphics.draw(blankSheet,100,100)
end

return drawBall
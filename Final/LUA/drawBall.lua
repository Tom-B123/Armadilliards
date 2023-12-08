local drawBall = {}

local ball       = love.graphics.newImage("Assets/ball.png")
local blankSheet = love.graphics.newImage("Assets/blank.png")

local blankQuads = {}

for y = 0,3 do
    for x = 0,7 do
        local quad = love.graphics.newQuad(x*32,y*32,32,32,32*8,32*4)
        table.insert(blankQuads,quad)
    end
end

function drawBall:draw(x,y,yaw,pitch,colour,scale,name)
    if not scale then scale = 1 end
    if not colour then colour = {1,1,1} end

    --Gets the corresponding sprite image based on the pitch angle of the ball.
    local imageIndex = math.floor(((pitch / (2 * math.pi) * 32) % 32)) + 1
    --Indexes the sprite image based on the stage of rotation
    --Draws the sprite at the x and y of the ball
    --Sets the sprite centre to be offset by 16px in x and y, representing the centre of the 32x32 images.
    --Rotates the sprite around the z axis by the yaw value.
    local function tryDraw()
        love.graphics.setColor(colour)
        love.graphics.draw(ball,x,y,yaw,scale,scale,16,16)
        love.graphics.setColor(1,1,1)
        love.graphics.print(name,x,y)
        love.graphics.draw(blankSheet,blankQuads[imageIndex],x,y,yaw,scale,scale,16,16)
    end
    pcall(tryDraw)
end

return drawBall
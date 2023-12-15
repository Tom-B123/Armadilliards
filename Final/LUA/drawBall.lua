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

local root2 = 2^0.5

function drawBall:draw(x,y,yaw,pitch,colour,scale,name,health,showCollisions,debugBall,radius)
    if not scale then scale = 1 end
    if not colour then colour = {1,1,1} end

    --Gets the corresponding sprite image based on the pitch angle of the ball.
    local imageIndex = math.floor(((pitch / (2 * math.pi) * 32) % 32)) + 1
    --Indexes the sprite image based on the stage of rotation
    --Draws the sprite at the x and y of the ball
    --Sets the sprite centre to be offset by 16px in x and y, representing the centre of the 32x32 images.
    --Rotates the sprite around the z axis by the yaw value.
    local function tryDraw()
        if showCollisions then
            love.graphics.setColor(1,0,0,0.5)
            love.graphics.polygon("fill",x + 32*root2,y,x,y + 32*root2,x - 32*root2,y,x,y - 32*root2)
            --Euclidian distance
            love.graphics.setColor(0,0,1,0.5)
            love.graphics.circle("fill",x,y,32)
        end
        if debugBall then
            love.graphics.circle(
                "line",
                x,
                y,
                radius
            )
        else
            love.graphics.setColor(colour)
            love.graphics.draw(ball,x,y,yaw,scale,scale,16,16)
        end
        love.graphics.setColor(1,1,1)
        if name then
            love.graphics.print(name,x - (4.5 * #name),y-32)
        end
        if health then
            love.graphics.print(health,x - (4.5 * #health),y+10)
        end
        love.graphics.draw(blankSheet,blankQuads[imageIndex],x,y,yaw,scale,scale,16,16)

        
    end
    pcall(tryDraw)
end

return drawBall
require("switch")
local drawBall = {}

local ball       = love.graphics.newImage("Assets/ball.png")
local blankSheet = love.graphics.newImage("Assets/blankSheet.png")
local bodySheet  = love.graphics.newImage("Assets/bodySheet.png")
local faceSheet  = love.graphics.newImage("Assets/faceSheet.png")

local imageQuads = {}

for y = 0,3 do
    for x = 0,7 do
        local quad = love.graphics.newQuad(x*32,y*32,32,32,32*8,32*4)
        table.insert(imageQuads,quad)
    end
end

local root2 = 2^0.5

local typeSwitch = Switch:new()

typeSwitch:addCase("debug",function(args)
    local x      = args[1]
    local y      = args[2]
    local radius = args[3]
    love.graphics.circle(
        "line",
        x,
        y,
        radius
    )
end)

typeSwitch:addCase("ball",function(args)
    local colour     = args[1]
    local x          = args[2]
    local y          = args[3]
    local yaw        = args[4]
    local scale      = args[5]
    local imageIndex = args[6]

    love.graphics.setColor(colour)
    love.graphics.draw(ball,x,y,yaw,scale,scale,16,16)
    love.graphics.setColor(1,1,1)
    love.graphics.draw(blankSheet,imageQuads[imageIndex],x,y,yaw,scale,scale,16,16)
end)

typeSwitch:addCase("armadillo",function(args)
    local colour     = args[1]
    local x          = args[2]
    local y          = args[3]
    local yaw        = args[4]
    local scale      = args[5]
    local imageIndex = args[6]

    love.graphics.setColor(colour)
    love.graphics.draw(bodySheet,imageQuads[imageIndex],x,y,yaw,scale,scale,16,16)
    love.graphics.setColor(1,1,1)
    love.graphics.draw(faceSheet,imageQuads[imageIndex],x,y,yaw,scale,scale,16,16)
end)

function drawBall:draw(x,y,yaw,pitch,colour,scale,name,health,showCollisions,style,radius)
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

        if style == "debug" then
            typeSwitch:case("debug",{x,y,radius})
        else
            typeSwitch:case(style,{colour,x,y,yaw,scale,imageIndex})
        end

        if style ~= debug then
            love.graphics.setColor(1,1,1)
            if name then
                love.graphics.print(name,x - (4.5 * #name),y-42)
            end
            if health then
                local ballHealth = health[1]
                local maxHealth  = health[2]
                love.graphics.setColor(0,1,0,0.2)
                love.graphics.rectangle("fill",x-30,y-28,60,10)
                love.graphics.setColor(0,1,0)
                love.graphics.rectangle("fill",x-30,y-28,60 * ballHealth / maxHealth,10)
                -- love.graphics.print(health,x - (4.5 * #health),y+10)
            end
        end
    end
    pcall(tryDraw)
end

return drawBall
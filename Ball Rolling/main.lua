
-- local balls = {}
-- local i = 0
-- local toDraw = {}
-- for i = 0,15 do
--     balls[i+1] = love.graphics.newImage("BlackBall"..i..".png")
-- end

-- local pos = {x=128,y=16}
-- function love.load()
-- end
-- function love.update()
--     i = i + 2
-- end
-- local function drawBall(roll,velocity,rotation)
--     roll = roll % 360
--     pos.x = pos.x + velocity * math.cos(rotation)
--     pos.y = pos.y + velocity * math.sin(rotation)
--     if 0 <= roll and roll < 90 then
--         love.graphics.draw(balls[math.floor(roll/5.625)+1],pos.x,pos.y,0+rotation,1,1,0,0)
--     end
--     if 90 <= roll and roll < 270 then
--         love.graphics.draw(balls[16],pos.x,pos.y,0+rotation,1,1,0,0)
--     end
--     if 270 <= roll and roll < 360 then
--         love.graphics.draw(balls[16 - math.floor((roll % 90)/5.625)],pos.x,pos.y,math.pi+rotation,1,1,32,32)
--     end
-- end
-- function love.draw()
--     drawBall(i*2,4,i * math.pi / 180)

local ballImages = {}

for i = 0,15 do
    ballImages[i+1] = love.graphics.newImage("BlackBall"..i..".png")
end

Ball = {}
Ball.__index = Ball

function Ball:new(x,y)
    local object = {}
    setmetatable(object,Ball)
    object.x = x
    object.y = y
    object.vx = 0
    object.vy = 0
    object.lx = x
    object.ly = y
    object.lvx = 0
    object.lvy = 0
    --rotation in the z axis
    object.yaw = 0
    --rotation stage of the ball
    object.pitch = 0
    return object
end

function Ball:draw()
    local imageIndex = (self.pitch % 32) + 1
    love.graphics.draw(ballImages[imageIndex],self.x,self.y)
end

local ball = Ball:new(100,100)

function love.draw()
    ball:draw()
end
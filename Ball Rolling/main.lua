
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

for i = 1,32 do
    ballImages[i] = love.graphics.newImage("ball ("..i..").png")
end

local function calcAngle(distance)
    local radius = 16
    local angle = distance / radius
    return angle
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
    local imageIndex = math.floor(((self.pitch / (2 * math.pi) * 32) % 32)) + 1
    local radYaw = self.yaw * 180 / math.pi
    love.graphics.draw(ballImages[imageIndex],self.x,self.y,radYaw,1,1,16,16)
    love.graphics.print("pitch: "..self.pitch.."\nyaw: "..self.yaw)
end

function Ball:verlet()
end

local ball = Ball:new(100,100)



function love.update()
    local v = 1
    ball.x = ball.x + v
    ball.pitch = ball.pitch + calcAngle(v)
end



function love.draw()
    for i = 1,30 do
        love.graphics.line(i*32,0,i*32,600)
    end
    for i = 1,20 do
        love.graphics.line(0,i*32,800,i*32)
    end
    ball:draw()
    
end
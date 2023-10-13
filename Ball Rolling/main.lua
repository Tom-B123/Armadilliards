
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

local function pitchAngle(distance)
    local radius = 16
    local angle = distance / radius
    return angle
end

local function yawAngle(x,y)
    if x >= 0 then
        return math.tan(y/x)
    else
        return -math.tan(y/x)
    end
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
    object.ax = 0
    object.ay = 0
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
    love.graphics.draw(ballImages[imageIndex],self.x,self.y,self.yaw,1,1,16,16)
    love.graphics.print("pitch: "..self.pitch.."\nyaw: "..self.yaw)
end

function Ball:move(x,y)
    self.x = self.x + x
    self.y = self.y + y
    local magnitude = (x^2 + y^2)^0.5
    self.pitch = self.pitch + pitchAngle(magnitude)
    self.yaw = yawAngle(self.vx,self.vy) 
end

function Ball:verlet(dt)
    local nextVX = (self.ax * dt * dt) + self.x - self.lx
    local nextVY = (self.ay * dt * dt) + self.y - self.ly

    self.vx = (self.vx + self.lvx) / 2
    self.vy = (self.vy + self.lvy) / 2

    local nextX = (self.x + self.vx)
    local nextY = (self.y + self.vy)

    self.lx = self.x
    self.ly = self.y

    self:move(self.vx,self.vy)

    self.lvx = self.vx * 0.99
    self.lvy = self.vy * 0.99

    self.vx = nextVX
    self.vy = nextVY

    self.ax = 0
    self.ay = 0

    if math.abs(self.vx) < 0.02 then self.vx = 0 end
    if math.abs(self.vy) < 0.02 then self.vy = 0 end
end

local ball = Ball:new(100,100)


function love.update(dt)
    ball:verlet(dt)
    local speed = 0.1
    if love.keyboard.isDown("w") then
        ball.vy = ball.vy - 1 * speed
    end
    if love.keyboard.isDown("a") then
        ball.vx = ball.vx - 1 * speed
    end
    if love.keyboard.isDown("s") then
        ball.vy = ball.vy + 1 * speed
    end
    if love.keyboard.isDown("d") then
        ball.vx = ball.vx + 1 * speed
    end
end



function love.draw()

    ball:draw()
    
end
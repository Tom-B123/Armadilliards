local porcupineImages = {}
local ballImages = {}

local mouseState = {false,false,false}

for i = 1,32 do
    porcupineImages[i] = love.graphics.newImage("porcupine ("..i..").png")
    ballImages[i] = love.graphics.newImage("ball ("..i..").png")
end

local function pitchAngle(distance,radius)
    local angle = distance / radius
    return angle
end

local function yawAngle(x,y)
    local ax,ay = math.abs(x),math.abs(y)
    if x > 0 and y >= 0 then
        return math.atan(ay/ax)
    elseif x <= 0 and y > 0 then
        return math.atan(ax/ay) + math.pi / 2
    elseif x < 0 and y <= 0 then
        return math.atan(ay/ax) + math.pi
    elseif x >= 0 and y < 0 then
        return math.atan(ax/ay) + math.pi * 3 / 2
    end
end

local ropes = {}

local balls = {}
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
    object.radius = 14
    object.model = "ball"
    object.team = "neutral"
    --rotation in the z axis
    object.yaw = 0
    --rotation stage of the ball
    object.pitch = 0
    return object
end

function Ball:draw()
    love.graphics.setColor(1,1,1)
    local images = {}
    if self.model == "ball" then
        images = ballImages
    else
        images = porcupineImages
    end

    --Gets the corresponding sprite image based on the pitch angle of the ball.
    local imageIndex = math.floor(((self.pitch / (2 * math.pi) * 32) % 32)) + 1
    --Indexes the sprite image based on the stage of rotation
    --Draws the sprite at the x and y of the ball
    --Sets the sprite centre to be offset by 16px in x and y, representing the centre of the 32x32 images.
    --Rotates the sprite around the z axis by the yaw value.
    local function tryDraw()
        love.graphics.setColor(0,0,0,0.4)

        if self.team == "team 1" then love.graphics.setColor(0,0,1,0.4) end

        love.graphics.circle("fill",self.x,self.y,self.radius + 4) 
        love.graphics.setColor(1,1,1)
        love.graphics.draw(images[imageIndex],self.x,self.y,self.yaw,1,1,16,16)
    end
    pcall(tryDraw)
end

function Ball:move(x,y)
    self.x = self.x + x
    self.y = self.y + y
    local magnitude = (x^2 + y^2)^0.5
    self.pitch = self.pitch + pitchAngle(magnitude,self.radius)
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

function Ball:constraint()
    if self.x < self.radius then
        self.x = self.radius
        self.vx = - self.vx
        self.lvx = - self.lvx
    end
    if self.y < self.radius then
        self.y = self.radius
        self.vy = - self.vy
        self.lvy = - self.lvy
    end
    if self.x > love.graphics.getWidth() - self.radius then
        self.x = love.graphics.getWidth() - self.radius
        self.vx = - self.vx
        self.lvx = - self.lvx
    end
    if self.y > love.graphics.getHeight() - self.radius then
        self.y = love.graphics.getHeight() - self.radius
        self.vy = - self.vy
        self.lvy = - self.lvy
    end
end

local count = 32
for i = 1,count do
    local speed = 5
    local ball = Ball:new(400,300)
    local angle = i / (count/2) * math.pi
    ball.vx = speed * math.cos(angle)
    ball.vy = speed * math.sin(angle)
    ball.x = ball.x + ball.vx * 10
    ball.y = ball.y + ball.vy * 10
    table.insert(balls,ball)
end

local playerBall = balls[1]
playerBall.model = "porcupine"
playerBall.team = "team 1"

local ropeObjects = {}
Rope = {}
Rope.__index = Rope

function Rope:new(source, target)
    local object = {}
    setmetatable(object,Rope)
    object.source = source
    object.tAngle = nil
    object.tLength = nil
    object.target = nil
    object.endX = 0
    object.endY = 0
    object.tAngle = target[1]
    object.tLength = target[2]
    
    return object

end

local function ropeLink(ball)
    for i,rope in ipairs(ropes) do
        if (rope[1] == playerBall and rope[2] == ball) or (rope[1] == ball and rope[2] == playerBall) then
            return
        end
    end
    local distanceToBall = math.max(((playerBall.x-ball.x)^2 + (playerBall.y-ball.y)^2)^0.5,64)
    table.insert(ropes,{playerBall,ball,distanceToBall})
end

function Rope:update()
    if self.target then
        --Code for when a specific target ball is given
    elseif self.tAngle and self.tLength then
        local dx = math.cos(self.tAngle) * self.tLength / 20
        local dy = math.sin(self.tAngle) * self.tLength / 20
        self.endX = self.endX + dx
        self.endY = self.endY + dy
        if ((self.endX)^2 + (self.endY)^2)^0.5 >= self.tLength then
            return true
        end
        local minDistance = 1000000
        local closestBall = nil
        local rx = self.endX + self.source.x
        local ry = self.endY + self.source.y
        for i,ball in ipairs(balls) do
            if ball ~= playerBall then
                local distance = ((rx - ball.x)^2 + (ry - ball.y)^2)^0.5
                if distance < minDistance then
                    minDistance = distance
                    closestBall = ball
                end
            end
        end
        if closestBall and minDistance < playerBall.radius then
            ropeLink(closestBall)
            return true
        end
    end
end

function Rope:draw()
    local ball = {x = self.source.x, y = self.source.y}
    love.graphics.setColor(1,1,0)
    love.graphics.line(ball.x,ball.y,ball.x + self.endX,ball.y + self.endY)
end

local bulletObjects = {}
Bullet = {}
Bullet.__index = Bullet

function Bullet:new(source,angle)
    local object = {}
    setmetatable(object,Bullet)
    object.x = source.x
    object.y = source.y
    object.radius = 4
    object.angle = angle
    object.distance = 0
    return object
end

local function bulletHit(object,fx,fy)
    object.vx = object.vx + fx
    object.vy = object.vy + fy
    object.lvx = object.lvx + fx
    object.lvy = object.lvy + fy
end

function Bullet:update()
    local speed = 10
    self.distance = self.distance + speed
    self.x = self.x + math.cos(self.angle) * speed
    self.y = self.y + math.sin(self.angle) * speed
    local minDistance = 1000000
    local closestBall = nil
    for i,ball in ipairs(balls) do
        if ball ~= playerBall then
            local distance = ((self.x - ball.x)^2 + (self.y - ball.y)^2)^0.5
            if distance < minDistance then
                minDistance = distance
                closestBall = ball
            end
        end
    end
    if closestBall and minDistance < playerBall.radius + self.radius then
        bulletHit(closestBall,speed * math.cos(self.angle), speed * math.sin(self.angle))
        return true
    end
    if self.distance == 300 then
        return true
    end
end

function Bullet:draw()
    love.graphics.setColor(1,0.5,0)
    love.graphics.circle("fill",self.x,self.y,self.radius)
end

local function verlet(objects,dt)
    for i,ball in ipairs(objects) do
        ball:verlet(dt)
    end
end

local function constraint(objects)
    for i,ball in ipairs(objects) do
        ball:constraint()
    end
end

local function expensiveCollisions(objects)
    local bounce = 1
    for i, obj1 in ipairs(objects) do
        for j, obj2 in ipairs(objects) do
            if i ~= j then
                local collisionAxis = {x=0,y=0}
                collisionAxis.x = obj1.x - obj2.x
                collisionAxis.y = obj1.y - obj2.y
                local distance = (collisionAxis.x^2 + collisionAxis.y^2) ^ 0.5
                local diameter = obj1.radius + obj2.radius
                if distance < diameter then
                    local n = collisionAxis
                    n.x = n.x / distance
                    n.y = n.y / distance
                    local delta = diameter - distance
                    local offset1 = obj2.radius / obj1.radius
                    local offset2 = obj1.radius / obj2.radius
                    if offset1 > 2 then offset1 = 2 end
                    if offset2 > 2 then offset2 = 2 end
                    obj2.x = obj2.x - bounce * offset2 * delta * n.x
                    obj2.y = obj2.y - bounce * offset2 * delta * n.y
                    obj1.x = obj1.x + bounce * offset1 * delta * n.x
                    obj1.y = obj1.y + bounce * offset1 * delta * n.y
                end
            end
        end
    end
end

local function processRopes()
    for i,rope in ipairs(ropes) do
        local ropeLength = rope[3]
        local centre = {
            x = (rope[1].x + rope[2].x) / 2,
            y = (rope[1].y + rope[2].y) / 2
        }
        for i = 1,2 do
            local ball = rope[i]
            local toObj = {x=0,y=0}
            toObj.x = ball.x - centre.x
            toObj.y = ball.y - centre.y
            local distance = (toObj.x^2 + toObj.y^2)^0.5
            local forceMult = 2
            if ball == playerBall then forceMult = 0.5 end
            --Elastic rope radius
            if distance > ropeLength - ball.radius then
                --Rigid rope radius
                if distance > (ropeLength * 1.5) - ball.radius then
                    forceMult = forceMult * 4
                end
                ball.vx = ball.vx + (centre.x - ball.x) / (50 / forceMult)
                ball.vy = ball.vy + (centre.y - ball.y) / (50 / forceMult)
            end
        end
    end
end

local function dashActive()
    local dashForce = 20
    local ball = playerBall
    local mx,my = love.mouse.getPosition()
    local distance = ((ball.x-mx)^2 + (ball.y-my)^2)^0.5
    if distance > 100 then distance = 100 end
    local distanceFactor = 100 / distance
    local angle = yawAngle(ball.x-mx,ball.y-my)
    local nx,ny = -dashForce / distanceFactor * math.cos(angle), -dashForce / distanceFactor * math.sin(angle)
    ball.vx,ball.lvx = nx,nx
    ball.vy,ball.lvy = ny,ny
end

local function ropeActive()
    local mx,my = love.mouse.getPosition()
    local angle = yawAngle(playerBall.x-mx,playerBall.y-my)
    local distance = ((playerBall.x-mx)^2 + (playerBall.y-my)^2)^0.5
    if distance > 150 then distance = 150 end
    local nRope = Rope:new(playerBall,{angle + math.pi,distance})
    table.insert(ropeObjects,nRope)
end

local function pistolActive()
    local mx,my = love.mouse.getPosition()
    local angle = yawAngle(playerBall.x-mx,playerBall.y-my)
    local distance = 300
    local nBullet = Bullet:new(playerBall,angle + math.pi)
    table.insert(bulletObjects,nBullet)
end

local function processPlayerInputs()
    local ball = playerBall
    local speed = 0.4
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

    local lMouse = love.mouse.isDown(1)
    local mMouse = love.mouse.isDown(3)
    local rMouse = love.mouse.isDown(2)

    
    if not lMouse and mouseState[1] then
        dashActive()
    elseif not rMouse and mouseState[2] then
        ropeActive()
    elseif not mMouse and mouseState[3] then
        pistolActive()
    end
    mouseState = {lMouse,rMouse,mMouse}
end

local function playerGhostInput(ability)
    local ball = playerBall
    local function abilityRange(rad)
        love.graphics.setColor(0,0,0,0.5)
        love.graphics.circle("line",ball.x,ball.y,rad)
        return rad
    end
    local function localMousePointer(rad,adjustable)
        local mx,my = love.mouse.getPosition()
        local distance = ((ball.x-mx)^2 + (ball.y-my)^2)^0.5
        if distance > rad or not adjustable then
            local angle = yawAngle(ball.x-mx,ball.y-my)
            mx = ball.x - rad * math.cos(angle)
            my = ball.y - rad * math.sin(angle)
        end
        love.graphics.line(mx-4,my-4,mx+4,my+4)
        love.graphics.line(mx-4,my+4,mx+4,my-4)
        return mx,my
    end
    local function lineToMouse(mx,my)
        love.graphics.line(ball.x,ball.y,mx,my)
    end
    local function ghostPlayerAtMouse(mx,my)
        love.graphics.circle("fill",mx,my,ball.radius)
    end
    if ability == "dash" then

        local range = abilityRange(100)
        local mx,my = localMousePointer(range,true)
        lineToMouse(mx,my)
        ghostPlayerAtMouse(mx,my)

    elseif ability == "rope" then

        local range = abilityRange(150)
        local mx,my = localMousePointer(range,true)
        lineToMouse(mx,my)

    elseif ability == "pistol" then

        local range = abilityRange(300)
        local mx,my = localMousePointer(range,false)
        lineToMouse(mx,my)

    end
end

local function drawBalls()
    for i,ball in ipairs(balls) do
        ball:draw()
    end
end

local function updateRopes()
    processRopes()
    for i,rope in ipairs(ropeObjects) do
        if rope:update() then
            table.remove(ropeObjects,i)
        end
    end
end

local function drawRopes()
    for i,rope in ipairs(ropes) do
        love.graphics.setColor(1,1,0)
        love.graphics.line(rope[1].x,rope[1].y,rope[2].x,rope[2].y)
    end
    for i,rope in ipairs(ropeObjects) do
        rope:draw()
    end
end

local function updateBullets()
    for i,bullet in ipairs(bulletObjects) do
        if bullet:update() then
            table.remove(bulletObjects,i)
        end
    end
end

local function drawBullets()
    for i,bullet in ipairs(bulletObjects) do
        bullet:draw()
    end
end

function love.update(dt)

    constraint(balls)

    expensiveCollisions(balls)

    verlet(balls,dt)

    processPlayerInputs()

    updateRopes()
    
    updateBullets()

end

function love.draw()

    love.graphics.setColor(0,0.4,0)
    love.graphics.rectangle("fill",0,0,love.graphics.getWidth(),love.graphics.getHeight())

    drawRopes()

    drawBalls()

    drawBullets()

    local lMouse = love.mouse.isDown(1)
    local mMouse = love.mouse.isDown(3)
    local rMouse = love.mouse.isDown(2)
    if lMouse then
        playerGhostInput("dash")
    elseif rMouse then
        playerGhostInput("rope")
    elseif mMouse then
        playerGhostInput("pistol")
    end
end
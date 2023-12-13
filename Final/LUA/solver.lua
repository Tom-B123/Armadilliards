require("util")
require("grid")
local drawBall  = require("drawBall")
require("lists")

local tick          = 0
local lastFrame     = Socket.gettime() * 10000
local checks        = 0
local fpsList       = List:new()
local timeToRespawn = 0

local grid = Grid:new(4098,32)

local windowDims = {x = love.graphics.getWidth(),y=love.graphics.getHeight()}

local camera = {x=0,y=0,vx=0,vy=0,focus = nil,focusInd = -1}

local Ball    = {}
Ball.__index  = Ball

local colours = {}
colours[1] = {0.1,0.1,0.1}
colours[2] = {1,0,0}
colours[3] = {0,1,0}
colours[4] = {0,0,1}
--Create a new ball object
function Ball:new(x,y)
    local object = {}
    setmetatable(object,Ball)
    object.ID       = ""
    object.playerID = nil
    object.x        = x
    object.y        = y
    object.initX    = x
    object.initY    = y
    object.vx       = 0
    object.vy       = 0
    object.ax       = 0
    object.ay       = 0
    object.lx       = x
    object.ly       = y
    object.lvx      = 0
    object.lvy      = 0
    object.radius   = 16
    object.yaw      = 0
    object.pitch    = 0
    object.colour   = colours[1]
    object.multi    = false
    object.health   = World.maxHealth
    object.mass     = 10
    object.death    = nil
    return object
end

function Ball:getWeight()
    local healthFraction = math.max(self.health / World.maxHealth,0.4)
    return healthFraction * self.mass
end

--Move a ball
function Ball:move(x,y)
    self.x          = self.x + x
    self.y          = self.y + y
    self:roll(x,y)
end

--Roll the ball
function Ball:roll(x,y)
    local magnitude = Util:findDistance(x,y)
    self.pitch      = self.pitch + Util:pitchAngle(magnitude,self.radius)
    self.yaw        = Util:yawAngle(x,y)
end

--Physics solving for ball objects
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

function Ball:edgeConstraint()
    if self.x - self.radius < 0 then
        self.x   = self.radius
        self.vx  = -self.vx
        self.lvx = -self.lvx
    end
    if self.x + self.radius > 4096 then
        self.x   = 4096 - self.radius
        self.vx  = -self.vx
        self.lvx = -self.lvx
    end
    if self.y - self.radius < 0 then
        self.y   = self.radius
        self.vy  = -self.vy
        self.lvy = -self.lvy
    end
    if self.y + self.radius > 4096 then
        self.y   = 4096 - self.radius
        self.vy  = -self.vy
        self.lvy = -self.lvy
    end
end

--Drawing ball objects
function Ball:draw(offsetX,offsetY)
    if self.multi or self.death then
        if World.debugShapes then
            love.graphics.circle(
                "line",
                self.x + offsetX,
                self.y + offsetY,
                self.radius
            )
        end
        return
    end
    local name   = nil
    local health = nil
    if self.playerID and World.showNames then
        name = LobbyPlayer:getName(self.playerID)
    end
    if self.health > 0 and World.showHealth and not self.multi then
        health = math.floor(self.health).."/"..World.maxHealth
    end
    drawBall:draw(
        self.x + offsetX,
        self.y + offsetY,
        self.yaw,self.pitch,
        self.colour,1,
        name,health
    )
end

function Ball:updateRoll()
    self:roll(self.x-self.lx,self.y-self.ly)
    self.lx = self.x
    self.ly = self.y
end

function Ball:tryRespawn()
    if self.death == nil then return end
    if tick - self.death >= World.respawnTime then
        local iX    = self.initX
        local iY    = self.initY
        self.x      = iX
        self.y      = iY
        self.lx     = iX
        self.ly     = iY
        self.vx     = 0
        self.vy     = 0
        self.lvx    = 0
        self.lvy    = 0
        self.health = World.maxHealth
        camera.focus = World.focus
        self.death  = nil
    end
end

Shape = {}

Shape.__index = Shape

--Make a new shape object, representing multiple bound circles
function Shape:new(circles,sides,length,circleRad)
    local object = {}
    setmetatable(object,Shape)
    object.circles   = circles
    object.sides     = sides
    object.length    = length
    object.circleRad = circleRad
    object.angle     = 0
    object.x         = 0
    object.y         = 0
    object.intAngle  = (sides-2)*math.pi / sides
    return object
end

--Calculate the angle of the shape
function Shape:calculateAngle()
    local circle1 = self.circles[1]
    local circle2 = self.circles[#self.circles]
    return Util:yawAngle(circle1.x-circle2.x,circle1.y-circle2.y)
end

--Calculate the centre of the shape's circles (the average of all coords)
function Shape:calculateCentre()
    local sumX  = 0
    local sumY  = 0
    local count = #self.circles
    for i,circle in ipairs(self.circles) do
        sumX = sumX + circle.x
        sumY = sumY + circle.y
    end
    return sumX / count, sumY / count
end

--Update the angle and centre position of the shape
function Shape:update()
    self.x,self.y = self:calculateCentre()
    self.angle    = self:calculateAngle()
end

function Shape:getVerts()
    local coords = {}
    for point = 0,self.sides-1 do
        local nx = self.length * math.cos(self.angle+(self.intAngle*point))
        local ny = self.length * math.sin(self.angle+(self.intAngle*point))
        nx = nx + self.x
        ny = ny + self.y
        table.insert(coords,nx)
        table.insert(coords,ny)
    end
    return coords
end

--Draw the shape based on the centre position and angle
function Shape:draw(offsetX,offsetY)
    local coords = self:getVerts()
    for i = 1,#coords do
        local offset = offsetX
        if i % 2 == 0 then offset = offsetY end
        coords[i] = coords[i] + offset
    end
    local fill = "fill"
    if World.debugShapes then fill = "line" end
    love.graphics.polygon(fill,coords)
end

function Shape:makeRopes()
    local circles = self.circles
    local dims = (#circles) ^ 0.5
    for y = 0,dims-1 do
        for x = 1,dims-1 do
            table.insert(World.ropes,{
                circles[dims*y + x].ID,
                circles[dims*y + x + 1].ID,
                self.circleRad*2,
                0
            })
        end
    end
    for y = 0,dims-2 do
        for x = 1,dims do
            table.insert(World.ropes,{
                circles[dims*y + x].ID,
                circles[dims*(y+1) + x].ID,
                self.circleRad*2,
                0
            })
        end
    end
end

local Particle = {}
Particle.__index = Particle

function Particle:new(x,y,colour,size,angle,speed)
    local object = {}
    setmetatable(object,Particle)
    object.maxLife = 30 + math.random(-5,5)
    object.life    = 60 + math.random(-10,10)
    object.x       = x
    object.y       = y
    object.vx      = speed * math.cos(angle)
    object.vy      = speed * math.sin(angle)
    object.size    = size + math.random(-10,10)/10
    object.colour  = colour
    return object
end

function Particle:update(dt)
    self.x = self.x + self.vx * dt
    self.y = self.y + self.vy * dt
    self.vx = self.vx * 0.9
    self.vy = self.vy * 0.9
    self.life = self.life - 1
end

function Particle:draw(offsetX,offsetY)
    local c = self.colour
    love.graphics.setColor(c[1],c[2],c[3],self.life / self.maxLife)
    love.graphics.circle("fill",offsetX + self.x,offsetY + self.y,self.size)
end

function camera:update(dt)
    self:updateFocus()

    if self.focus then
        local centre = {
            x = (self.x + self.focus.x) / 2,
            y = (self.y + self.focus.y) / 2
        }
        --attraction force of camera to the ball
        local forceMult = 10
        --Elastic rope radius
        self.vx = self.vx + (centre.x - self.x) * (forceMult)
        self.vy = self.vy + (centre.y - self.y) * (forceMult)
    end

    self.x = self.x + self.vx * dt
    self.y = self.y + self.vy * dt
    --setting velocity to a low number prevents boucing of camera
    self.vx = self.vx * 0.1
    self.vy = self.vx * 0.1
end

--Gets the offset for drawing objects
function camera:getOffset()
    return windowDims.x/2 - self.x, windowDims.y/2 - self.y
end

function camera:updateFocus()
    if self.focus == nil then return end
    if self.focus.death then
        World.ballsList:next()
        self.focus = World.ballsList:getVal()
    end
end

--World table, stores and processes all balls
--World focus = player's ball, camera focus = currently focused ball (eg. when spectating it will be different to world ball)
World = {
    ballsList     = List:new(),
    balls         = {},
    shapes        = {},
    playableBalls = {},
    ballIDDict    = {},
    ropes         = {},
    particles     = {},
    focus         = nil,
    showNames     = true,
    showHealth    = true,
    showFPS       = true,
    debugChecks   = true,
    debugGrid     = false,
    debugShapes   = false,
    respawnTime   = 60,
    maxHealth     = 20
}

function World:drawRespawnTime()
    if timeToRespawn > 0 then love.graphics.print("respawning in "..(timeToRespawn).." seconds",0,400) end
end

function World:updateFPS()
    local resolution = 60
    local curFrame = Socket.gettime()
    local dif = curFrame - lastFrame
    fpsList:append(1/dif)
    local averageFPS = 0
    local fpsLen = fpsList.length
    if fpsLen > resolution then fpsList:pop() end
    for i,fps in fpsList:iterator() do
        averageFPS = averageFPS + fps
    end
    averageFPS = averageFPS / fpsLen
    lastFrame = curFrame
    return tostring(math.floor(averageFPS))
end

function World:getOffset()
    return camera:getOffset()
end

function World:updateDeath(balls)
    for i, ball in ipairs(balls) do
        local health = ball.health
        if health <= 0 then
            for i = 1,15 do
                self:newParticle("rainbow",ball.x,ball.y,5,i)
            end
            ball.health = self.maxHealth
            ball.death  = tick
        end
    end
    
end

function World:updateRopes()
    local function process(balls,centre,length,elasticity)
        for i = 1,2 do
            local ball = balls[i]
            local toObj = {x=0,y=0}
            toObj.x = ball.x - centre.x
            toObj.y = ball.y - centre.y
            local distance = Util:findDistance(toObj.x, toObj.y)
            local forceMult = 1 * i^2
            if distance > length - ball.radius then
                if elasticity == 0 then
                    local new = {}
                    new[1] = toObj.x / distance
                    new[2] = toObj.y / distance
                    ball.x = centre.x + new[1] * (length - ball.radius)
                    ball.y = centre.y + new[2] * (length - ball.radius)
                else
                    forceMult = forceMult * elasticity
                    ball.vx = ball.vx + (centre.x - ball.x) / (50 / forceMult)
                    ball.vy = ball.vy + (centre.y - ball.y) / (50 / forceMult)
                end
            end
        end
    end
    for i,rope in ipairs(self.ropes) do
        local ID1        = rope[1]
        local ID2        = rope[2]
        local rope1      = self:getByID(ID1)
        local rope2      = self:getByID(ID2)
        local ropeLength = rope[3]
        local elasticity = rope[4]
        local ropeCentre = {
            x = (rope1.x + rope2.x) / 2,
            y = (rope1.y + rope2.y) / 2
        }
        --manhattan distance is very cheap to calculate, so used to prevent exessive square root calculions when they aren't necessary
        local manhattan = math.abs(rope2.x - rope1.x) + math.abs(rope2.y-rope1.y)
        if manhattan >= ropeLength then
            process({rope1,rope2},ropeCentre,ropeLength,elasticity)
        end
    end
end

--Follows a ball with the camera
function World:setFocus(ball)
    local ind = -1
    for i,sBall in ipairs(self.balls) do
        if sBall == ball then ind = i end
    end
    if ind > -1 then
        World.focus     = ball
        camera.focus    = ball
        camera.focusInd = ind
    end
end

--Used for i-frames to prevent many collisions with the same ball
local damageCooldowns = {}
local iTime           = 5

local damageMessages  = {}

--Clears all balls
function World:clear()
    self.balls         = {}
    self.shapes        = {}
    self.playableBalls = {}
    self.ballIDDict    = {}
    self.ropes         = {}
    camera.focus       = nil
    damageCooldowns    = {}
    tick               = 0
end

function World:updateRespawns()
    for i,ball in ipairs(self.balls) do
        if ball.death then ball:tryRespawn() end
    end
end

--Assigns an ID to a ball, or calculates a new ID using the given salt
function World:assignID(ball,ID,salt)
    if salt == nil then salt = 0 end
    if ID == nil then ID = Util:calculateID(6,salt) end
    ball.ID = ID
    self.ballIDDict[ID] = ball
    return ID
end

--Returns a ball by passing in the ball ID
function World:getByID(ID)
    return self.ballIDDict[ID]
end

--Creates a new ball in the world
function World:newBall(x,y,playable)
    local nBall = Ball:new(x,y)
    table.insert(self.balls,nBall)
    if playable then 
        table.insert(self.playableBalls,nBall)
        self.ballsList:push(nBall)
    end
    return nBall
end

--Creates a new shape out of a table of circles, side count and side length
function World:newShape(circles,sides,length,circleRad)
    local nShape = Shape:new(circles,sides,length,circleRad)
    table.insert(self.shapes,nShape)
end

--Create a new square object
function World:square(x,y,length)
    local function getDims(edge)
        if edge < 1 then return end
        local count = math.floor(edge / 32)+1
        if count <= 1 then count = 2
        elseif edge % 32 == 0 then count = count - 1 end
        return count,edge/count
    end
    local count,circleSize = getDims(length)
    local circles = {}
    for circleY = 1,count do
        for circleX = 1,count do
            local ball  = self:newBall(x + (circleX*circleSize),y + (circleY*circleSize))
            ball.multi  = true
            ball.radius = circleSize/2
            table.insert(circles,ball)
        end
    end
    
    local squareLength = ((length/2)^2 + (length/2)^2)^0.5
    self:newShape(circles,4,squareLength,circleSize/2)
end

--Assigns IDs to every ball, passing in a salt value to avoid duplicate IDs
function World:generateIDs()
    local IDs = {}
    for i,ball in ipairs(self.balls) do
        local ID = self:assignID(ball,nil,i)
        table.insert(IDs,ID)
    end
    for i,shape in ipairs(self.shapes) do
        shape:makeRopes()
    end
end

--Assigns playerIDs to the ball
function World:assignAll(playerIDs)
    for i,playerID in ipairs(playerIDs) do
        local ball = self.playableBalls[i]
        if ball then
            ball.playerID = playerID
            LobbyPlayer:setBallID(playerID,ball.ID)
        end
    end
end

function World:assign(playerID,ballID)
    local ball = self:getByID(ballID)
    if ball then
        ball.playerID = playerID
        LobbyPlayer:setBallID(playerID,ball.ID)
    end
end

local collisionCache  = {}

--Collisions with no optimisation
function World:expensiveCollisions(ballIDs)
    local bounce = 1
    local function calculateDamage(ball1,ball2,hashSum)

        --The tick of the last collision of ball1 and ball2
        local lastTick = damageCooldowns[hashSum]
        --If the balls have collided before, within 5 ticks, deal no damage
        if lastTick and tick - lastTick <= iTime then
            damageCooldowns[hashSum] = tick
            return
        end
        
        --Update the damageCooldowns
        damageCooldowns[hashSum] = tick

        local dvx = ball1.vx - ball2.vx
        local dvy = ball1.vy - ball2.vy

        --Using manhattan distance to check the speed isn't too low, without needing a sqrt
        local manhattan = math.abs(dvx) + math.abs(dvy)
        if manhattan < 3 then return end

        local dSpeed = Util:findDistance(dvx,dvy)
        if dSpeed < 3 then return end


        local speed1 = Util:findDistance(ball1.vx,ball1.vy)
        local speed2 = Util:findDistance(ball2.vx,ball2.vy)

        --The faster ball (the aggressor) will take less damage and inflict more damage
        local dampening       = 2
        local aggeressionMult = 1.5
        local nHealth1,nHealth2
        --If the speeds are similar, there is no aggressor so both balls lose equal health
        if math.abs(speed1 - speed2) < 0.3 then
            nHealth1 = ball1.health - (dSpeed * dSpeed / 10)
            nHealth2 = ball2.health - (dSpeed * dSpeed / 10)

        --If the speeds are unequal, the faster ball receives and deals more damage
        elseif speed1 > speed2 then
            nHealth1 = ball1.health - (dSpeed / dampening / aggeressionMult)
            nHealth2 = ball2.health - (dSpeed * dSpeed / 10 * aggeressionMult)
        elseif speed2 > speed1 then
            nHealth1 = ball1.health - (dSpeed * dSpeed / 10 * aggeressionMult)
            nHealth2 = ball2.health - (dSpeed / dampening / aggeressionMult)
        end

        local centre = {(ball1.x + ball2.x) / 2,(ball1.y + ball2.y) / 2}

        if not ball1.multi then ball1.health = nHealth1 end
        if not ball2.multi then ball2.health = nHealth2 end

        self:updateDeath({ball1,ball2})

        if nHealth1 > 0 and nHealth2 > 0 then
            self:newParticle("spark",centre[1],centre[2],math.floor(dSpeed)*1.5,dSpeed/2)
            self:newParticle("spark",centre[1],centre[2],math.floor(dSpeed)    ,1)
        end

        table.insert(damageMessages,"damg:"..ball1.ID.."_"..nHealth1.."_"..dSpeed.."_"..centre[1].."_"..centre[2])
        table.insert(damageMessages,"damg:"..ball2.ID.."_"..nHealth2.."_"..dSpeed.."_"..centre[1].."_"..centre[2])

    end

    local function collision(ID1,ID2,hashSum)
        local ball1 = self:getByID(ID1)
        local ball2 = self:getByID(ID2)
        
        local manhattan = math.abs(ball1.x-ball2.x) + math.abs(ball1.y-ball2.y)

        local diameter = ball1.radius + ball2.radius

        --Using manhattan distance to skip unnessesary checks
        if manhattan > 2 * diameter then return end

        checks = checks + 1

        local collisionAxis = {x=0,y=0}
        collisionAxis.x = ball1.x - ball2.x
        collisionAxis.y = ball1.y - ball2.y

        local distance = Util:findDistance(collisionAxis.x,collisionAxis.y)
        --If they collide:
        if distance > diameter then return end

        --Calulate the damage caused
        calculateDamage(ball1,ball2,hashSum)

        local n = collisionAxis
        n.x = n.x / distance
        n.y = n.y / distance

        local weight1 = ball1:getWeight()
        local weight2 = ball2:getWeight()

        local maxWeight = math.max(weight1,weight2)
        local minWeight = math.min(weight1,weight2)

        local dWeight = minWeight / maxWeight

        local delta = diameter - distance
        local offset1
        local offset2
        if weight1 > weight2 then 
            offset1 = ball2.radius / ball1.radius * dWeight
            offset2 = ball1.radius / ball2.radius / dWeight
        else
            offset1 = ball2.radius / ball1.radius / dWeight
            offset2 = ball1.radius / ball2.radius * dWeight
        end
        ball2.x = ball2.x - bounce * offset2 * delta * n.x
        ball2.y = ball2.y - bounce * offset2 * delta * n.y
        ball1.x = ball1.x + bounce * offset1 * delta * n.x
        ball1.y = ball1.y + bounce * offset1 * delta * n.y
    end
    for i, ID1 in ipairs(ballIDs) do
        for j, ID2 in ipairs(ballIDs) do
            if i ~= j then
                local sum = Util:hashIDs({ID1,ID2})
                if not collisionCache[sum] then
                    collision(ID1,ID2,sum)
                    collisionCache[sum] = true
                end
            end
        end
    end
end

function World:newParticle(style,x,y,count,speed)
    for i = 1,count do
        local colour = {1,1,1}
        if style == "spark" then colour = {1,0.5,0} end
        if style == "rainbow" then colour = {math.random(2,10)/10,math.random(2,10)/20,math.random(2,10)/10} end
        local nParticle = Particle:new(x,y,colour,5,math.random(0,628)/100,100 * speed)
        table.insert(self.particles,nParticle)
    end
end

function World:updateParticles(dt)
    for i,particle in ipairs(self.particles) do
        particle:update(dt)
        if particle.life <= 0 then
            particle = nil
        end
    end
end

function World:drawParticles(offsetX,offsetY)
    for i,particle in ipairs(self.particles) do
        particle:draw(offsetX,offsetY)
    end
end

--Populates the grid for optimised collisons
function World:populate()
    grid:reset()
    for i,ball in ipairs(self.balls) do
        grid:populate(ball.x,ball.y,ball.ID)
    end
end

--Optimised collisions to only check nearby balls
function World:optimisedCollisions()
    local found = grid:search()
    --Stores a dictionary of the sum of ball IDs. Should prevent double entry of IDs.
    --The IDs are mutliplied by 17 to avoid collisions
    local existingNeighbours = {}
    for i,searchBall in ipairs(found) do
        local searchX   = searchBall[1]
        local searchY   = searchBall[2]
        local neighbors = {}
        for gridY = -1,1 do
            for gridX = -1,1 do
                local cell = grid:lookup(gridX + searchX,gridY + searchY,grid.levels)
                if type(cell) == "table" then
                    for j,ID in ipairs(cell) do
                        if not self:getByID(ID).death then
                            table.insert(neighbors,ID)
                        end
                    end
                end
            end
        end
        if #neighbors > 1 then
            local sum = Util:hashIDs(neighbors)

            if not existingNeighbours[sum] then
                self:expensiveCollisions(neighbors)
                existingNeighbours[sum] = true
            end
        end
    end
end

--Draw all ropes
function World:drawRopes(offsetX,offsetY)
    love.graphics.setColor(1,1,0)
    for i, rope in ipairs(self.ropes) do
        local ball1 = self:getByID(rope[1])
        local ball2 = self:getByID(rope[2])
        love.graphics.line(ball1.x + offsetX,ball1.y + offsetY,ball2.x + offsetX,ball2.y + offsetY)
    end
end

function World:getBallIDs()
    local out = {}
    for i,ball in ipairs(self.balls) do
        table.insert(out,ball.ID)
    end
    return out
end

--Updates the position of every ball
function World:update(dt,isClient)
    camera:update(dt)
    self:updateParticles(dt)
    self:updateRespawns()
    if isClient then
        self:updateDeath(self.balls)
        for i, ball in ipairs(self.balls) do
            ball:verlet(dt)
        end
        tick = tick + 1
        return
    end
    checks = 0
    collisionCache = {}
    damageMessages = {}
    self:populate()
    self:updateRopes()
    
    for i, ball in ipairs(self.balls) do
        ball:edgeConstraint()
        ball:verlet(dt)
    end
    for i,shape in ipairs(self.shapes) do
        shape:update()
    end
    self:optimisedCollisions()

    tick = tick + 1
end

function World:getDamg()
    local ind = 0
    return function()
        if damageMessages[ind+1] then
            ind = ind + 1
            return damageMessages[ind]
        end
    end
end

--Draw every ball
function World:draw()
    local offsetX,offsetY = camera:getOffset()

    love.graphics.setColor( 0,0.4,0 )
    love.graphics.rectangle("fill",offsetX,offsetY,4096,4096)
    self:drawRopes(offsetX,offsetY)

    self:drawParticles(offsetX,offsetY)

    for i, ball in ipairs(self.balls) do
        ball:draw(offsetX,offsetY)
    end

    for i,shape in ipairs(self.shapes) do
        shape:draw(offsetX,offsetY)
    end

    self:drawRespawnTime()

    if self.debugGrid then grid:draw(offsetX,offsetY) end
    if self.debugChecks then love.graphics.print("collision checks: "..checks,0,200) end
    if World.showFPS then love.graphics.print(World:updateFPS()) end
end

--Create a string for assigning players to a ballID for taking player inputs
function World:getAsgn()
    local out = "asgn:"
    for i, ball in ipairs(self.balls) do
        if ball.playerID then
            out = out..ball.ID.."_"..ball.playerID
        else
            out = out..ball.ID.."_".."no ID"
        end
        if i < #self.balls then out = out.."_" end
    end
    return out
end

--Create a string for updating player's positions
function World:getUpgm()
    local out = {}
    for i, ball in ipairs(self.balls) do
        if not ball.multi then 
            table.insert(out,"upgm:ball_"..ball.ID.."_"..Util:coordToHex(ball.x,ball.y).."_\n")
        end
    end
    for i,shape in ipairs(self.shapes) do
        local verts = shape:getVerts()
        local msg = "upgm:poly"
        for j = 1, #verts/2 do
            local x = verts[j*2-1]
            local y = verts[j*2]
            msg = msg.."_"..Util:coordToHex(x,y)
        end
        table.insert(out,msg)
    end
    return out
end

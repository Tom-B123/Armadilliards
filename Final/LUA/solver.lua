require("util")
require("grid")
require("lists")
require("sets")
local drawBall  = require("drawBall")
local track     = require("performance")
local objective = require("objective")

local tick            = 0
local lastFrame       = Socket.gettime() * 10000
local checks          = 0
local manhattanChecks = 0
local fpsList         = List:new()
local timeToRespawn   = 0

local grid = Grid:new(4098,32)

local windowDims = {x = love.graphics.getWidth(),y=love.graphics.getHeight()}

local camera = {x=0,y=0,vx=0,vy=0,focus = nil,focusInd = -1}

local damageMessages     = {}
local objectiveMessages  = {}
local ropeMessages       = {}

local Ball    = {}
Ball.__index  = Ball

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
    object.colour   = {0,0,0}
    object.health   = World.maxHealth
    object.mass     = 10
    object.death    = nil
    object.eliminated = false
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

    if World.holesSet:has(self.ID) then
        love.graphics.setColor(0,0.2,0)
        love.graphics.circle("fill",self.x + offsetX,self.y + offsetY,self.radius)
        return
    end

    if World.bulletsSet:has(self.ID) then
        love.graphics.setColor(1,0,0)
        love.graphics.circle("fill",self.x + offsetX,self.y + offsetY,self.radius)
        return
    end

    local debugBall = false
    local style = "ball"
    for i,ball in ipairs(World.playableBalls) do
        if ball.ID == self.ID then
            style = "armadillo"
        end
    end
    if (World.multiSet:has(self.ID) or self.death) then
        if World.debugShapes then
            style = "debug"
        else
            return
        end
    end

    local name   = nil
    local health = nil

    if self.playerID and World.showNames then
        name = LobbyPlayer:getName(self.playerID)
    end

    if self.health > 0 and World.showHealth and not World.multiSet:has(self.ID) then
        health = {self.health,World.maxHealth}
    end

    drawBall:draw(
        self.x + offsetX,
        self.y + offsetY,
        self.yaw,self.pitch,
        self.colour,1,
        name,health,World.debugChecks,
        style,self.radius
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

function Ball:dash(angle,velocity)
    local vx = velocity * math.cos(angle)
    local vy = velocity * math.sin(angle)
    self.vx  = vx
    self.lvx = vx
    self.vy  = vy
    self.lvy = vy
end

function Ball:shoot(angle,velocity)
    World:newBullet(self.ID,self.x,self.y,angle,velocity)
end

--Rope a ball at the given position
function Ball:rope(rx,ry)
    local function getNeighbours(searchX,searchY)
        local neighbors = {}
        for gridY = -1,1 do
            for gridX = -1,1 do
                local cell = grid:lookup(gridX + searchX,gridY + searchY,grid.levels)
                if type(cell) == "table" then
                    for j,ID in ipairs(cell) do
                        if not World:getByID(ID).death then
                            table.insert(neighbors,ID)
                        end
                    end
                end
            end
        end
        return neighbors
    end

    local function isClicked(ID,x,y)
        local ball      = World:getByID(ID)

        local manhattan = Util:manhattanDistance(ball.x - x,ball.y - y)
        if manhattan > 2*ball.radius then return false end

        return Util:findDistance(ball.x-x,ball.y-y) <= ball.radius
    end
    --Confine to within the game area
    rx = math.max(rx,0)
    rx = math.min(rx,4096)
    ry = math.max(ry,0)
    ry = math.min(ry,4096)

    local searchX = math.floor(rx/32)
    local searchY = math.floor(ry/32)

    local neighbors = getNeighbours(searchX,searchY)

    for i,ID in ipairs(neighbors) do
        if isClicked(ID,rx,ry) then
            World:newRope(self.ID,ID,100,1)
            table.insert(ropeMessages,"nrope:"..self.ID.."_"..ID.."_\n")
        end
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
    
    local diagonal = Util:findDistance(circles[1].x-circles[2].x,circles[1].y-circles[dims+1].y) / 1.15
    for y = 0,dims-2 do
        for x = 0,dims-2 do
            local ind  = (dims)*y + x + 1
            local nInd = (dims)*(y+1) + x + 2
            World:newRope(
                circles[ind].ID,
                circles[nInd].ID,
                diagonal,0
            )
        end
    end
    for y = 0,dims-2 do
        for x = 1,dims-1 do
            local ind  = (dims)*y + x + 1
            local nInd = (dims)*(y+1) + x
            World:newRope(
                circles[ind].ID,
                circles[nInd].ID,
                diagonal,0
            )
        end
    end

    for y = 0,dims-1 do
        for x = 1,dims-1 do
            World:newRope(
                circles[dims*y + x].ID,
                circles[dims*y + x + 1].ID,
                self.circleRad*2,0
            )
        end
    end
    for y = 0,dims-2 do
        for x = 1,dims do
            World:newRope(
                circles[dims*y + x].ID,
                circles[dims*(y+1) + x].ID,
                self.circleRad*2,0
            )
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
    love.graphics.circle("fill",offsetX + self.x,offsetY + self.y,self.size * self.life / self.maxLife)
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

objective:new("deaths")
objective:new("kills")
objective:new("damage dealt")
objective:new("damage taken")
objective:new("capture point")

--World table, stores and processes all balls
--World focus = player's ball, camera focus = currently focused ball (eg. when spectating it will be different to world ball)
World = {
    ballsList     = List:new(),
    shapes        = {},

    holes         = {},
    holesSet      = Set: new(),
    multi         = {},
    multiSet      = Set: new(),
    bulletsSet    = Set: new(),

    playableBalls = {},
    ballIDDict    = {},

    ropes         = {},
    ropedBalls    = Set: new(),

    particles     = {},

    focus         = nil,
    
    showNames     = true,
    showHealth    = true,
    showFPS       = true,
    debugChecks   = false,
    debugGrid     = true,
    debugShapes   = false,
    debugTracking = false,

    respawnTime   = 240,
    maxHealth     = 50,
    particleLimit = 200,
    particleCount = 0,

    allTeams        = Set:new(),
    eliminatedTeams = Set:new(),

    atGoal        = false
}

function World:drawRespawnTime()
    if not self.focus then return end
    if World.focus.eliminated then love.graphics.print("your team has been eliminated!",0,400) return end
    timeToRespawn = -1
    if World.focus.death then timeToRespawn = (math.floor(((World.respawnTime - tick + World.focus.death) / 60)*10) + 1)/10 end

    if timeToRespawn > -1 then
        love.graphics.print("respawning in "..(timeToRespawn).." seconds",0,400)
    end
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

function World:updateDeath(balls,kill,isClient)
    if not isClient and kill and #balls == 2 then
        --Logic for detecting which team got a kill
        if balls[1].health <= 0 then
            if balls[2].playerID then
                local team2 = LobbyPlayer:getTeam(balls[2].playerID)
                if team2 then
                    if objective:addScore("kills",team2,1) then self.atGoal = true end

                    table.insert(objectiveMessages,{"kills",team2,objective:getScore("kills",team2)})
                end
            end
        end
        if balls[2].health <= 0 then
            if balls[1].playerID then
                local team1 = LobbyPlayer:getTeam(balls[1].playerID)
                if team1 then
                    if objective:addScore("kills",team1,1) then self.atGoal = true end

                    table.insert(objectiveMessages,{"kills",team1,objective:getScore("kills",team1)})
                end
            end
        end
    end
    for i, ball in ipairs(balls) do
        local health = ball.health
        if health <= 0 then
            --If the dead ball is a player, update their team's death count
            if not isClient and ball.playerID then
                local team = LobbyPlayer:getTeam(ball.playerID)
                if objective:addScore("deaths",team,1) then
                    ball.eliminated = true
                end

                table.insert(objectiveMessages,{"deaths",team,objective:getScore("deaths",team)})
            end

            if not self.bulletsSet:has(ball.ID) then
                for j = 1,15 do
                    self:newParticle("rainbow",ball.x,ball.y,5,j)
                end
                ball.health = self.maxHealth
            end
            ball.death  = tick
            self:removeRopes(ball.ID)
        end
    end
end

function World:withinRopeDistance(hashedID)
    local rope = self.ropes[hashedID]
    if not rope then return false end

    local ID1        = rope[1]
    local ID2        = rope[2]
    local ropeLength = rope[3] * 2

    local ball1 = self:getByID(ID1)
    local ball2 = self:getByID(ID2)

    local distance = Util:withinDistance(ball1,ball2,ropeLength)
    return distance
end

--Create a new entry in the ropes dictionary using the 2 connected IDs
function World:newRope(ID1,ID2,length,elasticity)
    if ID1 == ID2 then return end

    --Holes can't be roped.

    if self.holesSet:has(ID1) or self.holesSet:has(ID2)   then return end


    if not (self:getByID(ID1) and self:getByID(ID2))      then return end
    --Dead players can't be roped

    if self:getByID(ID1).death or self:getByID(ID2).death then return end


    --Create an ID for the rope unique to the two connected balls. creating a new rope with the same ID will alter the existing rope connection
    local hashedID       = Util:hashIDs({ID1,ID2})
    local nRope          = {ID1,ID2,length,elasticity}

    local function isSameRope(rope1,rope2)
        if not(rope1 and rope2) then return false end
        for i = 1,#rope1 do
            if rope1[i] ~= rope2[i] then
                return false
            end
        end
        return true
    end

    --delete the rope if the same rope already exists
    if isSameRope(self.ropes[hashedID],nRope) then
        self.ropes[hashedID] = nil
        self.ropedBalls:remove(ID1)
        self.ropedBalls:remove(ID2)
        return
    end

    self.ropes[hashedID] = nRope

    self.ropedBalls:add(ID1)
    self.ropedBalls:add(ID2)

    return nRope
end

--Removes all ropes connected to a ballID
function World:removeRopes(ID)
    if not self.ropedBalls:has(ID) then return end
    local hashedID
    for ballID,val in self.ropedBalls:pairs() do
        --Loop through every ball that is roped, if that ID combined with the removing ball's ID exists, they must be roped. Remove all
        --rope connections found
        hashedID = Util:hashIDs({ID,ballID})
        if self.ropes[hashedID] then self.ropes[hashedID] = nil end
    end
    self.ropedBalls:remove(ID)
end

function World:updateRopes()
    local function findDistance(ball,centre,length)
        local toObj = {x=0,y=0}
        toObj.x = ball.x - centre.x
        toObj.y = ball.y - centre.y
        
        local manhattan = Util:manhattanDistance(toObj.x,toObj.y)
        
        if manhattan <= length - ball.radius then return nil end
        local distance = Util:findDistance(toObj.x, toObj.y)
        if distance  <= length - ball.radius then return nil end
        return distance
    end
    local function process(balls,centre,length,elasticity)
        for i = 1,2 do
            local ball = balls[i]
            local toObj = {x=0,y=0}
            toObj.x = ball.x - centre.x
            toObj.y = ball.y - centre.y
            
            local distance = findDistance(ball,centre,length)
            if distance then
                if elasticity == 0 then
                    local new = {}
                    new[1] = toObj.x / distance
                    new[2] = toObj.y / distance
                    ball.x = centre.x + new[1] * (length - ball.radius)
                    ball.y = centre.y + new[2] * (length - ball.radius)
                else
                    local forceMult = elasticity * i^2
                    ball.vx = ball.vx + (centre.x - ball.x) / (50 / forceMult)
                    ball.vy = ball.vy + (centre.y - ball.y) / (50 / forceMult)
                end
            end
        end
    end
    for hashedID,rope in pairs(self.ropes) do
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
        process({rope1,rope2},ropeCentre,ropeLength,elasticity)
    end
end

--Follows a ball with the camera
function World:setFocus(ball)
    local ind = -1
    for i,sBall in self.ballsList:iterator() do
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

--Clears all balls
function World:clear()
    self.ballsList     = List:new()
    self.shapes        = {}
    self.holes         = {}
    self.holesSet:  clear()
    self.multiSet:  clear()
    self.allTeams:       clear()
    self.eliminatedTeams:clear()
    self.playableBalls = {}
    self.ballIDDict    = {}
    self.ropes         = {}
    camera.focus       = nil
    damageCooldowns    = {}
    tick               = 0
    objective:resetScores()
    self.atGoal        = false
    
end

function World:updateEliminations()
    if objective:getGoal()[2] ~= "deaths" then return end
    for i,ball in self.ballsList:iterator() do
        --Add the team to the eliminated and regular teams sets
        if ball.playerID then
            local team = LobbyPlayer:getTeam(ball.playerID)
            self.allTeams:add(team)
            if ball.eliminated then self.eliminatedTeams:add(team) end
        end
    end
    
    if self.allTeams.length <= self.eliminatedTeams.length + 1 then
        self.atGoal = true
    end
end

--Respawns every ball that has reached the end if its respawn timer.
function World:updateRespawns()
    for i,ball in self.ballsList:iterator() do
        if not ball.eliminated and ball.death then ball:tryRespawn() end
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
    self.ballsList:push(nBall)
    if playable then
        table.insert(self.playableBalls,nBall)
    end
    return nBall
end

--Creates a new ball in the world
function World:newHole(x,y)
    local nBall = Ball:new(x,y)
    self.ballsList:push(nBall)
    table.insert(self.holes,nBall)
    return nBall
end

--Creates a new ball in the world
function World:newBullet(owner,x,y,angle,velocity)
    local nBall = Ball:new(x,y)
    --The player that shot the bullet, used to prevent shooting yourself
    nBall.owner  = owner
    nBall.vx     = velocity * math.cos(angle)
    nBall.vy     = velocity * math.sin(angle)
    nBall.radius = 8
    local salt   = x+y+angle+velocity
    local ID     = self:assignID(nBall,Util:calculateID(6,salt))
    self.ballsList:push(nBall)
    self.bulletsSet:add(ID)
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
            ball.radius = circleSize/2
            table.insert(circles,   ball)
            table.insert(self.multi,ball)
        end
    end
    
    local squareLength = ((length/2)^2 + (length/2)^2)^0.5
    self:newShape(circles,4,squareLength,circleSize/2)
end

--Assigns IDs to every ball, passing in a salt value to avoid duplicate IDs
function World:generateIDs()
    local IDs = {}
    for i,ball in self.ballsList:iterator() do
        local ID = self:assignID(ball,nil,i)
        table.insert(IDs,ID)
        for j,hole in ipairs(self.holes) do
            if hole == ball then
                self.holesSet:add(ID)
            end
        end
        for j,multi in ipairs(self.multi) do
            if multi == ball then
                self.multiSet:add(ID)
            end
        end
    end
    self.holes = {}
    self.multi = {}
    for i,shape in ipairs(self.shapes) do
        shape:makeRopes()
    end
end

local teamColour = {}
teamColour["team 1"] = {1,0,0}
teamColour["team 2"] = {0,1,0}
teamColour["team 3"] = {0,0,1}
teamColour["team 4"] = {0,1,1}
teamColour["team 5"] = {1,0,1}
teamColour["team 6"] = {1,1,0}
teamColour["team 7"] = {1,1,1}
teamColour["team 8"] = {0,0,0}

--Assigns playerIDs to the ball
function World:assignAll(playerIDs)
    for i,playerID in ipairs(playerIDs) do
        local ball = self.playableBalls[i]
        if ball then
            ball.playerID = playerID
            local team = LobbyPlayer:getTeam(playerID)
            ball.colour = teamColour[team]
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

function World:updateBullets()
    local toRemove = {}
    for ID,v in self.bulletsSet:pairs() do
        local ball = self:getByID(ID)
        if ball.health <= 0 then
            self.bulletsSet:remove(ID)
            table.insert(toRemove,ball)
        end
    end

    --Can be shortened to o(n), currently O(n^2) with removeItem being O(n)
    for i,ball in self.ballsList:iterator() do
        for j,rBall in ipairs(toRemove) do
            if rBall == ball then
                self.ballsList:removeItem(ball)
            end
        end
    end
end

local collisionCache = {}

--Collisions with no optimisation
function World:expensiveCollisions(ballIDs)
    local bounce = 1
    local function calculateDamage(ID1,ID2,hashSum)

        --The tick of the last collision of ball1 and ball2
        local lastTick = damageCooldowns[hashSum]
        --If the balls have collided before, within iTime ticks, deal no damage and reset the cooldown timer
        if lastTick and tick - lastTick <= iTime then
            damageCooldowns[hashSum] = tick
            return
        end
        
        
        local ball1 = self:getByID(ID1)
        local ball2 = self:getByID(ID2)

        local multi1 = self.multiSet:has(ID1)
        local multi2 = self.multiSet:has(ID2)

        local hole1 = self.holesSet:has(ID1)
        local hole2 = self.holesSet:has(ID2)

        --If ball1 is a hole and ball2 is a non-multi-shape ball then

        if     hole1 and not hole2 and not multi2 then

            --Adds damage taken for the reamaining ball health
            local team2 = LobbyPlayer:getTeam(ball2.playerID)
            if team2 then 
                if objective:addScore("damage taken",team2,ball2.health) then self.atGoal = true end
                table.insert(objectiveMessages,{"damage taken",team2,objective:getScore("damage dealt",team2)})
            end

            ball2.health = 0
            local hexX,hexY = Util:coordToHex(ball2.x,ball2.y)
            table.insert(damageMessages,"damg:"..ball2.ID.."_".."00".."_".."02".."_"..hexX.."_"..hexY)

            self:updateDeath({ball2})
            return
        
        --If ball2 is a hole and ball1 is a non-multi-shape ball then
        elseif hole2 and not hole1 and not multi1 then

            --Adds damage taken for the reamaining ball health
            local team1 = LobbyPlayer:getTeam(ball1.playerID)
            if team1 then 
                objective:addScore("damage taken",team1,ball1.health) 
                table.insert(objectiveMessages,{"damage taken",team1,objective:getScore("damage dealt",team1)})
            end

            ball1.health = 0
            local hexX,hexY = Util:coordToHex(ball1.x,ball1.y)
            table.insert(damageMessages,"damg:"..ball1.ID.."_".."00".."_".."02".."_"..hexX.."_"..hexY)

            self:updateDeath({ball1})
            return
        end

        local bullet1 = self.bulletsSet:has(ID1)
        local bullet2 = self.bulletsSet:has(ID2)

        if bullet1 then
            if ball1.owner == ID2 then return end
        end

        if bullet2 then
            if ball2.owner == ID1 then return end
        end

        if bullet1 then
            ball1.health = 0
            local hexX,hexY = Util:coordToHex(ball1.x,ball1.y)
            table.insert(damageMessages,"damg:"..ball1.ID.."_".."00".."_".."02".."_"..hexX.."_"..hexY)
            self:updateDeath({ball1})
        end

        if bullet2 then
            ball2.health = 0
            local hexX,hexY = Util:coordToHex(ball2.x,ball2.y)
            table.insert(damageMessages,"damg:"..ball2.ID.."_".."00".."_".."02".."_"..hexX.."_"..hexY)
            self:updateDeath({ball2})
        end
        
        --Update the damageCooldowns
        damageCooldowns[hashSum] = tick

        local dvx = ball1.vx - ball2.vx
        local dvy = ball1.vy - ball2.vy

        --Using manhattan distance to check the speed isn't too low, without needing a sqrt
        local manhattan = Util:manhattanDistance(dvx,dvy)
        if manhattan < 3 then return end

        local dSpeed = Util:findDistance(dvx,dvy)
        if dSpeed < 3 then return end

        --Get the teams of the two balls, or nil if they aren't player controlled.
        local team1
        local team2
        if ball1.playerID then
            team1  = LobbyPlayer:getTeam(ball1.playerID)
        end

        if ball2.playerID then
            team2  = LobbyPlayer:getTeam(ball2.playerID)
        end

        --Get the true speed of the balls
        local speed1 = Util:findDistance(ball1.vx,ball1.vy)
        local speed2 = Util:findDistance(ball2.vx,ball2.vy)

        --The faster ball (the aggressor) will take less damage and inflict more damage
        local dampening       = 2
        local aggeressionMult = 1.5

        local oHealth1        = ball1.health
        local oHealth2        = ball2.health

        local nHealth1
        local nHealth2

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

        --Damage taken = change in health
        local damage1 = oHealth1 - nHealth1
        local damage2 = oHealth2 - nHealth2

        --Update the damage dealt scores, adding scores to objectiveMessages
        if team1 then
            if objective:addScore("damage dealt",team1,damage2) then self.atGoal = true end
            if objective:addScore("damage taken",team1,damage1) then self.atGoal = true end

            table.insert(objectiveMessages,{"damage dealt",team1,objective:getScore("damage dealt",team1)})
            table.insert(objectiveMessages,{"damage taken",team1,objective:getScore("damage taken",team1)})
        end

        if team2 then
            if objective:addScore("damage dealt",team2,damage1) then self.atGoal = true end
            if objective:addScore("damage taken",team2,damage2) then self.atGoal = true end

            table.insert(objectiveMessages,{"damage dealt",team2,objective:getScore("damage dealt",team2)})
            table.insert(objectiveMessages,{"damage taken",team2,objective:getScore("damage taken",team2)})
        end

        local centre = {(ball1.x + ball2.x) / 2,(ball1.y + ball2.y) / 2}

        if not multi1 then ball1.health = nHealth1 end
        if not multi2 then ball2.health = nHealth2 end

        self:updateDeath({ball1,ball2},true)

        if not (multi1 and multi2) then
            self:newParticle("spark",centre[1],centre[2],math.floor(dSpeed)*1.5,dSpeed/2)
            self:newParticle("spark",centre[1],centre[2],math.floor(dSpeed)    ,1)
        end
        local hexHealth
        local hexSpeed  = Util:numToHex(math.max(0,dSpeed*10))
        local hexX,hexY = Util:coordToHex(centre[1],centre[2])
        if not multi1 then
            hexHealth = Util:numToHex(math.max(0,nHealth1*10))
            table.insert(damageMessages,"damg:"..ball1.ID.."_"..hexHealth.."_"..hexSpeed.."_"..hexX.."_"..hexY)
        end
        if not multi2 then
            hexHealth = Util:numToHex(math.max(0,nHealth2*10))
            table.insert(damageMessages,"damg:"..ball2.ID.."_"..hexHealth.."_"..hexSpeed.."_"..hexX.."_"..hexY)
        end

    end

    local function collision(ID1,ID2,hashSum)
        local ball1 = self:getByID(ID1)
        local ball2 = self:getByID(ID2)
        
        local manhattan = Util:manhattanDistance(ball1.x-ball2.x,ball1.y-ball2.y)

        local diameter = ball1.radius + ball2.radius

        
        --Using manhattan distance to skip unnessesary checks
        if manhattan > (2^0.5) * diameter then return end
        
        manhattanChecks = manhattanChecks + 1

        local collisionAxis = {x=0,y=0}
        collisionAxis.x = ball1.x - ball2.x
        collisionAxis.y = ball1.y - ball2.y

        local distance = Util:findDistance(collisionAxis.x,collisionAxis.y)
        --If they collide:
        if distance > diameter then return end

        checks = checks + 1

        --Calulate the damage caused
        calculateDamage(ID1,ID2,hashSum)

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

        local function toCollide()

            --If either ball is a hole, move neither ball
            if self.holesSet:has(ID1) or self.holesSet:has(ID2) then return false,false end

            --If both balls are bullets, move neither
            if self.bulletsSet:has(ID1) and self.bulletsSet:has(ID2) then return false,false end

            --If one ball is a bullet, move the non-bullet ball
            if self.bulletsSet:has(ID1) then
                --If the bullet hits it's owner, don't collide them
                if self:getByID(ID1).owner == ID2 then return false,false end
                offset2 = offset2 * 5
                return false,true
            end
            if self.bulletsSet:has(ID2) then
                --If the bullet hits it's owner, don't collide them
                if self:getByID(ID2).owner == ID1 then return false,false end
                offset1 = offset1 * 5
                return true,false end

            --If both balls are normal, move both
            return true,true
        end

        local col1,col2 = toCollide()

        if col1 then
            ball1.x = ball1.x + bounce * offset1 * delta * n.x
            ball1.y = ball1.y + bounce * offset1 * delta * n.y
        end
        if col2 then
            ball2.x = ball2.x - bounce * offset2 * delta * n.x
            ball2.y = ball2.y - bounce * offset2 * delta * n.y
        end
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
        if self.particleCount > self.particleLimit then return end
        self.particleCount = self.particleCount + 1
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
            self.particleCount = self.particleCount - 1
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
    track:start("grid clear")
    grid:reset()
    track:finish("grid clear")

    track:start("grid populate")
    for i,ball in self.ballsList:iterator() do
        grid:populate(ball.x,ball.y,ball.ID)
    end
    track:finish("grid populate")
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
    for hashedID, rope in pairs(self.ropes) do
        local ball1 = self:getByID(rope[1])
        local ball2 = self:getByID(rope[2])
        love.graphics.line(ball1.x + offsetX,ball1.y + offsetY,ball2.x + offsetX,ball2.y + offsetY)
    end
end

function World:getBallIDs()
    local out = {}
    for i,ball in self.ballsList:iterator() do
        table.insert(out,ball.ID)
    end
    return out
end

track:new("solver")
track:new("update particles")
track:new("grid clear")
track:new("grid populate")
track:new("ropes")
track:new("verlet")
track:new("collisions")

track:new("draw")
track:new("grid and ropes")
track:new("particles")
track:new("balls")
track:new("polygons")
track:new("other debugs")

local function getTrackingTimes()
    local out = {}
    table.insert(out,"solver:     "..track:getTime("solver"))
    table.insert(out,"particles:  "..track:getTime("update particles"))
    table.insert(out,"grid clear: "..track:getTime("grid clear"))
    table.insert(out,"grid pop:   "..track:getTime("grid populate"))
    table.insert(out,"ropes:      "..track:getTime("ropes"))
    table.insert(out,"verlet:     "..track:getTime("verlet"))
    table.insert(out,"collisions: "..track:getTime("collisions"))
    table.insert(out,"draw time:  "..track:getTime("draw"))
    table.insert(out,"grid+ropes: "..track:getTime("grid and ropes"))
    table.insert(out,"particles:  "..track:getTime("particles"))
    table.insert(out,"balls:      "..track:getTime("balls"))
    table.insert(out,"polygons:   "..track:getTime("polygons"))
    table.insert(out,"debug info: "..track:getTime("other debugs"))
    return out
end

local function getBallsTable()
    local out = {}
    for i,ball in World.ballsList:iterator() do
        out[#out+1] = ball
    end
    return out
end

--Updates the position of every ball
function World:update(dt,isClient)
    track:start("solver")
    if self.focus then camera:update(dt) end
    track:start("update particles")
    self:updateParticles(dt)
    track:finish("update particles")
    self:updateRespawns()
    if isClient then
        self:updateDeath(getBallsTable(),false,true)
        for i, ball in self.ballsList:iterator() do
            if not self.holesSet:has(ball) then
                ball:verlet(dt)
            end
        end
        tick = tick + 1
        track:finish("solver")
        return
    end

    --Reset all per-tick variables
    checks            = 0
    manhattanChecks   = 0
    collisionCache    = {}
    damageMessages    = {}
    objectiveMessages = {}
    ropeMessages      = {}

    self:populate()

    self:updateEliminations()

    track:start("ropes")
    self:updateRopes()
    track:finish("ropes")
    
    track:start("verlet")
    for i, ball in self.ballsList:iterator() do
        if not self.holesSet:has(ball) then
            ball:edgeConstraint()
            ball:verlet(dt)
        end
    end
    for i,shape in ipairs(self.shapes) do
        shape:update()
    end
    track:finish("verlet")

    track:start("collisions")
    -- self:expensiveCollisions(World:getBallIDs())
    self:optimisedCollisions()
    track:finish("collisions")
    self:updateBullets()
    track:finish("solver")
    tick = tick + 1
end

--Iterator for damage messages
function World:getDamg()
    local ind = 0
    return function()
        if damageMessages[ind+1] then
            ind = ind + 1
            return damageMessages[ind]
        end
    end
end

--Iterator for objective messages messages
function World:getObjv()
    local ind = 0
    return function()
        if objectiveMessages[ind+1] then
            ind = ind + 1
            local message = objectiveMessages[ind]
            return "objv:"..message[1].."_"..message[2].."_"..message[3].."_\n"
        end
    end
end

--Sets the score of a team and event
function World:setScore(event,team,nScore)
    objective:setScore(event,team,nScore)
end

function World:setGoal(event,score)
    objective:setGoal(event,score)
end

function World:getGoal()
    return objective:getGoal()
end

--Iterator for rope messages
function World:getRope()
    local ind = 0
    return function()
        if ropeMessages[ind+1] then
            ind = ind + 1
            return ropeMessages[ind]
        end
    end
end

--Draw every ball
function World:draw()
    local offsetX,offsetY = camera:getOffset()

    track:start("draw")

    track:start("grid and ropes")
    love.graphics.setColor( 0,0.4,0 )
    love.graphics.rectangle("fill",offsetX,offsetY,4096,4096)

    if self.debugGrid then grid:draw(offsetX,offsetY) end

    self:drawRopes(offsetX,offsetY)
    track:finish("grid and ropes")

    track:start("particles")
    self:drawParticles(offsetX,offsetY)
    track:finish("particles")

    track:start("balls")
    for i, ball in self.ballsList:iterator() do
        ball:draw(offsetX,offsetY)
    end
    track:finish("balls")

    track:start("polygons")
    for i,shape in ipairs(self.shapes) do
        shape:draw(offsetX,offsetY)
    end
    track:finish("polygons")

    track:start("other debugs")
    self:drawRespawnTime()

    if self.debugChecks then love.graphics.print("collision checks: "..checks,0,200) end
    if self.debugChecks then love.graphics.print("manhattan checks: "..manhattanChecks,0,220) end
    if World.showFPS then love.graphics.print(World:updateFPS()) end
    track:finish("other debugs")

    track:finish("draw")

    if World.debugTracking then
        local times = getTrackingTimes()
        for i,str in ipairs(times) do
            love.graphics.print(str,0,220 + i*20)
        end
    end
end

--Create a string for assigning players to a ballID for taking player inputs
function World:getAsgn()
    local out = "asgn:"
    for i, ball in self.ballsList:iterator() do
        if ball.playerID then
            out = out..ball.ID.."_"..ball.playerID
        else
            out = out..ball.ID.."_".."no ID"
        end
        if i < self.ballsList.length then out = out.."_" end
    end
    return out
end

--Create a string for updating player's positions
function World:getUpgm()
    local out = {}
    for i, ball in self.ballsList:iterator() do
        if not self.multiSet:has(ball.ID) then
            local hexX,hexY = Util:coordToHex(ball.x,ball.y)
            table.insert(out,"upgm:ball_"..ball.ID.."_"..hexX.."_"..hexY.."_\n")
        end
    end
    for i,shape in ipairs(self.shapes) do
        local verts = shape:getVerts()
        local msg = "upgm:poly_"
        for j = 1, #verts/2 do
            local x = verts[j*2-1]
            local y = verts[j*2]
            local hexX,hexY = Util:coordToHex(x,y)
            msg = msg..hexX.."_"..hexY.."_"
        end
        table.insert(out,msg)
    end
    return out
end

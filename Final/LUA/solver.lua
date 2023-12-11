require("util")
require("grid")

local checks = 0

local grid = Grid:new(4098,32)

local drawBall  = require("drawBall")

local windowDims = {x = love.graphics.getWidth(),y=love.graphics.getHeight()}

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
    return object
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
    local name = nil
    if self.playerID then 
        name = LobbyPlayer:getName(self.playerID)
    end
    drawBall:draw(
        self.x + offsetX,
        self.y + offsetY,
        self.yaw,self.pitch,
        self.colour,1,
        name
    )
end

function Ball:updateRoll()
    self:roll(self.x-self.lx,self.y-self.ly)
    self.lx = self.x
    self.ly = self.y
end

local camera = {x=0,y=0,vx=0,vy=0,focus = nil}

function camera:update(dt)
    local centre = {
        x = (self.x + self.focus.x) / 2,
        y = (self.y + self.focus.y) / 2
    }
    --attraction force of camera to the ball
    local forceMult = 10
    --Elastic rope radius
    self.vx = self.vx + (centre.x - self.x) * (forceMult)
    self.vy = self.vy + (centre.y - self.y) * (forceMult)

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

--World table, stores and processes all balls
World = {
    balls         = {},
    playableBalls = {},
    ballIDDict    = {},
    ropes         = {},
    focus         = nil,
    debugChecks   = false,
    debugGrid     = false
}

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
        local ID1 = rope[1]
        local ID2 = rope[2]
        local rope1 = self:getByID(ID1)
        local rope2 = self:getByID(ID2)
        local ropeLength = rope[3]
        local ropeCentre = {
            x = (rope1.x + rope2.x) / 2,
            y = (rope1.y + rope2.y) / 2
        }
        --manhattan distance is very cheap to calculate, so used to prevent exessive square root calculions when they aren't necessary
        local manhattan = math.abs(rope2.x - rope1.x) + math.abs(rope2.y-rope1.y)
        if manhattan >= ropeLength then
            process({rope1,rope2},ropeCentre,ropeLength,0.5)
        end
    end
end

--Follows a ball with the camera
function World:setFocus(ball)
    camera.focus = ball
end

--Clears all balls
function World:clear()
    self.balls = {}
    self.playableBalls = {}
    self.ballIDDict = {}
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
    if playable then table.insert(self.playableBalls,nBall) end
    return nBall
end

--Assigns IDs to every ball, passing in a salt value to avoid duplicate IDs
function World:generateIDs()
    local IDs = {}
    for i,ball in ipairs(self.balls) do
        local ID = self:assignID(ball,nil,i)
        table.insert(IDs,ID)
    end
    table.insert(self.ropes,{IDs[1],IDs[2],100})
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

--Collisions with no optimisation
function World:expensiveCollisions(ballIDs)
    local bounce = 1
    local function collision(ID1,ID2)
        checks = checks + 1
        local ball1 = self:getByID(ID1)
        local ball2 = self:getByID(ID2)
        
        local collisionAxis = {x=0,y=0}
        collisionAxis.x = ball1.x - ball2.x
        collisionAxis.y = ball1.y - ball2.y
        local distance = Util:findDistance(collisionAxis.x,collisionAxis.y)
        local diameter = ball1.radius + ball2.radius
        --If they collide:
        if distance < diameter then
            local speed1 = Util:findDistance(ball1.vx,ball1.vy)
            local speed2 = Util:findDistance(ball2.vx,ball2.vy)

            local n = collisionAxis
            n.x = n.x / distance
            n.y = n.y / distance
            local delta = diameter - distance
            local offset1 = ball2.radius / ball1.radius
            local offset2 = ball1.radius / ball2.radius
            if offset1 > 2 then offset1 = 2 end
            if offset2 > 2 then offset2 = 2 end
            ball2.x = ball2.x - bounce * offset2 * delta * n.x
            ball2.y = ball2.y - bounce * offset2 * delta * n.y
            ball1.x = ball1.x + bounce * offset1 * delta * n.x
            ball1.y = ball1.y + bounce * offset1 * delta * n.y
        end
    end
    
    local existingCheck = {}
    for i, ID1 in ipairs(ballIDs) do
        for j, ID2 in ipairs(ballIDs) do
            if i ~= j then
                local sum = 0
                sum = sum + tonumber(ID1) * 17
                sum = sum + tonumber(ID2) * 17
                if not existingCheck[sum] then
                    collision(ID1,ID2)
                    existingCheck[sum] = true
                end
            end
        end
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
                    for j,ball in ipairs(cell) do
                        local ID = ball
                        table.insert(neighbors,ID)
                    end
                end
            end
        end
        if #neighbors > 1 then
            local sum = 0
            for j,ID in ipairs(neighbors) do
                sum = sum + tonumber(ID) * 17
            end
            if not existingNeighbours[sum] then
                self:expensiveCollisions(neighbors)
                existingNeighbours[sum] = true
            end
        end
    end
end

--Updates the position of every ball
function World:update(dt,isClient)
    checks = 0
    self:populate()
    camera:update(dt)
    self:updateRopes()
    for i, ball in ipairs(self.balls) do
        if isClient then
            ball:verlet(dt)
        else
            ball:edgeConstraint()
            ball:verlet(dt)
        end
    end
    if not isClient then
        self:optimisedCollisions()
    end
end

--Draw every ball
function World:draw()
    local offsetX,offsetY = camera:getOffset()
    love.graphics.setColor( 0,0.4,0 )
    love.graphics.rectangle("fill",offsetX,offsetY,4096,4096)
    for i, ball in ipairs(self.balls) do
        ball:draw(offsetX,offsetY)
    end
    if self.debugGrid then grid:draw(offsetX,offsetY) end
    if self.debugChecks then love.graphics.print("collision checks: "..checks,0,200) end
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
        table.insert(out,"upgm:"..ball.ID..Util:coordToHex(ball.x,ball.y))
    end
    return out
end

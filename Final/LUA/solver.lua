require("util")
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
    if self.x + self.radius > 800 then
        self.x   = 800 - self.radius
        self.vx  = -self.vx
        self.lvx = -self.lvx
    end
    if self.y - self.radius < 0 then
        self.y   = self.radius
        self.vy  = -self.vy
        self.lvy = -self.lvy
    end
    if self.y + self.radius > 600 then
        self.y   = 600 - self.radius
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

--World table, stores and processes all balls
World = {
    balls         = {},
    playableBalls = {},
    ballIDDict    = {},
    focus         = nil
}

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
    for i,ball in ipairs(self.balls) do
        self:assignID(ball,nil,i)
    end
end

--Assigns a playerID to the ball
function World:assign(playerIDs)
    for i,playerID in ipairs(playerIDs) do
        local ball = self.playableBalls[i]
        if ball then
            ball.playerID = playerID
            LobbyPlayer:setBallID(playerID,ball.ID)
        end
    end
end

--Follows a ball with the camera
function World:setFocus(ball)
    self.focus = ball
end

--Gets the offset for drawing objects
function World:getOffset()
    if not self.focus then return 0,0 end
    return windowDims.x/2 - self.focus.x, windowDims.y/2 - self.focus.y
end

--Collisions with no optimisation
function World:expensiveCollisions(balls)
    local bounce = 1
    for i, ball1 in ipairs(balls) do
        for j, ball2 in ipairs(balls) do
            if i ~= j then
                local collisionAxis = {x=0,y=0}
                collisionAxis.x = ball1.x - ball2.x
                collisionAxis.y = ball1.y - ball2.y
                local distance = Util:findDistance(collisionAxis.x,collisionAxis.y)
                local diameter = ball1.radius + ball2.radius
                --If they collide:
                if distance < diameter then
                    local speed1 = Util:findDistance(ball1.vx,ball1.vy)
                    local speed2 = Util:findDistance(ball2.vx,ball2.vy)

                    --Stuff with teams of neutral balls

                    -- local team1 = ball1:getTeam()
                    -- local team2 = ball2:getTeam()
                    -- --Changing temporary teams
                    -- if speed1 >= speed2 then
                    --     if team1 and not team2 then
                    --         ball2:setTeam(team1)
                    --     end
                    -- else
                    --     if team2 and not team1 then
                    --         ball1:setTeam(team2)
                    --     end
                    -- end

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
        end
    end
end

--Updates the position of every ball
function World:update(dt,isClient)
    for i, ball in ipairs(self.balls) do
        if isClient then
            ball:verlet(dt)
        else
            ball:edgeConstraint()
            ball:verlet(dt)
        end
    end
    if not isClient then
        self:expensiveCollisions(self.balls)
    end
end

--Draw every ball
function World:draw()
    local offsetX,offsetY = World:getOffset()
    for i, ball in ipairs(self.balls) do
        ball:draw(offsetX,offsetY)
    end
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

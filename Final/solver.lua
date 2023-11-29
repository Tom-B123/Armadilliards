require("util")

local Ball = {}
Ball.__index = Ball

--Create a new ball object
function Ball:new(x,y)
    local object = {}
    setmetatable(object,Ball)
    object.ID = ""
    object.playerID = nil
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
    object.radius = 16
    object.colour = {1,1,1}
    return object
end

--Move a ball
function Ball:move(x,y)
    self.x = self.x + x
    self.y = self.y + y
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

--Drawing ball objects
function Ball:draw()
    love.graphics.circle("fill",self.x,self.y,self.radius)
end

--World table, stores and processes all balls
World = {balls = {},playableBalls = {},ballIDDict = {}}

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

--Updates the position of every ball
function World:update(dt)
    for i, ball in ipairs(self.balls) do
        ball:verlet(dt)
    end
end

--Draw every ball
function World:draw()
    for i, ball in ipairs(self.balls) do
        love.graphics.setColor(ball.colour)
        ball:draw()
    end
end

--Create a string for assigning players to a ballID for taking player inputs
function World:getAsgn()
    local out = ""
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
    local out = ""
    for i, ball in ipairs(self.balls) do
        out = out..ball.ID.."_"..ball.x.."_"..ball.y
        if i < #self.balls then out = out.."_" end
    end
    return out
end

require("util")

local Ball = {}
Ball.__index = Ball
function Ball:new(x,y)
    local object = {}
    setmetatable(object,Ball)
    object.ID = Util:calculateID(6)
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

function Ball:move(x,y)
    self.x = self.x + x
    self.y = self.y + y
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

function Ball:draw()
    love.graphics.circle("fill",self.x,self.y,self.radius)
end

World = {balls = {},playableBalls = {}}

function World:newBall(x,y,playable)
    local nBall = Ball:new(x,y)
    table.insert(self.balls,nBall)
    if playable then table.insert(self.playableBalls,nBall) end
end

function World:assign(playerID)
    self.playableBalls[#self.playableBalls].playerID = playerID
    table.remove(self.playableBalls,#self.playableBalls)
    print(#self.playableBalls)
end

function World:update(dt)
    for i, ball in ipairs(self.balls) do
        ball:verlet(dt)
    end
end

function World:draw()
    for i, ball in ipairs(self.balls) do
        love.graphics.setColor(ball.colour)
        ball:draw()
    end
end
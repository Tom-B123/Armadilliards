require("util")

Ball = {}
Ball.__index = Ball
function Ball:new(x,y)
    local object = {}
    setmetatable(object,Ball)
    object.ID = Util:calculateID(6)
    object.x = x
    object.y = y
    object.vx = 0
    object.vy = 0
    object.lx = x
    object.ly = y
    object.lvx = 0
    object.lvy = 0
    object.radius = 16
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

World = {balls = {}}

function World:update()
    for i, ball in ipairs(self.balls) do
        ball:verlet()
    end
end

function World:draw()
    for i, ball in ipairs(self.balls) do
        ball:draw()
    end
end
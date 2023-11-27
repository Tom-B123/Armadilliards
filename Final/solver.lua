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
end

Solver = {}
function Solver:verlet(ball)
end
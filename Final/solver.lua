require("util")

Ball = {}
Ball.__index = Ball
function Ball:new()
    local object = {}
    setmetatable(object,Ball)
    object.ID = Util:calculateID(6)
end

Solver = {}
function Solver:verlet(ball)
end
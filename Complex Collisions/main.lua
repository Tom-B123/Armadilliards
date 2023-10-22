Shape = {}
Shape.__index = Shape

function Shape:new(shape,dims,colour,fill)
    local object = {}
    setmetatable(object,Shape)
    object.shape = shape
    object.colour = colour
    object.fill = "line" and not fill or "fill" and fill
    if shape == "circle" then
        object.x = dims[1]
        object.y = dims[2]
        object.radius = dims[3]
    elseif shape == "poly" then
        object.coords = dims
    end
    return object
end

function Shape:draw()
    love.graphics.circle(self.fill,self.x,self.y,self.radius)
end

local circle = Shape:new()

function love.update()
end

function love.draw()
end
Shape = {}
Shape.__index = Shape

function Shape:new(shape,dims,colour,fill)
    local object = {}
    setmetatable(object,Shape)
    object.shape = shape
    object.colour = colour
    object.fill = "line"
    if fill then object.fill = "fill" end
    if shape == "circle" then
        object.coords = {
            dims[1],
            dims[2]
        }
        object.radius = dims[3]
    elseif shape == "poly" then
        object.coords = dims
    end
    return object
end

function Shape:draw()
    if self.shape == "circle" then
        love.graphics.circle(self.fill,self.coords[1],self.coords[2],self.radius)
    elseif self.shape == "poly" then
        love.graphics.polygon(self.fill,self.coords)
    end
end

function Shape:move(x,y)
    
end

local circle = Shape:new("circle",{100,100,50},{1,1,1},false)
local triangle = Shape:new("poly",{200,200,300,200,250,300},{1,1,1},false)

function love.update()
    circle.x = circle.x + 1
end

function love.draw()
    circle:draw()
    triangle:draw()
end
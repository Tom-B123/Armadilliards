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
    for i,v in ipairs(self.coords) do
        if i % 2 == 1 then self.coords[i] = self.coords[i] + x
        else self.coords[i] = self.coords[i] + y
        end
    end
end

function Shape:getLines()
    local lx,ly = nil,nil
    local dx,dy = nil,nil
    local lines = {}
    for i,coord in ipairs(self.coords) do
        if i % 2 == 1 then
            local x = coord
            if lx ~= nil then
                dx = lx - x
            end
            lx = x
        else
            local y = coord
            if ly ~= nil then
                dy = ly - y
            end
            table.insert(lines,(dy/dx))
            ly = y
        end
    end
    return lines
end

local circle = Shape:new("circle",{100,100,50},{1,1,1},false)
local triangle = Shape:new("poly",{200,200,300,200,250,300},{1,1,1},false)

function love.update()
    circle:move(1,0)
    triangle:move(2,0)
end

function love.draw()
    circle:draw()
    triangle:draw()
end
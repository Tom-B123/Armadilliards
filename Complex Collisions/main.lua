
local function getAngle(x,y)
    local ax,ay = math.abs(x),math.abs(y)
    if x > 0 and y >= 0 then
        return math.atan(ay/ax)
    elseif x <= 0 and y > 0 then
        return math.atan(ax/ay) + math.pi / 2
    elseif x < 0 and y <= 0 then
        return math.atan(ay/ax) + math.pi
    elseif x >= 0 and y < 0 then
        return math.atan(ax/ay) + math.pi * 3 / 2
    end
end

local function getDistance(x,y)
    return (x^2+y^2)^0.5
end

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
    local function isInf(num)
        return num == math.huge or num == -math.huge
    end
    local lx,ly = nil,nil
    local dx,dy = nil,nil
    local lines = {}
    local points = #self.coords / 2
    --If it is a point or a line, loop one less time
    if points < 3 then
        points = points - 1
    end
    for i = 1,(points + 1) do
        local x,y = self.coords[2*i-1],self.coords[2*i]
        if i > points then 
            x = self.coords[2*i-1-#self.coords]
            y = self.coords[2*i-#self.coords]
        end
        if lx ~= nil then
            dx = lx - x
        end
        
        if ly ~= nil then
            dy = ly - y
        end
        if dx and dy then
            local gradient = dy/dx
            local yInt = "none"
            if not isInf(gradient) then
                yInt = y - gradient * x
            end
            local line = {gradient,yInt,lx,x}
            table.insert(lines,line)
        end
        lx = x
        ly = y
    end
    return lines
end

function Shape:intersects(shape)
    if self.shape == "poly" and shape.shape == "poly" then
        
    end
end

function Shape:rotate(angle)
    local centre = {x=0,y=0}
    local points = #self.coords / 2
    for i,coord in ipairs(self.coords) do
        if i % 2 == 1 then
            centre.x = centre.x + coord
        else
            centre.y = centre.y + coord
        end
    end
    centre.x = centre.x / points
    centre.y = centre.y / points
    for i = 1,points do
        local x,y = self.coords[2*i-1],self.coords[2*i]
        local distanceTo = getDistance(centre.x-x,centre.y-y)
        local angleTo = getAngle(x-centre.x,y-centre.y)
        local newAngle = angleTo + angle
        self.coords[2*i-1] = centre.x + distanceTo*math.cos(newAngle)
        self.coords[2*i] = centre.y + distanceTo*math.sin(newAngle)
    end
    
end


local circle = Shape:new("circle",{100,350,50},{1,1,1},false)
local square = Shape:new("poly",{400,300,500,300,500,400,400,400},{1,1,1},false)
local triangle = Shape:new("poly",{400,300,500,300,450,400},{1,1,1},false)

triangle:move(-300,0)

function love.update(dt)
    -- circle:move(100 * dt,0)
    -- square:move(50 * dt,0)
    -- triangle:move(10*dt,0)
    triangle:rotate(math.pi / 180)
end

function love.draw()
    love.graphics.print("fps: "..tostring(love.timer.getFPS()),600,0)
    circle:draw()
    square:draw()
    triangle:draw()
    for i,line in ipairs(triangle:getLines()) do
        love.graphics.circle("fill",line[3],line[2],10)
        love.graphics.circle("fill",line[4],line[2],10)
        love.graphics.print(line[1]..","..line[2],0,i*20)
    end
end
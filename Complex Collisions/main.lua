
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

local lmx,lmy = love.mouse.getPosition()

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
    love.graphics.setColor(self.colour)
    if self.shape == "circle" then
        love.graphics.circle(self.fill,self.coords[1],self.coords[2],self.radius)
    elseif self.shape == "poly" then
        if #self.coords == 4 then
            love.graphics.line(self.coords)
        elseif #self.coords > 4 then
            love.graphics.polygon(self.fill,self.coords)
        end
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
        if x and y then 
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
                local line = {gradient,yInt,lx,x,ly,y}
                table.insert(lines,line)
            end
            lx = x
            ly = y
        end
    end
    return lines
end

function Shape:intersects(shape)
    local isIntersecting = false
    if self.shape == "poly" and shape.shape == "poly" then
        local lines1 = self:getLines()
        local lines2 = shape:getLines()
        
        for i,line1 in ipairs(lines1) do
            for j,line2 in ipairs(lines2) do
                local xMinimums = {
                    math.min(line1[3],line1[4]),
                    math.min(line2[3],line2[4])
                }
                local xMaximums = {
                    math.max(line1[3],line1[4]),
                    math.max(line2[3],line2[4])
                }
                local yMinimums = {
                    math.min(line1[5],line1[6]),
                    math.min(line2[5],line2[6])
                }
                local yMaximums = {
                    math.max(line1[5],line1[6]),
                    math.max(line2[5],line2[6])
                }
                local xOverlap = {
                    math.max(xMinimums[1],xMinimums[2]),
                    math.min(xMaximums[1],xMaximums[2])
                }
                local yOverlap = {
                    math.max(yMinimums[1],yMinimums[2]),
                    math.min(yMaximums[1],yMaximums[2])
                }

                local xIntersect
                local yIntersect
                
                local lGradient = line1[1]
                local lIntercept = line1[2]
                local rGradient = line2[1]
                local rIntercept = line2[2]
                
                if line1[3] == line1[4] then
                    xIntersect = line1[3]
                    yIntersect = xIntersect * rGradient * rIntercept
                elseif line2[3] == line2[4] then
                    xIntersect = line2[3]
                    yIntersect = xIntersect * lGradient * lIntercept
                else
                    xIntersect = (rIntercept - lIntercept) / (lGradient - rGradient)
                    yIntersect = lGradient * xIntersect + lIntercept
                end
                if xOverlap[1] <= xIntersect and xIntersect <= xOverlap[2] then
                    if yOverlap[1] <= yIntersect and yIntersect <= yOverlap[2] then
                        isIntersecting = true
                    end
                end
                -- love.graphics.setColor(1,0,0)
                -- love.graphics.line(overlap[1],0,overlap[1],600)
                -- love.graphics.setColor(0,0,1)
                -- love.graphics.line(overlap[2],0,overlap[2],600)
            end
        end
    end
    if isIntersecting then self.fill = "fill"
    else self.fill = "line"
    end
    return isIntersecting
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

local line1 = Shape:new("poly",{5,500,500,5,5,5},{1,1,1},false)
local line2 = Shape:new("poly",{100,100,400,400,100,400},{1,1,1},false)

triangle:move(-300,0)

function love.update(dt)
    local mx,my = love.mouse.getPosition()
    line1:move(-(lmx-mx),-(lmy-my))
    line1:rotate(math.pi/180)
    lmx = mx
    lmy = my
end

function love.draw()
    love.graphics.setColor(1,1,1)
    love.graphics.print("fps: "..tostring(love.timer.getFPS()),600,0)
    line1:draw()
    line2:draw()
    line1:intersects(line2)
    -- circle:draw()
    -- square:draw()
    -- triangle:draw()
    -- for i,line in ipairs(triangle:getLines()) do
    --     love.graphics.circle("fill",line[3],line[2],10)
    --     love.graphics.circle("fill",line[4],line[2],10)
    --     love.graphics.print(line[1]..","..line[2],0,i*20)
    -- end
end
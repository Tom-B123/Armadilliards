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
    local corners = #self.coords / 2
    --If it is a point or a line, loop one less time
    if corners < 3 then
        corners = corners - 1
    end
    for i = 1,(corners + 1) * 2 do
        local coord = self.coords[i]
        if i > #self.coords then 
            coord = self.coords[i-#self.coords]
        end
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
            if dx and dy then
                local gradient = dy/dx
                local yInt = "none"
                if not isInf(gradient) then
                    yInt = y - gradient * lx
                end
                local line = {gradient,yInt}
                table.insert(lines,line)
            end
            ly = y
        end
    end
    return lines
end

local circle = Shape:new("circle",{100,100,50},{1,1,1},false)
local square = Shape:new("poly",{300,380,400,310,440,410,340,410},{1,1,1},false)

function love.update()
    circle:move(1,0)
    square:move(2,0)
end

function love.draw()
    circle:draw()
    square:draw()
    for i,line in ipairs(square:getLines()) do
        love.graphics.print(line[1]..line[2],10,i*20)
    end
end
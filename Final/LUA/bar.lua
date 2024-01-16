--Bar:

--Draws a bar with a given x,y,maximum width, height, and full vs nearly empty colour
local bar = {}

bar.__index = bar

function bar:new(x,y,w,h,base,filled)
    local object = {}
    setmetatable(object,bar)
    object.x = x
    object.y = y
    object.w = w
    object.h = h
    object.base     = base
    object.filled   = filled
    object.target   = 0
    object.fraction = 0

    return object
end

function bar:update()
    self.fraction = self.fraction + (self.target - self.fraction) / 10
end

--Draws a bar, filled fully with filled colour with fraction = 1
--Draws the bar completely empty with base colour with fraction = 0
function bar:draw()

    --Sets the colour to be between base colour and filled colour, by a given fraction
    love.graphics.setColor(
        self.base[1] * (1 - self.fraction) + self.filled[1] * self.fraction,
        self.base[2] * (1 - self.fraction) + self.filled[2] * self.fraction,
        self.base[3] * (1 - self.fraction) + self.filled[3] * self.fraction,
        0.4
    )

    --Draws the border outline for the bar
    love.graphics.rectangle("fill",self.x-2,self.y-2,self.w+4,self.h+4)

    love.graphics.setColor(
        self.base[1] * (1 - self.fraction) + self.filled[1] * self.fraction,
        self.base[2] * (1 - self.fraction) + self.filled[2] * self.fraction,
        self.base[3] * (1 - self.fraction) + self.filled[3] * self.fraction,
        1
    )
    
    --Draws the filled fraction of the bar
    love.graphics.rectangle("fill",self.x,self.y,self.w * self.fraction,self.h)
end

return bar
local bar = {}

bar.__index = bar

function bar:new(x,y,w,h,base,filled)
    local object = {}
    setmetatable(object,bar)
    object.x = x
    object.y = y
    object.w = w
    object.h = h
    object.base = base
    object.filled = filled
    object.fraction = 0

    return object
end

function bar:update(fraction,x,y)
    self.fraction = fraction
    self.x = x
    self.y = y
end

function bar:draw()
    love.graphics.setColor(
        self.base[1] * (1 - self.fraction) + self.filled[1] * self.fraction,
        self.base[2] * (1 - self.fraction) + self.filled[2] * self.fraction,
        self.base[3] * (1 - self.fraction) + self.filled[3] * self.fraction,
        0.2
    )
    love.graphics.rectangle("fill",self.x - self.w/2,self.y - self.h/2,self.w,self.h)

    love.graphics.setColor(
        self.base[1] * (1 - self.fraction) + self.filled[1] * self.fraction,
        self.base[2] * (1 - self.fraction) + self.filled[2] * self.fraction,
        self.base[3] * (1 - self.fraction) + self.filled[3] * self.fraction,
        1
    )
    love.graphics.rectangle("fill",self.x - self.w/2,self.y - self.h/2,self.w * self.fraction,self.h)
end

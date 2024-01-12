local bar = {}

-- bar.__index = bar

-- function bar:new(x,y,w,h,base,filled)
--     local object = {}
--     setmetatable(object,bar)
--     object.x = x
--     object.y = y
--     object.w = w
--     object.h = h
--     object.base = base
--     object.filled = filled
--     object.fraction = 0

--     return object
-- end

-- function bar:update(fraction,x,y)
--     self.fraction = fraction
--     self.x = x
--     self.y = y
-- end

function bar:draw(fraction,x,y,w,h,base,filled)
    print("health bar")
    love.graphics.setColor(
        base[1] * (1 - fraction) + filled[1] * fraction,
        base[2] * (1 - fraction) + filled[2] * fraction,
        base[3] * (1 - fraction) + filled[3] * fraction,
        0.2
    )
    love.graphics.rectangle("fill",x - w/2,y - h/2,w,h)

    love.graphics.setColor(
        base[1] * (1 - fraction) + filled[1] * fraction,
        base[2] * (1 - fraction) + filled[2] * fraction,
        base[3] * (1 - fraction) + filled[3] * fraction,
        1
    )
    love.graphics.rectangle("fill",x - w/2,y - h/2,w * fraction,h)
end

return bar
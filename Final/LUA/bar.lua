local bar = {}

function bar:draw(fraction,x,y,w,h,base,filled)
    love.graphics.setColor(
        base[1] * (1 - fraction) + filled[1] * fraction,
        base[2] * (1 - fraction) + filled[2] * fraction,
        base[3] * (1 - fraction) + filled[3] * fraction,
        0.4
    )
    love.graphics.rectangle("fill",x,y,w,h)

    love.graphics.setColor(
        base[1] * (1 - fraction) + filled[1] * fraction,
        base[2] * (1 - fraction) + filled[2] * fraction,
        base[3] * (1 - fraction) + filled[3] * fraction,
        1
    )
    love.graphics.rectangle("fill",x,y,w * fraction,h)
end

return bar
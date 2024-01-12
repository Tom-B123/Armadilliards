--Draws a bar with a given x,y,maximum width, height, and full vs nearly empty colour
local bar = {}

--Draws a bar, filled fully with filled colour with fraction = 1
--Draws the bar completely empty with base colour with fraction = 0
function bar:draw(fraction,x,y,w,h,base,filled)

    --Sets the colour to be between base colour and filled colour, by a given fraction
    love.graphics.setColor(
        base[1] * (1 - fraction) + filled[1] * fraction,
        base[2] * (1 - fraction) + filled[2] * fraction,
        base[3] * (1 - fraction) + filled[3] * fraction,
        0.4
    )

    --Draws the border outline for the bar
    love.graphics.rectangle("fill",x-2,y-2,w+4,h+4)

    love.graphics.setColor(
        base[1] * (1 - fraction) + filled[1] * fraction,
        base[2] * (1 - fraction) + filled[2] * fraction,
        base[3] * (1 - fraction) + filled[3] * fraction,
        1
    )
    
    --Draws the filled fraction of the bar
    love.graphics.rectangle("fill",x,y,w * fraction,h)
end

return bar
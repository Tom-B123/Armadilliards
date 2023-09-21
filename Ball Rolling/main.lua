local balls = {}
local i = 0
local toDraw = {}
for i = 0,15 do
    balls[i+1] = love.graphics.newImage("BlackBall"..i..".png")
end

local pos = {x=128,y=16}
function love.load()
end
function love.update()
    i = i + 2
end
local function drawBall(roll,velocity,rotation)
    roll = roll % 360
    pos.x = pos.x + velocity * math.cos(rotation)
    pos.y = pos.y + velocity * math.sin(rotation)
    if 0 <= roll and roll < 90 then
        love.graphics.draw(balls[math.floor(roll/5.625)+1],pos.x,pos.y,0+rotation,1,1,0,0)
    end
    if 90 <= roll and roll < 270 then
        love.graphics.draw(balls[16],pos.x,pos.y,0+rotation,1,1,0,0)
    end
    if 270 <= roll and roll < 360 then
        love.graphics.draw(balls[16 - math.floor((roll % 90)/5.625)],pos.x,pos.y,math.pi+rotation,1,1,32,32)
    end
end
function love.draw()
    drawBall(i*2,4,i * math.pi / 180)
end
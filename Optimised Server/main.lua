local socket = require('socket')
local server = assert(socket.bind("*", 12345))

local tick = 0

Recieved = {}

server:settimeout(0)

Server = {clients = {}}

World = {balls = {}}

Command = {}

--Do some custom switch case

-- Switch = {dict = {}}

-- function Switch:new(values)
-- end

--==Helper functions==--

local function round(n,p)
    return math.floor((10^p*n)+0.5) / 10^p
end

function love.keypressed(key)
	if key == "escape" then
	  love.event.quit()
	end
end

--==Main functions==--

function Command:compile(type,balls)
    local out = ""
    if type == "initiate"   then out = out.."0:"
    elseif type == "update" then out = out.."1:"
    else return nil,"Type Error" end
    for i,ball in ipairs(balls) do
        out = out..ball.id.."-"
        out = out..round(ball.x,1) .."-"
        out = out..round(ball.y,1) .."-"
        out = out..round(ball.lx,1) .."-"
        out = out..round(ball.ly,1) .."-"
        out = out..round(ball.vx,3).."-"
        out = out..round(ball.vy,3).."-"
        out = out..round(ball.lvx,3).."-"
        out = out..round(ball.lvy,3)
        if i < #balls then out = out.."," end
    end
    return out, nil
end

function World:new(id,team,radius,x,y,vx,vy,ax,ay)
    local ball = {}
    ball.id = id
    ball.team = team
    ball.radius = radius
    ball.x   = x
    ball.y   = y
    ball.vx  = vx
    ball.vy  = vy
    ball.ax  = ax
    ball.ay  = ay
    ball.lx  = x
    ball.ly  = y
    ball.lvx = vx
    ball.lvy = vy
    ball.lax = ax
    ball.lay = ay

    table.insert(self.balls,ball)
end

function World:verlet(dt)

    for i,ball in ipairs(self.balls) do
        local nextVX = (ball.ax * dt * dt) + ball.x - ball.lx
        local nextVY = (ball.ay * dt * dt) + ball.y - ball.ly

        ball.vx = (ball.vx + ball.lvx) / 2
        ball.vy = (ball.vy + ball.lvy) / 2

        local nextX = (ball.x + ball.vx)
        local nextY = (ball.y + ball.vy)

        ball.lx = ball.x
        ball.ly = ball.y

        ball.x = nextX
        ball.y = nextY

        ball.lvx = ball.vx * 0.99
        ball.lvy = ball.vy * 0.99

        ball.vx = nextVX
        ball.vy = nextVY

        ball.ax = 0
        ball.ay = 0

        if math.abs(ball.vx) < 0.02 then ball.vx = 0 end
        if math.abs(ball.vy) < 0.02 then ball.vy = 0 end
    end
end

function World:constraint()
    for i,ball in ipairs(self.balls) do
        ball.vx = ball.vx
        ball.vy = ball.vy
        if ball.x < ball.radius then 
            ball.x = ball.radius
            ball.vx = - ball.vx
            ball.lvx = - ball.lvx
        end
        if ball.y < ball.radius then 
            ball.y = ball.radius
            ball.vy = - ball.vy
            ball.lvy = - ball.lvy
        end
        if ball.x > love.graphics.getWidth() - ball.radius then 
            ball.x = love.graphics.getWidth() - ball.radius
            ball.vx = - ball.vx
            ball.lvx = - ball.lvx
        end
        if ball.y > love.graphics.getHeight() - ball.radius then 
            ball.y = love.graphics.getHeight() - ball.radius
            ball.vy = - ball.vy
            ball.lvy = - ball.lvy
        end

    end
end

function Server:update(dt)
    
    local newClient = server:accept()
    if newClient then
        table.insert(self.clients, newClient)
        -- newClient:send(#self.clients+1)
    end
end

function Server:sendToClient(message)
    for i, client in ipairs(self.clients) do
        client:send(message.."\n")
    end
end

function Server:receiveFromClient(clients)
    --if no clients are specified, recieve from all of them
    if clients == nil then clients = self.clients end

    local dataOut = {}
    for i,client in ipairs(clients) do
        local data, err = client:receive()
        if data then dataOut[i] = data
        elseif err == "closed" then
            -- Client disconnected
            client:close()
            table.remove(clients, i)
        end
    end
    return dataOut
end

World:new(1,{1,1,1},25,100,100,10,10,0,0)
World:new(2,{1,0,1},25,200,100,0,0,0,0)

--==love functions==

function love.load()
    love.window.setTitle("Server")
end

function love.update(dt)
    tick = tick + 1
    World:verlet(dt)
    World:constraint()
    Server:update()
    local data = Server:receiveFromClient()
    if data ~= nil then Recieved = data end
    
    if tick % 4 == 0 then
        local ball = World.balls[1]
        local toSend = {
            round(ball.x,1),
            round(ball.y,1),
            round(ball.vx,2),
            round(ball.vy,2)
        }
        local message = ""
        for i, at in ipairs(toSend) do
            message = message..at.."-"
        end
        Server:sendToClient(message)
    end
end

function love.draw()
    local data,err = Command:compile("update",World.balls)
    if data then love.graphics.print(data,200,0) end
    for i,ball in ipairs(World.balls) do
        love.graphics.setColor(ball.team)
        love.graphics.circle(
            "line",
            ball.x,
            ball.y,
            ball.radius
        )
    end
    love.graphics.setColor(1,1,1)
    love.graphics.print("server tick: "..tick,20,0)
    for i,message in ipairs(Recieved) do
        love.graphics.print("client "..i.." tick: "..message,20,i*20)
    end
end

local socket = require('socket')
local server = assert(socket.bind("*", 12345))

local tick = 0

Recieved = {}

server:settimeout(0)

Server = {clients = {}}

World = {balls = {}}

Command = {}

local ids = {"1","2"}
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

local function split(str,sep)
    local out = {}
    for i in string.gmatch(str,"([^"..sep.."]+)") do
        table.insert(out,i)
    end
    return out
end

--==Main functions==--

function Command:compile(operation,balls)
    local out = ""
    if operation == "initiate"   then out = out.."0:"
    elseif operation == "update" then out = out.."1:"
    else return nil,"Operation Error" end
    for i,ball in ipairs(balls) do
        out = out..ball.id.."_"
        out = out..round(ball.x,1)  .."_"
        out = out..round(ball.y,1)  .."_"
        out = out..round(ball.vx,1) .."_"
        out = out..round(ball.vy,1) .."_"
        out = out..round(ball.lx,3) .."_"
        out = out..round(ball.ly,3) .."_"
        out = out..round(ball.lvx,3).."_"
        out = out..round(ball.lvy,3)
        if i < #balls then out = out.."," end
    end
    return out, nil
end

function Command:decompile(string)
    --Split the operation from the ball data
    local colonDiv = split(string,":")
    --return error if there are multiple colons in the string
    if #colonDiv ~= 2 then return nil,"Colon error" end

    local operation,balls = colonDiv[1],colonDiv[2]
    --initialise the output table
    local out = {operation = operation, balls = {}}
    for i,ball in ipairs(split(balls,",")) do

        local tempArr = {}

        local dashDiv = split(ball,"_")
        --Create a dictionary from the ball ID to the ball stats.
        tempArr = {
            x = dashDiv[2],
            y = dashDiv[3],
            vx = dashDiv[4],
            vy = dashDiv[5],
            lx = dashDiv[6],
            ly = dashDiv[7],
            lvx = dashDiv[8],
            lvy = dashDiv[9]
        }
        out.balls[dashDiv[1]] = tempArr
    end
    return out
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

        ball.lvx = ball.vx
        ball.lvy = ball.vy

        ball.vx = nextVX
        ball.vy = nextVY

        ball.ax = 0
        ball.ay = 0

        if math.abs(ball.vx) < 0.02 then ball.vx = 0 end
        if math.abs(ball.vy) < 0.02 then ball.vy = 0 end
    end
end

function World:constraint()
    --Only updates client side balls when a collision takes place.
    local ballsToUpdate = {}
    for i,ball in ipairs(self.balls) do
        ball.vx = ball.vx
        ball.vy = ball.vy
        if ball.x < ball.radius then
            table.insert(ballsToUpdate,ball)
            ball.x = ball.radius
            ball.vx = - ball.vx
            ball.lvx = - ball.lvx
        end
        if ball.y < ball.radius then
            table.insert(ballsToUpdate,ball)
            ball.y = ball.radius
            ball.vy = - ball.vy
            ball.lvy = - ball.lvy
        end
        if ball.x > love.graphics.getWidth() - ball.radius then
            table.insert(ballsToUpdate,ball)
            ball.x = love.graphics.getWidth() - ball.radius
            ball.vx = - ball.vx
            ball.lvx = - ball.lvx
        end
        if ball.y > love.graphics.getHeight() - ball.radius then
            table.insert(ballsToUpdate,ball)
            ball.y = love.graphics.getHeight() - ball.radius
            ball.vy = - ball.vy
            ball.lvy = - ball.lvy
        end
    end
    Server:update(ballsToUpdate)
end

function Server:updateConnections()
    
    local newClient = server:accept()
    if newClient then
        table.insert(self.clients, newClient)
        Server:update(World.balls)
        -- newClient:send(#self.clients+1)
    end
end

function Server:update(balls)
    local message = Command:compile("update",balls)
    self:sendToClient(message)
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

World:new(ids[1],{1,1,1},25,100,100,10,10,0,0)
World:new(ids[2],{1,0,1},25,200,100,-10,0,0,0)

--==love functions==

function love.load()
    love.window.setTitle("Server")
end

function love.update(dt)
    tick = tick + 1
    Server:updateConnections()
    World:verlet(dt)
    World:constraint()
    
    local data = Server:receiveFromClient()
    if data ~= nil then Recieved = data end
end

function love.draw()
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

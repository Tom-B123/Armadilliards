local socket = require('socket')
local server = assert(socket.bind("*", 12345))

local tick = 0

local divider = 50
local xLen = math.floor(love.graphics.getWidth() / divider)
local yLen = math.floor(love.graphics.getHeight() / divider)

Recieved = {}

server:settimeout(0)

Server = {clients = {}}

World = {balls = {}, grid = {}}

for i = 1,yLen do
    World.grid[i] = {}
    for j = 1,xLen do
        World.grid[i][j] = {}
    end
end

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
        local posPlaces = 1
        local velPlaces = 4
        out = out..ball.id.."_"
        out = out..round(ball.x,  posPlaces)  .."_"
        out = out..round(ball.y,  posPlaces)  .."_"
        out = out..round(ball.vx, velPlaces) .."_"
        out = out..round(ball.vy, velPlaces) .."_"
        out = out..round(ball.lx, posPlaces) .."_"
        out = out..round(ball.ly, posPlaces) .."_"
        out = out..round(ball.lvx,velPlaces).."_"
        out = out..round(ball.lvy,velPlaces)
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

function World:new(id,team,x,y,vx,vy,ax,ay)
    local ball = {}
    ball.id = id
    ball.team = team
    ball.radius = divider / 2
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

function World:expensiveCollisions(objects)
    local bounce = 1
    for i = 1, #objects do
        local obj1 = objects[i]
        for j = 1, #objects do
            if i ~= j then
                local obj2 = objects[j]
                local collisionAxis = {x=0,y=0}
                collisionAxis.x = obj1.x - obj2.x
                collisionAxis.y = obj1.y - obj2.y
                local distance = (collisionAxis.x^2 + collisionAxis.y^2) ^ 0.5
                local diameter = obj1.radius + obj2.radius
                if distance < diameter then
                    table.insert(self.ballsToUpdate,obj1)
                    table.insert(self.ballsToUpdate,obj2)
                    local n = collisionAxis
                    n.x = n.x / distance
                    n.y = n.y / distance
                    local delta = diameter - distance
                    local offset1 = obj2.radius / obj1.radius
                    local offset2 = obj1.radius / obj2.radius
                    if offset1 > 2 then offset1 = 2 end
                    if offset2 > 2 then offset2 = 2 end
                    obj2.x = obj2.x - bounce * offset2 * delta * n.x
                    obj2.y = obj2.y - bounce * offset2 * delta * n.y
                    obj1.x = obj1.x + bounce * offset1 * delta * n.x
                    obj1.y = obj1.y + bounce * offset1 * delta * n.y
                end
            end
        end
    end
end

function World:optimisedCollisions()
    for gridX = 2,xLen-1 do
        for gridY = 2,yLen-1 do
            local balls = {}
            for x = gridX-1, gridX+1 do
                for y = gridY-1, gridY+1 do
                    for ball = 1, #self.grid[y][x] do
                        table.insert(balls,self.grid[y][x][ball])
                    end
                end
            end
            self:expensiveCollisions(balls)
        end
    end
end

function World:updateGrid()
    self.grid = {}

    for i = 1,yLen do
        self.grid[i] = {}
        for j = 1,xLen do
            self.grid[i][j] = {}
        end
    end

    for i = 1,#self.balls do
        local obj = self.balls[i]
        local x,y = obj.x, obj.y
        x = math.floor(x / divider) + 1
        y = math.floor(y / divider) + 1
        if y > 0 and y < yLen and x > 0 and x < xLen then
            table.insert(self.grid[y][x],obj)
        end
    end
end

function World:constraint()
    --Only updates client side balls when a collision takes place.
    for i,ball in ipairs(self.balls) do
        if ball.x < ball.radius then
            table.insert(self.ballsToUpdate,ball)
            ball.x = ball.radius
            ball.vx = - ball.vx
            ball.lvx = - ball.lvx
        end
        if ball.y < ball.radius then
            table.insert(self.ballsToUpdate,ball)
            ball.y = ball.radius
            ball.vy = - ball.vy
            ball.lvy = - ball.lvy
        end
        if ball.x > love.graphics.getWidth() - ball.radius - divider then
            table.insert(self.ballsToUpdate,ball)
            ball.x = love.graphics.getWidth() - ball.radius - divider
            ball.vx = - ball.vx
            ball.lvx = - ball.lvx
        end
        if ball.y > love.graphics.getHeight() - ball.radius - divider then
            table.insert(self.ballsToUpdate,ball)
            ball.y = love.graphics.getHeight() - ball.radius - divider
            ball.vy = - ball.vy
            ball.lvy = - ball.lvy
        end
    end
    
end

function World:substep(dt,n)
    for i = 1,n do
        self:optimisedCollisions()
        self:verlet(dt/n)
        self:constraint()
        self:updateGrid()
    end
end

function World:update(dt)
    --Add a queue system to update a ball n times after it collides
    self.ballsToUpdate = {}
    self:substep(dt,7)
    Server:update(self.ballsToUpdate)
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

for i = 1,5 do
    World:new(i,{1,1,1},100+1.5*divider*i,100 + i,2,2,0,0)
end


--==love functions==

function love.load()
    love.window.setTitle("Server")
end

function love.update(dt)
    tick = tick + 1
    Server:updateConnections()
    
    World:update(dt)
    
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

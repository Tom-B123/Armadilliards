-- Load the necessary library
local socket = require("socket")
local tick = 0

Out = "none"
-- Replace "your_server_ip" with the IP address of your server
local ips = {["local"] = "192.168.1.110", ["foreign"] = "192.168.1.79"}

local serverPort = 12345

local id = "none"
-- Initialize the client socket
local client = assert(socket.connect(ips["local"], serverPort))
-- Set the timeout (in seconds) for the client socket
client:settimeout(0)

World = {balls = {}}

Command = {}

local ids = {"1","2"}
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
        out = out..round(ball.lx,1) .."_"
        out = out..round(ball.ly,1) .."_"
        out = out..round(ball.vx,3) .."_"
        out = out..round(ball.vy,3) .."_"
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
    ball.x  = x
    ball.y  = y
    ball.vx = vx
    ball.vy = vy
    ball.ax = ax
    ball.ay = ay
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

local function sendToServer(data)
    client:send(data .. "\n")
end

local function receiveFromServer()
    
    local data, err = client:receive()
    if data then
        return data
    elseif err == "closed" then
        client:close()
    end
end

World:new(ids[1],{1,1,1},25,100,100,0,0,0,0)
World:new(ids[2],{1,1,1},25,200,100,0,0,0,0)

--==love functions==--

function love.quit()
    -- Cleanup when quitting the application
    client:close()
end

function love.update(dt)
    
    
    tick = tick + 1
    local data = receiveFromServer()
    if data then 
        if id == "none" then id = data end
        Out = data 
        for i, ball in ipairs(World.balls) do
            local splitData,err = Command:decompile(data)
            if splitData then
                local ballData = splitData.balls[ball.id]
                if ballData then
                    ball.x = ballData.x
                    ball.y = ballData.y
                    ball.vx = ballData.vx
                    ball.vy = ballData.vy
                    ball.lx = ballData.lx
                    ball.ly = ballData.ly
                    ball.lvx = ballData.lvx
                    ball.lvy = ballData.lvy
                end
            end
        end
    end
    World:verlet(dt)
    if tick % 2 == 0 then
        local message = tick
        sendToServer(message.."\n")
    end
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
    love.graphics.print(split(Out,"_"),20,0)
    love.graphics.print("local tick: "..tick,20,20)
    love.graphics.print("id: "..id,20,40)
end
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

--==Helper functions==--

local function split(str,sep)
    local out = {}
    for i in string.gmatch(str,"([^"..sep.."]+)") do
        table.insert(out,i)
    end
    return out
end

--==Main functions==--

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

        ball.lvx = ball.vx * 0.99
        ball.lvy = ball.vy * 0.99

        ball.vx = nextVX
        ball.vy = nextVY

        ball.ax = 0
        ball.ay = 0
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

World:new(1,{1,1,1},25,100,100,0,0,0,0)
World:new(2,{1,1,1},25,200,100,0,0,0,0)

--==love functions==--

function love.keypressed(key)
	if key == "escape" then
	  love.event.quit()
	end
end

function love.quit()
    -- Cleanup when quitting the application
    client:close()
end

function love.update(dt)
    World:verlet(dt)
    
    tick = tick + 1
    local data = receiveFromServer()
    if data then 
        if id == "none" then id = data end
        Out = data 
        for i, ball in ipairs(World.balls) do
            local splitData = split(data,"-")
            ball.x = splitData[1]
            ball.y = splitData[2]
            ball.vx = splitData[3]
            ball.vy = splitData[4]
        end
    end
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
    love.graphics.print(split(Out,"-"),20,0)
    love.graphics.print("local tick: "..tick,20,20)
    love.graphics.print("id: "..id,20,40)
end
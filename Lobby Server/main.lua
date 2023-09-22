local socket = require("socket")

local clientMessages = {}

local requests = {}

Lobby = {}

Lobby.__index = Lobby

--Create a new lobby
function Lobby:new(name,port)
    local object = {}
    setmetatable(object,Lobby)
    object.name = name
    object.clients = {}
    object.server = assert(socket.bind("*",port))
    object.server:settimeout(0)
    return object
end

--Update connections coming into a lobby.
function Lobby:updateConnections()
    local newClient = self.server:accept()
    if newClient then
        table.insert(self.clients,newClient)
    end
end

--Send to clients connected to a lobby.
function Lobby:sendToClient(client)
    if client == "all" then
        for i,clientToSend in ipairs(self.clients) do
            clientToSend:send(self.name..":"..tostring(i).."\n")
        end
    end
end

--Receive from all clients of a lobby.
function Lobby:receiveFromClient()
    local dataOut = {}
    for i,clientToReceive in ipairs(self.clients) do
        local data,err = clientToReceive:receive()
        if data then dataOut[i] = data
        elseif err == "closed" then
            clientToReceive:close()
            table.remove(self.clients,i)
        end
    end
    return dataOut
end

--splits string by a seperator
local function split (inputstr, sep)
    if sep == nil then
            sep = "%s"
    end
    local t={}
    for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
            table.insert(t, str)
    end
    return t
end

--A list of all online players.
local players = {}
--A list of all active lobby servers,
--Displayed to the clients in the players list.
local lobbies = {}
--The server that online players attempt to connect to.
lobbies[1] = Lobby:new("Main Lobby",500)

lobbies[2] = Lobby:new("my lobby",1000)

function love.keypressed(key)
	if key == "escape" then
	  love.event.quit()
	end
end

function love.load()
end

function love.update()
    --For each lobby
    for i, lobby in ipairs(lobbies) do
        requests[i] = {}
        --Send data to and update active clients.
        lobby:updateConnections()
        lobby:sendToClient("all")
        clientMessages[i] = lobby:receiveFromClient()
        --For every client in the lobby
        for j, message in ipairs(clientMessages[i]) do
            requests[i][j] = "none"
            --If there is a command sent, update the
            --requests table,
            if message ~= "ndat" then 
                --splitting the command from the params
                local commandData = split(message,":")
                --Join lobby request
                if commandData[1] == "jlob" then
                    requests[i] = {"join",commandData[2]}

                --Create lobby request
                elseif commandData[1] == "clob" then
                    local lobbyData = split(commandData[2],"_")
                    requests[i] = {"create",lobbyData[1],lobbyData[2]}
                end
            end
        end
    end
end

function love.draw()
    for x, lobby in ipairs(lobbies) do
        local data = clientMessages[x]
        if data then
            for y, message in ipairs(data) do
                love.graphics.print(message,x*50,y*50)
            end
        end
    end
    for i, lobby in ipairs(requests) do
        for j,request in ipairs(lobby) do
            if request ~= "none" then
                love.graphics.print(request,0,j*15)
            end
        end
    end
end
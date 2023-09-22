local socket = require("socket")

local clientMessages = {}

local requests = {}

Lobby = {}

Lobby.__index = Lobby

local lobbies = {}
local lobbiesDict = {}
--Create a new lobby
function Lobby:new(name,port)
    local object = {}
    setmetatable(object,Lobby)
    object.name = name
    object.port = port
    object.clients = {}
    object.server = assert(socket.bind("*",port))
    object.server:settimeout(0)
    table.insert(lobbies,object)
    lobbiesDict[name] = object
end

--Update connections coming into a lobby.
function Lobby:updateConnections()
    local newClient = self.server:accept()
    if newClient then
        table.insert(self.clients,newClient)
    end
end

--Send to clients connected to a lobby.
function Lobby:sendToClient(client,data)
    if client == "all" then
        for i,clientToSend in ipairs(self.clients) do
            clientToSend:send(self.name..":"..tostring(i).."\n")
        end
    else
        if data then client:send(data.."\n") end
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

--The server that online players attempt to connect to.
Lobby:new("Main Lobby",500)

function love.keypressed(key)
	if key == "escape" then
	  love.event.quit()
	end
end

function love.load()
end

function love.update()

    --Proccess incoming requests
    for i, lobby in ipairs(lobbies) do
        requests[i] = {}
        --Send data to and update active clients.
        clientMessages[i] = lobby:receiveFromClient()
        --For every client in the lobby
        for j, message in ipairs(clientMessages[i]) do
            requests[i][j] = nil
            --If there is a command sent, update the
            --requests table,
            if message ~= "ndat" then 
                --splitting the command from the params
                local commandData = split(message,":")
                
                --Join lobby request
                if commandData[1] == "jlob" then
                    requests[i][j] = {"join",commandData[2]}

                --Create lobby request
                elseif commandData[1] == "clob" then
                    local lobbyData = split(commandData[2],"_")
                    requests[i][j] = {"create",lobbyData[1],lobbyData[2]}
                end
            end
        end
    end
    --Packet example = requests[lobby][client] = 
    --{"create","my lobby","1005"}
    local toSend = {}

    --Carry out incoming requests
    for i,lobby in ipairs(requests) do
        toSend[i] = {}
        for j,request in ipairs(lobby) do
            toSend[i][j] = nil
            if request then
                if request[1] == "create" then
                    Lobby:new(request[2],tonumber(request[3]))
                elseif request[1] == "join" then
                    toSend[i][j] = request[2]
                end
            end
        end
    end
    --Sends data to all clients that requested it.
    for i,lobby in ipairs(lobbies) do
        lobby:updateConnections()
        for j, client in ipairs(lobby.clients) do
            if toSend[i][j] then
                local server = lobbiesDict[toSend[i][j]]
                if server then 
                    local serverInfo = server.port.."\n"
                    lobby:sendToClient(client,"port:"..serverInfo)
                else
                    lobby:sendToClient(client,"invalid lobby name")
                end
            else
                lobby:sendToClient(client,"none")
            end
        end
    end
end





--Draw text, debugging for server
function love.draw()
    love.graphics.print("lobby count: "..#lobbies)
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
            if request then
                love.graphics.print(request,0,j*15)
            end
        end
    end
end
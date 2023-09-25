local socket = require("socket")

local clientMessages = {}

local requests = {}

Lobby = {}

Lobby.__index = Lobby

local lobbies = {}
local lobbiesDict = {}
--Create a new lobby
function Lobby:new(name,port,isMain)
    local object = {}
    setmetatable(object,Lobby)
    object.name = name
    object.port = port
    object.clients = {}
    if isMain then 
        object.server = assert(socket.bind("*",port))
        object.server:settimeout(0)
    end
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
function Lobby:sendToClient(client,data)
    if client == "all" then
        for i,clientToSend in ipairs(self.clients) do
            clientToSend:send(data.."\n")
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

--The server that online players attempt to connect to.
local mainLobby = Lobby:new("Main Lobby",500,true)

function love.keypressed(key)
	if key == "escape" then
	  love.event.quit()
	end
end

function love.update()

    mainLobby:updateConnections()
    --Proccess incoming requests
    clientMessages = mainLobby:receiveFromClient()

    requests = {}
    --process special requests to the main lobby
    for i, message in ipairs(clientMessages) do
        requests[i] = nil
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
                -- Lobby:new(lobbyData[1],tonumber(lobbyData[2]))
                requests[i] = {"create",lobbyData[1],tonumber(lobbyData[2])}
            end
        end
    end
    --Packet example = requests[lobby][client] = 
    --{"create","my lobby","1005"}
    local toSend = {}

    --Carry out incoming requests to the main server
    for i,request in ipairs(requests) do
        toSend[i] = nil
        if request then
            if request[1] == "create" then
                local nLobby = Lobby:new(request[2],tonumber(request[3]))
                lobbies[#lobbies+1] = nLobby
                lobbiesDict[nLobby.name] = nLobby
                -- toSend[i] = request[2]
            elseif request[1] == "join" then
                toSend[i] = request[2]
            end
        end
    end

    --Sends data to all clients that requested it.
    

    for i, client in ipairs(mainLobby.clients) do
        if toSend[i] then
            local server = lobbiesDict[toSend[i]]
            if server then 
                local serverInfo = server.name.."_"..server.port.."\n"
                mainLobby:sendToClient(client,"port:"..serverInfo)
            else
                mainLobby:sendToClient(client,"invalid lobby name")
            end
        else
            mainLobby:sendToClient(client,"none")
        end
    end
end





--Draw text, debugging for server
function love.draw()
    love.graphics.print("lobby count: "..#lobbies)
    love.graphics.print("client count: "..#mainLobby.clients,0,20)
    local data = clientMessages
    if data then
        for y, message in ipairs(data) do
            love.graphics.print(message,0,y*50)
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
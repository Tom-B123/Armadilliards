local socket = require("socket")

local clientMessages = {}

local requests = {}

Lobby = {}

Lobby.__index = Lobby

local lobbies = {}
local lobbiesDict = {}
--Create a new lobby
function Lobby:new(name,port,isMain,ipAddress)
    local object = {}
    setmetatable(object,Lobby)
    object.name = name
    object.port = port
    object.ipAddress = ipAddress
    object.clients = {}
    if isMain then 
        object.server = assert(socket.bind("*",port))
        object.server:settimeout(0)
    else
        lobbies[#lobbies+1] = object
        lobbiesDict[name] = object
    end
    return object
end

local mainLobby = Lobby:new("Main Lobby",500,true)

--Connect a client to a sub-Lobby
function Lobby:join(client,name)
    --If the lobby exists, send the client the socket info.
    local lobby = lobbiesDict[name]
    if lobby then
        local lobbyInfo = "sock:"..lobby.name.."_"..lobby.ipAddress.."_"..lobby.port.."\n"
        mainLobby:sendToClient(client,lobbyInfo)
        return nil
    end
    return "invalid lobby name\n"
end

--Confirm a creation request from the client.
function Lobby:create(client,name)

    local nLobby = lobbiesDict[name]
    local lobbyInfo = nLobby.name.."_"..nLobby.port.."_"..nLobby.ipAddress.."\n"
    mainLobby:sendToClient(client,"clob:"..lobbyInfo)
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
        if data then dataOut[i] = {data,clientToReceive}
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
        if message[1] ~= "ndat" then 
            --splitting the command from the params
            local commandData = split(message[1],":")
            
            --Join lobby request
            if commandData[1] == "jlob" then
                --{join,[lobby]}
                requests[i] = {"join",commandData[2]}
            --Create lobby request
            elseif commandData[1] == "clob" then
                local lobbyData = split(commandData[2],"_")
                Lobby:new(lobbyData[1],tonumber(lobbyData[2]),false,lobbyData[3])
                requests[i] = {"create",lobbyData[1]}
            end
        end
    end
    --Packet example = requests[lobby][client] = 
    --{"create","my lobby","1005","192.168..."}

    --Sends data to all clients that requested it.
    for i, client in ipairs(mainLobby.clients) do
        if requests[i] then
            --If the request is a join command then.
            if requests[i][1] == "join" then
                local err = Lobby:join(client,requests[i][2])
                if err then
                    mainLobby:sendToClient(client,err)
                end
            --If the request is a create command then.
            elseif requests[i][1] == "create" then
                --Confirm creation
                local err = Lobby:create(client,requests[i][2])
                if err then
                    mainLobby:sendToClient(client,err)
                end
            end
        else
            mainLobby:sendToClient(client,"none")
        end
    end
end





--Draw text, debugging for server
function love.draw()
    love.graphics.print("lobby count: "..#lobbies,100,0)
    for i, lobby in ipairs(lobbies) do
        love.graphics.print(lobby.name,100,15*i)
    end
        
    love.graphics.print("client count: "..#mainLobby.clients,0,20)
    local data = clientMessages
    if data then
        for y, message in ipairs(data) do
            love.graphics.print(message[1],0,y*50)
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
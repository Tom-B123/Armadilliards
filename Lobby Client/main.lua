local socket = require("socket")

local client
local server = nil
local lobbyName
local playerName = "new player"
--The client of players, that will be connected to lobbies.
local function connectToMainLobby()
    client = assert(socket.connect("localhost",500))
    client:settimeout(0)
    lobbyName = "Main"
end

connectToMainLobby()


--The identifier of the client
local clientID = nil
--the last message recieved.
local serverMessage = ""

--Name of the currently accessed lobby.

--list of all lobbies available to join
local lobbiesList = {}

Lobby = {}

--The lobby requests to send to the main lobby.
local lobbyToJoin = nil

local lobbyToCreate = nil

Lobby.__index = Lobby

--Stores messages from the main lobby
local messagesToWrite = {}

--Creates a new lobby object
function Lobby:new(name,port,tmp)
    local object = {}
    setmetatable(object,Lobby)
    object.name = name
    object.port = port
    if tmp == nil then
        object.clients = {}
        object.server = assert(socket.bind("*",port))
        object.server:settimeout(0)
    end
    return object
end

--Sends the new lobby details to the server.
function Lobby:send()
    local ip = socket.dns.toip(socket.dns.gethostname()) 
    return self.name.."_"..self.port.."_"..ip.."_"..playerName.."\n"
end

--Update connections coming into a lobby.
function Lobby:updateConnections()
    local newClient = self.server:accept()
    if newClient then
        table.insert(self.clients,newClient)
    end
end

function love.keypressed(key)
	if key == "escape" then
	  love.event.quit()
	end

    for i = 0,9 do
        if key == tostring(i) then
            if love.keyboard.isDown("lctrl") then
                lobbyToCreate = Lobby:new("lobby "..i,1000+i,true)
            else
                lobbyToJoin = "lobby "..i
            end
        end
    end
end

--Splits strings by a separator
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

--Sends message to server
local function sendToServer(data)
    client:send(data .. "\n")
end

--Reads message from server
local function receiveFromServer()
    local data, err = client:receive()
    if data then
        return data
    elseif err == "closed" then
        client:close()
    end
end

--Sends message to clients when hosting
function Lobby:sendToClients(data)
    for i, client in ipairs(self.clients) do
        client:send(data)
    end
end

--Recieves messages from clients when hosting
function Lobby:receiveFromClients()
    local out = {}
    for i,client in ipairs(self.clients) do
        local data,err = client:receive()
        table.insert(out,data)
        if err == "closed" then
            client:close()
            table.remove(self.clients,i)
        end
    end
    return out
end

--All the processing the lobby client does.
local function comWithMainLobby()
    messagesToWrite = {}
    --Sends data to the server based on user input
    if lobbyToCreate ~= nil then
        sendToServer("clob"..":"..lobbyToCreate:send())
    elseif lobbyToJoin ~= nil then
        sendToServer("jlob"..":"..lobbyToJoin)
    else
        sendToServer("ndat")
    end
    repeat
        local quit = false
        serverMessage = receiveFromServer()
        messagesToWrite[#messagesToWrite+1] = serverMessage
        --If a command is recieved from the server
        if serverMessage and serverMessage ~= "none" then
            --split the command
            local commandData = split(serverMessage,":")

            if commandData[1] == "exit" then
                client:quit()
                client = assert(socket.connect("localhost",500))
                client:settimeout(0)
                lobbyName = "Main"
                quit = true

            --Command confirms lobby creation
            elseif commandData[1] == "clob" then
                local sockData = split(commandData[2],"_")
                client:close()
                client = nil
                lobbyName = sockData[1]
                server = Lobby:new(sockData[1],sockData[2])
                messagesToWrite = {}
                quit = true

            --If a socket details are given, connect to that socket.
            elseif commandData[1] == "sock" then
                local sockData = split(commandData[2],"_")
                client:close()
                lobbyName = sockData[1]
                client = assert(socket.connect(sockData[2],sockData[3]))
                client:settimeout(0)
                quit = true


            elseif commandData[1] == "disp" then
                if commandData[2] then
                    local lobbyData = split(commandData[2],"_")
                    for i, lobby in ipairs(lobbyData) do
                        lobbiesList[i] = lobby
                    end
                end
            end
        end
    until (serverMessage == nil or quit == true)
end

--All the processing a server does
local function comWithClients()
    if server then
        server:updateConnections()
        server:sendToClients("hello clients, I am a host\n")
        server:receiveFromClients()
    end
end

local function displayLobbies()
    love.graphics.print("Available lobbies:")

    for i, lobby in ipairs(lobbiesList) do
        love.graphics.print(lobby,0,i*20)
    end
end

--Called when quitting.
function love.quit()
    if client then client:close() end
    if server then
        --Disconnect all connected clients when closing
        connectToMainLobby()
        sendToServer("exit:"..server.name)
    end
end

function love.update()
    if client then comWithMainLobby()

    elseif server then comWithClients() end
end


function love.draw()
    love.graphics.print(lobbyName,200,0)
    if lobbyName == "Main" then 
        displayLobbies()
    end

    lobbyToJoin = nil
    lobbyToCreate = nil
end

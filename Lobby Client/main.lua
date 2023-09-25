local socket = require("socket")
--The client of players, that will be connected to lobbies.
local client = assert(socket.connect("localhost",1001))
local server = nil
--The identifier of the client
local clientID = nil
--the last message recieved.
local serverMessage = ""

client:settimeout(0)

local lobbyName = "Main"

Lobby = {}

--The lobby requests to send to the main lobby.
local lobbyToJoin = nil

local lobbyToCreate = nil

Lobby.__index = Lobby

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
    return self.name.."_"..self.port.."_"..ip.."\n"
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

function love.quit()
    if client then client:close() end
end

--split strings by a separator
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

--Send message to server
local function sendToServer(data)
    client:send(data .. "\n")
end

--Read message from server
local function receiveFromServer()
    local data, err = client:receive()
    if data then
        return data
    elseif err == "closed" then
        client:close()
    end
end

--Send message to clients when hosting
local function sendToClients(data)
    if server then
        for i, client in ipairs(server.clients) do
            client:send(data)
        end
    end
end

--Recieve messages from clients when hosting
local function receiveFromClients()
    if server then
        local out = {}
        for i,client in ipairs(server.clients) do
            local data,err = client:receive()
            table.insert(out,data)
            if err == "closed" then
                client:close()
                table.remove(server.clients,i)
            end
        end
    end
end

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
        serverMessage = receiveFromServer()
        messagesToWrite[#messagesToWrite+1] = serverMessage
        --If a command is recieved from the server
        if serverMessage and serverMessage ~= "none" then
            --split the command
            local commandData = split(serverMessage,":")
            --Command confirms lobby creation
            if commandData[1] == "clob" then
                local sockData = split(commandData[2],"_")
                client:close()
                client = nil
                lobbyName = sockData[1]
                server = Lobby:new(sockData[1],sockData[2])
                messagesToWrite = {}
            --If a socket details are given, connect to that socket.
            elseif commandData[1] == "sock" then
                local sockData = split(commandData[2],"_")
                client:close()
                lobbyName = sockData[1]
                client = assert(socket.connect(sockData[2],sockData[3]))
            end
        end
    until (serverMessage == nil or client == nil)
end

local function comWithClients()
    sendToClients("hello clients, I am a host")
    receiveFromClients()
end



function love.update()
    if client then comWithMainLobby() end

    if server then comWithClients() end
end


function love.draw()
    love.graphics.print(lobbyName,200,0)
    for i, message in ipairs(messagesToWrite) do
        local data = message
        if data and data ~= "none" then love.graphics.print(data,0,0) end
    end
    if lobbyToJoin then 
        love.graphics.print("attemped to join lobby: "..lobbyToJoin,0,200)
    end
    if lobbyToCreate then
        love.graphics.print("attemped to create lobby: "..lobbyToCreate:send(),200,200)
    end
    lobbyToJoin = nil
    lobbyToCreate = nil
end
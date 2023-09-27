local socket = require("socket")
require("button")

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

-- love.window.setMode(0,0)

connectToMainLobby()

local lobbyImg = love.graphics.newImage("lobby UI mock up.png")
local futura = love.graphics.newFont("Futura font.ttf",28)
love.graphics.setFont(futura)

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

local buttons = {}

function buttons:draw()
    for i,button in ipairs(buttons) do
        love.graphics.setColor(button.colour)
        love.graphics.print(button.text,button.x1,button.y1)
    end
end

function buttons:update()
    for i,button in ipairs(buttons) do
        button:update()
    end
end

local function newButton(text,colour,x1,y1,x2,y2,command,params)
    table.insert(buttons,Button:new(text,colour,x1,y1,x2,y2,command,params))
end

local function drawSquare(param)
    love.graphics.setColor(0,0,0)
    love.graphics.print(param)
end

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


local function join(lobby)
    sendToServer("jlob:"..lobby)
end

--All the processing the lobby client does.
local function comWithMainLobby()
    messagesToWrite = {}
    --Sends data to the server based on user input
    if lobbyToCreate ~= nil then
        sendToServer("clob"..":"..lobbyToCreate:send())
    elseif lobbyToJoin ~= nil then
        sendToServer("jlob:"..lobbyToJoin)
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
                        local lobbyInfo = split(lobby,"|")
                        lobbiesList[i] = lobbyInfo
                        
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
    love.graphics.setColor(1,1,1)
    love.graphics.draw(lobbyImg)
    love.graphics.setColor(1,1,1)

    for i, lobby in ipairs(lobbiesList) do
        newButton(lobby[1],{1,1,1},305,80+i*50,945,80+i*85,join,lobby[1])
        love.graphics.print(lobby[2],510,80+i*50)
        love.graphics.print(lobby[3],855,80+i*50)
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
    
    love.graphics.setColor(1,1,1)
    love.graphics.print(lobbyName,200,0)
    if lobbyName == "Main" then 
        displayLobbies()
        buttons:update()
        buttons:draw()
    end
    
    lobbyToJoin = nil
    lobbyToCreate = nil
end

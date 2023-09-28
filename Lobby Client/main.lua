local socket = require("socket")
require("button")

local client
local server = nil
local lobbyName
local lPlayerName
local playerName = "new player"
local tick = 0

local lState
local state = "browsing"

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

--The client of players, that will be connected to lobbies.
local function connectToMainLobby()
    client = assert(socket.connect("localhost",500))
    client:settimeout(0)
    --Main lobby = _Main, as this can't be immitated by players.
    lobbyName = "_Main"
end

-- love.window.setMode(0,0)

connectToMainLobby()

local lobbyImg = love.graphics.newImage("lobby UI mock up.png")
local futura = love.graphics.newFont("Futura font.ttf",28)
local futuraL = love.graphics.newFont("Futura font.ttf",56)

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

local buttons = {lobbyButtons = {},browsingButtons = {}}

function buttons:draw()
    for i,button in ipairs(buttons.lobbyButtons) do
        love.graphics.setFont(button.font)
        love.graphics.setColor(button.colour)
        love.graphics.print(button.text,button.x1,button.y1)
    end
    for i,button in ipairs(buttons.browsingButtons) do
        love.graphics.setFont(button.font)
        love.graphics.setColor(button.colour)
        love.graphics.print(button.text,button.x1,button.y1)
    end
end

function buttons:update()
    for i,button in ipairs(buttons.lobbyButtons) do
        button:update()
    end
    for i,button in ipairs(buttons.browsingButtons) do
        button:update()
    end
end

--New button to enter a lobby
local function newLobbyButton(text,colour,x1,y1,x2,y2,command,params)
    local nButton = Button:new(text,colour,futura,x1,y1,x2,y2,command,params)
    table.insert(buttons.lobbyButtons,nButton)
    return nButton
end

local function newBrowsingButton(text,colour,font,x1,y1,x2,y2,command,params)
    local nButton = Button:new(text,colour,font,x1,y1,x2,y2,command,params)
    table.insert(buttons.browsingButtons,nButton)
    return nButton
end

--Changes the state to allow the player name to be edited.
local function editPlayerName()
    state = "editing player name"
end

local playerNameButton = newBrowsingButton("Enter player name...",{1,1,1},futuraL,300,30,980,100,editPlayerName)

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


local function contains(table,item)
    for i,obj in ipairs(table) do
        if obj == item then
            return true
        end
    end
    return false
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
    tick = tick + 1
    
    messagesToWrite = {}
    --Sends data to the server based on user input
    if lobbyToCreate ~= nil then
        sendToServer("clob"..":"..lobbyToCreate:send())
    elseif lobbyToJoin ~= nil then
        sendToServer("jlob:"..lobbyToJoin)
    else
        if tick % 30 == 0 then
            sendToServer("updt:all")
        else 
            sendToServer("ndat") 
        end
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
                client:close()
                client = assert(socket.connect("localhost",500))
                client:settimeout(0)
                lobbyName = "_Main"
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
                buttons.lobbyButtons = {}
                if commandData[2] then
                    local lobbyData = split(commandData[2],"_")
                    for i, lobby in ipairs(lobbyData) do
                        local lobbyInfo = split(lobby,"|")
                        lobbiesList[i] = lobbyInfo

                        newLobbyButton(lobbyInfo[1],{1,1,1},305,80+i*50,945,80+i*85,join,lobbyInfo[1])
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
    love.graphics.setFont(futura)
    love.graphics.setColor(1,1,1)
    love.graphics.draw(lobbyImg)
    love.graphics.setColor(1,1,1)

    for i, lobby in ipairs(lobbiesList) do
        
        love.graphics.print(lobby[2],510,80+i*50)
        love.graphics.print(lobby[3],855,80+i*50)
    end
end

--Called when quitting.
function love.quit()
    if client then
        local tmp = lobbyName
        connectToMainLobby()
        sendToServer("exit:"..tmp)

    end
    if server then
        --Disconnect all connected clients when closing
        connectToMainLobby()
        sendToServer("clse:"..server.name)
    end
end

--Stores the old player name
local function storePlayerName()
    lPlayerName = playerName
    if playerName == "new player" then
        playerName = ""
    end
end

--Changes the player name on the button
local function updatePlayerName()
    if playerName == "" then
        playerNameButton.text = "Enter player name..."
    else
        playerNameButton.text = playerName
        
    end
end


function love.keypressed(key)
    if state == "browsing" then
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
    elseif state == "editing player name" then
        local invalidLetters = {"_"}
        if not contains(invalidLetters,key) and #key == 1 then
            if love.keyboard.isDown("lshift") or love.keyboard.isDown("rshift") then
                key = string.upper(key)
            end
            playerName = playerName..key
        elseif key == "space" then 
            playerName = playerName.." "
        elseif key == "backspace" then
            playerName = string.sub(playerName,1,#playerName-1)
        end
        if key == "escape" then
            playerName = lPlayerName
            if playerName == "" then
                playerName = "new player"
            end
            updatePlayerName()
            state = "browsing"
        end
        if key == "return" then
            if playerName == "" then
                playerName = "new player"
            end
            updatePlayerName()
            state = "browsing"
        end
    end
end

function love.update()
    if state == "editing player name" then
        if lState ~= "editing player name" then
            storePlayerName()
        end
        updatePlayerName()
    end
    
    
    if client then comWithMainLobby()

    elseif server then comWithClients() end

    lState = state
end


function love.draw()
    
    love.graphics.setColor(1,1,1)
    love.graphics.print(lobbyName,200,0)
    if lobbyName == "_Main" then 
        displayLobbies()
        buttons:update()
        buttons:draw()
    end
    love.graphics.setColor(0,0,0)
    love.graphics.print(playerName)
    lobbyToJoin = nil
    lobbyToCreate = nil
end

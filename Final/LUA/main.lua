require("lists")
require("switch")
require("button")
require("net")
require("util")
require("solver")
require("sets")
local ReadMap = require("readMap")

-- local mobile = false
-- if love.system.getOS() == 'iOS' or love.system.getOS() == 'Android' then
--     mobile = true
-- end

local mainClient = nil
local player     = nil
-- Default values for creating a lobby
local lobbyToCreate = {name = "new lobby", maxPlayers = 8}

local toRemoveIDs     = List:new()
local toConnectMain   = false
local toClosePlayer   = false
local toConnectPlayer = nil
-- Used when exiting a server, sets a delay of n ticks before changing state to confirm exit.
local toChangeState   = nil
local tempTick        = 0

local server = nil

-- number of ticks between each lobby refresh
local refreshRate = 120

local canQuit     = false
local tick        = 0

local messageLog  = {}

local monoSpace   = love.graphics.newFont("cour.ttf",15)
love.graphics.setFont(monoSpace)

local dashIcon     = love.graphics.newImage("Assets/dashIcon.png")
local ropeIcon     = love.graphics.newImage("Assets/ropeIcon.png")
local shootIcon    = love.graphics.newImage("Assets/shootIcon.png")

local iconDict = {
    ["dash"]  = dashIcon,
    ["rope"]  = ropeIcon,
    ["shoot"] = shootIcon
}

local editingText  = nil
local editingIndex = 1

local aPercentage = 0
local bPercentage = 0

local abilities   = {"dash","rope","shoot"}

local aAbilities  = List:new()
local bAbilities  = List:new()

for i,ability in ipairs(abilities) do
    aAbilities:append(ability)
    bAbilities:append(ability)
end

local aAbility
local bAbility

local function updateAbility()
    aAbility    = aAbilities:getVal()
    bAbility    = bAbilities:getVal()
    Util:setAbility(1,aAbility)
    Util:setAbility(2,bAbility)
end

local function changeAbiltiy(slot,forward)
    if slot == 1 and forward then     aAbilities:next() end
    if slot == 1 and not forward then aAbilities:prev() end
    if slot == 2 and forward then     bAbilities:next() end
    if slot == 2 and not forward then bAbilities:prev() end
    updateAbility()
end

updateAbility()

local state    = {"main menu"}
local lState   = {nil}
-- Order of states, used to overlap menues ontop of eachother
local order    = 1
-- hardcoded limit on orders, only 4 menues can overlap at once
local maxOrder = 4
-- Stores all buttons within tables, corresponding to their order.
local buttons        = {}
local lobbyButtons   = List:new()
local kickButtons    = List:new()
local teamButtons    = List:new()
local maps           = List:new()

local nextTeam       = {}

local teamCount = 8

for i = 1,teamCount-1 do
    nextTeam["team "..i] = "team "..i+1
end

nextTeam["team "..teamCount] = "team "..(1)

local polyCoords     = {}

local lobbyScroll    = 0
local lobbyScrollVel = 0

for i = 1,maxOrder do
    buttons[i] = {}
end

-- Stores player inputs to send to the host all at once when cooldown = 0
local inputCooldown = 4
local inputSum = {x=0,y=0,aHeld = 0,bHeld = 0,abilities = {}}

-- To run every frame a state is active.
local stateSwitch     = Switch:new()

-- To run the first frame a state is active
local newStateSwitch  = Switch:new()

-- To draw every frame a state is active.
local drawStateSwitch = Switch:new()

-- Convert message to function
local netSwitch       = Switch:new()

--Converts the ability name into a function to process that abiltiy
local abilitySwitch   = Switch:new()


local function newMessage(sender,message)
    -- Append the name of the sender onto the message
    local name = LobbyPlayer:getName(sender)
    if sender == "server" then name = "server" end
    if name then table.insert(messageLog,name..": "..message) end
end

local function drawMessages()
    love.graphics.setColor(1,1,1)
    for i,message in ipairs(messageLog) do
        local topPos = 550 - #messageLog * 20
        love.graphics.print(message,100,topPos + i*20)
    end
end

local function clearMessages()
    messageLog = {}
end

local function removeButton(ord,dButton)
    local ind = -1
    for i,button in ipairs(buttons[ord]) do
        if button == dButton then ind = i end
    end
    if ind > -1 then
        table.remove(buttons[ord],ind)
    end
end

-- Detect if the player clicks any buttons of the current order
local function updateButtons()
    for i,button in ipairs(buttons[order]) do
        button:update()
    end
end

local function drawButtons(ord)
    for j,button in ipairs(buttons[ord]) do
        button:draw()
    end
end

local function updateScroll(dt)
    lobbyScroll = lobbyScroll + lobbyScrollVel * dt
    lobbyScrollVel = lobbyScrollVel * 0.9
end

local function updateLobbyButtons()
    for i,button in lobbyButtons:iterator() do
        button:update()
    end
end

local function drawLobbyButtons()
    local firstY = 0
    local lastY  = 0
    local distance = 50
    for i,button in lobbyButtons:iterator() do
        if i == 1 then firstY = i*distance + lobbyScroll end
        lastY = i*distance + lobbyScroll
        button:setCoords(100,100+i*distance + lobbyScroll,700,distance * 0.9 + 100+i*distance + lobbyScroll)
        button:draw()
    end
    if firstY > distance then lobbyScrollVel = lobbyScrollVel - firstY end
    if lastY < 0 then lobbyScrollVel = lobbyScrollVel - lastY end
end

local function updateKickButtons()
    for i,button in kickButtons:iterator() do
        button:update()
    end
end

local function drawKickButtons()
    local distance = 20
    for i,button in kickButtons:iterator() do
        button:setCoords(475,20 + i*distance,525,20 + distance * 0.9 + i*distance)
        button:draw()
    end
end

local function updateTeamButtons()
    for i,button in teamButtons:iterator() do
        button:update()
    end
end

local function drawTeamButtons()
    local distance = 20
    for i,button in teamButtons:iterator() do
        button:setCoords(400,0 + i*distance,455,0 + distance * 0.9 + i*distance)
        button:draw()
    end
end

local function newButton(ord,text,x1,y1,x2,y2,command,params)
    local nButton = Button:new(text,0,x1,y1,x2,y2,command,params)
    table.insert(buttons[ord],nButton)
    return nButton
end

-- Clears existing buttons on the current order (for when state changes and buttons need to change)
local function clearButtons()
    buttons[order] = {}
end

local function getNewState()
    if state[order] ~= lState[order] then return state[order] end
end

local function getState(ord)
    return state[ord]
end

-- Apply editing text to the player name
local function changePlayerName()
    if not mainClient then return end
    if editingText == "" then editingText = "new player" end
    mainClient.name    = editingText
    editingText    = nil
    state[2]       = nil
    lState[2]      = nil
    order          = 1
end

-- Apply editing text to message, and send to other players
local function sendMessage(message)
    if not message then message = editingText end
    if player and not server then
        player:send("msg:"..player.ID.."_"..message.."_\n")
    end
    if player and server then
        server:send("all","msg:"..player.ID.."_"..message.."_\n")
        newMessage(player.ID,message)
    end
    editingText = nil
    state[2]    = nil
    lState[2]   = nil
    order       = 1
end

-- Apply editing text to the lobby name
local function changeLobbyName()
    if not mainClient then return end
    if editingText    == "" then editingText = "new lobby" end
    lobbyToCreate.name = editingText
    editingText        = nil
    state[4]           = nil
    lState[4]          = nil
    order              = 3
end

-- Pass received data into netSwitch
local function processReceived()
    local function process(data)
        for i,message in ipairs(data) do
            local splitData = Util:split(message,":")
            local key,args  = splitData[1],splitData[2]
            if args then
                netSwitch:case(key,args)
            end
        end
    end
    local data
    if server then
        data = server:receive("all")
        process(data)
    end
    if player then
        data = {player:receive()}
        while data do
            process(data)
            data = player:receive()
            if data then data = {data}
            end
        end
    end
    if mainClient then
        data = {mainClient:receive()}
        while data do
            process(data)
            data = mainClient:receive()
            if data then data = {data}
            end
        end
    end
end

-- Checks if every player in the lobby is ready
local function playersAllReady()
    local teams = Set:new()
    for i,ID in ipairs(LobbyPlayer:getIDs()) do
        if not (LobbyPlayer:getReady(ID) and LobbyPlayer:getInLobby(ID))  then return false end
        teams:add(LobbyPlayer:getTeam(ID))
    end
    return teams
end

-- Applies vx and vy to the ball, at a set speed.
local function applyMove(ball,vx,vy)
    local speed = 40
    if ball then
        ball.vx = ball.vx + vx * speed
        ball.vy = ball.vy + vy * speed
    end
end

local root2 = math.sqrt(2)

local function drawIconCooldown(icon,x,y,percentage)
    local faded  = {0.8,0.8,0.8}
    local scroll = {0,0,0,0.7}

    love.graphics.setColor(faded)
    love.graphics.draw(icon,x,y,0,1,1,32,32)

    local scrollAngle = 2 * math.pi - (percentage) * 2 * math.pi
    local centreX = x
    local centreY = y

    local scrollX = 0
    local scrollY = 0

    local scrollPoints = {}
    
    --extra region to keep the scroll square
    local alpha = 32 * (1 - root2)
    --If the angle is on the bottom left diagonal, alpha needs to be negative
    if not (3*math.pi/4 < scrollAngle or 7*math.pi/4 > scrollAngle) then alpha = -alpha end

    --Changes the face angle for moving the angle regions from -1/4 -> 0 -> 1/4 to -1/2 -> 0 -> 1/2
    local faceAngle = 0
    if scrollAngle < 7*math.pi/4 and scrollAngle >= 5*math.pi/4 then
        faceAngle = 3/2 * math.pi
    elseif scrollAngle < 5*math.pi/4 and scrollAngle >= 3*math.pi/4 then
        faceAngle = math.pi
    elseif scrollAngle < 3*math.pi/4 and scrollAngle >= 1*math.pi/4 then
        faceAngle = 1/2 * math.pi
    end

    local dAngle = ((scrollAngle-faceAngle)*2)+faceAngle

    if (math.pi/4 < scrollAngle and scrollAngle < 3*math.pi/4) or (5*math.pi/4 < scrollAngle and scrollAngle < 7*math.pi/4) then
        scrollX = centreX + (32 * root2 * math.cos(scrollAngle))
        scrollY = centreY + (32 * root2 * math.sin(scrollAngle)) + alpha * math.sin(dAngle)
    else
        scrollX = centreX + (32 * root2 * math.cos(scrollAngle)) + alpha * math.cos(dAngle)
        scrollY = centreY + (32 * root2 * math.sin(scrollAngle))
    end
    --Always passes through the centre horizontally
    scrollPoints = {centreX,centreY,centreX + 32,centreY}

    local numCorners = math.floor(0.5 + ((scrollAngle / math.pi) * 2))

    for i = 1,numCorners do
        local nAngle = math.pi * (i/2 - 0.25)
        table.insert(scrollPoints,centreX + 32 * root2 * math.cos(nAngle))
        table.insert(scrollPoints,centreY + 32 * root2 * math.sin(nAngle))
    end

    table.insert(scrollPoints,scrollX)
    table.insert(scrollPoints,scrollY)

    love.graphics.setColor(scroll)
    love.graphics.polygon("fill",scrollPoints)
end

local function drawIcons()
    local bright = {1,1,1}

    local aIcon = iconDict[aAbility]
    local bIcon = iconDict[bAbility]

    if aPercentage < 1 then
        drawIconCooldown(aIcon,300,500,aPercentage)
    else
        love.graphics.setColor(bright)
        love.graphics.draw(aIcon,300,500,0,1,1,32,32)
    end

    if bPercentage < 1 then
        drawIconCooldown(bIcon,500,500,bPercentage)
    else
        love.graphics.setColor(bright)
        love.graphics.draw(bIcon,500,500,0,1,1,32,32)
    end
end

-- Returns true if the player is in a lobby / in game
local function inLobby()
    return (state[1] == "in lobby" or state[1] == "hosting lobby" or state[1] == "in game" or state[1] == "hosting game")
end

local function offline()
    return (state[1] == "main menu" or state[1] == "gamemode select")
end

-- Updates the list of avialable maps
local function updateMaps()
    maps = List:new()
    for map in ReadMap:get() do
        maps:push(map)
    end
end

local function getMap()
    local splitData = Util:split(maps:getVal(),".")
    return splitData[1]
end

updateMaps()

-- ============================================================================================-- 
-- ============================================================================================-- 

-- Adding cases to the switch statements

stateSwitch:addCase("searching for lobby",function()
    if not mainClient then return end

    if order == 1 then updateLobbyButtons() end

    if tick % 2 == 0 then
        mainClient:send("no dat\n")
    end

    processReceived()
end)

stateSwitch:addCase("hosting lobby",function()
    if not (server and mainClient) then return end
    processReceived()

    if order == 1 then 
        updateKickButtons()
        updateTeamButtons()
    end
    if tick % refreshRate == 0 then
        server:sendUpdateMessage()
        mainClient:send("updt:"..server.ID.."_player count_"..server.playerCount.."_\n")
    elseif tick % 2       == 0 then
        server:update()
    else
        server:send("all","no dat".."_\n")
    end
end)

stateSwitch:addCase("connecting to lobby",function()
    if not player then return end

    processReceived()
end)

stateSwitch:addCase("in lobby",function()
    if not player then return end

    processReceived()
end)

local aSuccess = false
local bSuccess = false

stateSwitch:addCase("in game",function(dt)
    if not player then return end

    polyCoords = {}

    processReceived()

    World:update(dt,true)

    if order == 1 and not editingText then
        local x,y,a,b,ap,bp = Util:processGameInputs(tick,aSuccess,bSuccess)

        local ball = World.focus

        aPercentage = ap
        bPercentage = bp

        inputSum.x = inputSum.x + x
        inputSum.y = inputSum.y + y
        inputSum.aHeld = tonumber(a > 0)
        if a == -1 then
            table.insert(inputSum.abilities,abilitySwitch:case(aAbility,ball))
            aSuccess = true
        else
            aSuccess = false
        end
        inputSum.bHeld = tonumber(b > 0)
        if b == -1 then
            table.insert(inputSum.abilities,abilitySwitch:case(bAbility,ball))
            aSuccess = true
        else
            bSuccess = false
        end
    end

    if order == 1 and not editingText and tick % inputCooldown == 0 then
        
        local inX = inputSum.x
        local inY = inputSum.y
        player:send("plin:move_"..player.ID.."_"..inX.."_"..inY.."_\n")
        for i,msg in ipairs(inputSum.abilities) do
            player:send(msg)
        end
        inputSum.x = 0
        inputSum.y = 0
        inputSum.abilities = {}
    end
end)

stateSwitch:addCase("hosting game",function(dt)
    if not server then return end
    server:send("all","no dat".."_\n")
    processReceived()

    for rope in World:getRope() do
        server:send("all",rope)
    end

    World:update(dt,false)

    for damage in World:getDamg() do
        server:send("all",damage)
    end

    for objective in World:getObjv() do
        server:send("all",objective)
    end

    if order == 1 and not editingText then
        local ball = World.focus
        local nx,ny,a,b,ap,bp = Util:processGameInputs(tick,aSuccess,bSuccess)

        aPercentage = ap
        bPercentage = bp

        applyMove(ball,nx,ny)

        --Passes the selected abilities into ability switch to be
        --processed.
        if a == -1 then
            aSuccess = abilitySwitch:case(aAbility,ball)
        else
            aSuccess = false
        end

        if b == -1 then
            bSuccess = abilitySwitch:case(bAbility,ball)
        else
            bSuccess = false
        end
    end

    if tick % refreshRate == 0 then
        server:sendUpdateMessage()
    end

    if tick % 1 == 0 then
        local gameState = World:getUpgm()
        for i, ball in ipairs(gameState) do
            server:send("all",ball)
        end
    end

    if order == 1 and World.atGoal then
        local gameResults = World:getGameResults()
        local msg = "endgm:"
        for i,v in ipairs(gameResults) do
            if type(v) == "string" then msg = msg..v.."_"
            elseif type(v) == "table" then msg = msg..v[1].."_"..v[2].."_" end
        end
        server:send("all",msg.."\n")

        for i = 1,4 do
            local score = Util:calculateID(4,i)
            msg = msg.."team"..i.."_"..score
            if i < 4 then msg = msg.."_" end
        end

        server:send("all",msg.."_\n")
        state[2]  = "end screen"
        lState[2] = nil
        order     = 2

    end
end)

-- ============================================================================================-- 
-- ============================================================================================-- 

newStateSwitch:addCase("main menu",function()
    clearButtons()
    newButton(1,"click to start",300,300,500,350,function()
        state[1] = "gamemode select"
    end)
    lState[1] = state[1]
end)

newStateSwitch:addCase("gamemode select",function()
    clearButtons()
    newButton(1,"multiplayer",300,100,500,150,function()
        state[1] = "connecting to server"
    end)
    newButton(1,"settings",300,300,500,350,function()
        state[2] = "user settings"
        order    = 2
    end)
    newButton(1,"back",300,500,500,550,function()
        state[1] = "main menu"
    end)
    lState[1] = state[1]
end)

newStateSwitch:addCase("connecting to server",function()
    clearButtons()
    print("connecting to main")
    local nPlayer = Player:new()
    if not nPlayer then
        lState[1] = "connecting to server"
        state[1]  = "connection error"
    else
        lState[1] = "connecting to server"
        state[1]  = "searching for lobby"

        nPlayer.ID     = Util:calculateID(8)
        mainClient     = nPlayer
        player         = nPlayer
    end
end)

newStateSwitch:addCase("connection error",function()
    clearButtons()
    print("connection error")
    newButton(1,"retry",300,375,500,425,function()
        state[1] = "connecting to server"
    end)
    newButton(1,"back",300,450,500,500,function()
        state[1] = "gamemode select"
    end)
    lState[1]    = state[1]
end)

newStateSwitch:addCase("user settings",function()
    clearButtons()
    newButton(2,"configure settings",300,300,500,350,function()
        order     = 3
        state[3]  = "configure game settings"
        lState[3] = nil
    end)
    newButton(2,"back",300,375,500,425,function()
        state[2]  = nil
        lState[2] = nil
        order     = 1
    end)
    newButton(2,"quit",300,450,500,500,function()
        love.event.quit()
    end)
    lState[2] = state[2]
end)

newStateSwitch:addCase("configure game settings",function()
    newButton(3,"back",300,375,500,425,function()
        -- arbitrary values so user settings can open above any menu
        state[3]  = nil
        lState[3] = nil
        order     = 2
    end)
    lState[3] = state[3]
end)

newStateSwitch:addCase("searching for lobby",function()
    if not mainClient then return end
    clearButtons()

    JoinableLobby:clear()
    -- no text, the player name is drawn separatly above the button
    local nameButton = newButton(1,"",300,25,500,75,function()
        state[2]  = "editing player name"
        lState[2] = nil
        order     = 2
    end)
    nameButton:preset("text editing")
    newButton(1,"Create new lobby",300,400,500,450,function()
        lState[2] = nil
        state[2]  = "lobby creation"
        order     = 2
    end)
    newButton(1,"back",300,475,500,525,function()
        mainClient:send("econ:"..mainClient.ID.."_\n")
        toChangeState = "gamemode select"
        tempTick      = 30
        JoinableLobby:clear()
    end)
    lState[1] = state[1]
end)

newStateSwitch:addCase("editing player name",function()
    if not mainClient then return end
    clearButtons()
    
    editingText  = mainClient.name
    editingIndex = #editingText + 1
    local cancel = newButton(2,"cancel",300,80,398,105,function()
        state[2]    = nil
        lState[2]   = nil
        order       = 1
        editingText = nil
    end)
    cancel:preset("cancel")
    local confirm = newButton(2,"confirm",402,80,500,105,function()
        changePlayerName()
    end)
    confirm:preset("confirm")
    lState[2] = state[2]
end)

newStateSwitch:addCase("lobby creation",function()
    if not mainClient then return end
    clearButtons()
    newButton(2,"back",300,300,500,350,function()
        state[2]  = nil
        lState[2] = nil
        state[1]  = "searching for lobby"
        order     = 1
    end)
    newButton(2,"Lobby settings",300,375,500,425,function()
        lState[3] = nil
        state[3]  = "lobby settings"
        order     = 3
    end)
    newButton(2,"Create",300,450,500,500,function()
        local lobbyID = Util:calculateID(6)
        local IP      = Socket.dns.toip(Socket.dns.gethostname( ))
        local port    = 1000
        mainClient:send("create:"..
            lobbyID.."_"..
            lobbyToCreate.name.."_"..
            mainClient.ID.."_"..
            mainClient.name.."_"..
            IP.."_"..
            port.."_"..
            lobbyToCreate.maxPlayers.."_\n"
        )
    end)
    lState[2] = state[2]
end)

newStateSwitch:addCase("lobby settings",function()
    clearButtons()
    -- no text, lobby name drawn above text
    local nameButton = newButton(3,"",300,300,500,350,function()
        lState[4] = nil
        state[4]  = "editing lobby name"
        order     = 4
    end)
    nameButton:preset("text editing")
    newButton(3,"max players",300,375,500,425,function()
        -- change number of max players (2,4,8?)
    end)
    newButton(3,"back",300,450,500,500,function()
        state[3]  = nil
        lState[3] = nil
        order     = 2
    end)
    lState[3] = state[3]
end)

newStateSwitch:addCase("editing lobby name",function()
    if not mainClient then return end
    clearButtons()
    
    editingText  = lobbyToCreate.name
    editingIndex = #editingText + 1
    local cancel = newButton(4,"cancel",300,355,398,380,function()
        state[4]    = nil
        lState[4]   = nil
        order       = 3
        editingText = nil
    end)
    cancel:preset("cancel")
    local confirm = newButton(4,"confirm",402,355,500,380,function()
        changeLobbyName()
    end)
    confirm:preset("confirm")
    lState[4] = state[4]
end)

newStateSwitch:addCase("hosting lobby",function()
    if not (mainClient and server) then return end

    clearButtons()

    --Initialises the switch statement to process game inputs.
    --Different output for client and host players.
    abilitySwitch = Switch:new()

    abilitySwitch:addCase("dash",function(ball)
        local mx,my = love.mouse.getPosition()
        local offsetX,offsetY = World:getOffset()
        local bx,by = offsetX+ball.x,offsetY+ball.y
        local angle = Util:yawAngle(mx-bx,my-by)
        
        return ball:dash(angle,1000)
    end)

    abilitySwitch:addCase("rope",function(ball)
        local mx,my = love.mouse.getPosition()
        local offsetX,offsetY = World:getOffset()
        local rx,ry = mx - offsetX, my - offsetY

        return ball:rope(rx,ry)
    end)

    abilitySwitch:addCase("shoot",function(ball)
        local mx,my = love.mouse.getPosition()
        local offsetX,offsetY = World:getOffset()
        local bx,by = offsetX+ball.x,offsetY+ball.y
        local angle = Util:yawAngle(mx-bx,my-by)
        
        return ball:shoot(angle,3000)
    end)

    --Buttons for changing the selected abilities
    newButton(1,"<",63,434,95,466,function()
        changeAbiltiy(1,false)
    end)
    newButton(1,">",137,434,169,466,function()
        changeAbiltiy(1,true)
    end)
    newButton(1,"<",63,470,95,502,function()
        changeAbiltiy(2,false)
    end)
    newButton(1,">",137,470,169,502,function()
        changeAbiltiy(2,true)
    end)

    love.graphics.setBackgroundColor( 0,0,0 )

    if lState[1] ~= "in game"  then
        LobbyPlayer:clear()
        LobbyPlayer:new(mainClient.ID)
        LobbyPlayer:setName(mainClient.ID,     mainClient.name)
        LobbyPlayer:setReady(mainClient.ID,    true)
        LobbyPlayer:setInLobby(mainClient.ID,  true)
        LobbyPlayer:setTeam(mainClient.ID,    "team 1")

        local y = 20

        local nTeamButton = Button:new("",0,450,y,500, y + 17.5,function()
            local nTeam = nextTeam[LobbyPlayer:getTeam(mainClient.ID)]
            LobbyPlayer:setTeam(mainClient.ID,nTeam)
        end)
        nTeamButton:preset("text editing")

        teamButtons:append(nTeamButton)
        TeamButton:new(mainClient.ID,nTeamButton)
    end

    newButton(1,"start",600,500,750,550,function()

        --Get all the unique teams from all players, return false if not all players are ready
        local teams = playersAllReady()
        if teams then
            server:send("all","start:".."_\n")
            state[1]  = "hosting game"
            lState[1] = nil
            order     = 1
            --Clears all existing balls
            World:clear()

            local msg = "actm:"
            for team,i in teams:pairs() do
                msg = msg..team.."_"
            end
            server:send("all",msg.."\n")

            --Defines which teams have players for this round
            World:setActiveTeams(teams)
        else
            sendMessage("ready up")
        end
    end)

    lState[1] = state[1]
end)

newStateSwitch:addCase("connecting to lobby",function()
    if not player then return end

    print("sending ncon")

    player:send("ncon:"..player.ID.."_"..player.name.."_\n")
    lState[1] = state[1]
end)

newStateSwitch:addCase("in lobby",function()
    if not player then return end

    clearButtons()

    abilitySwitch = Switch:new()

    abilitySwitch:addCase("dash",function(ball)
        local mx,my = love.mouse.getPosition()
        local offsetX,offsetY = World:getOffset()
        local bx,by = offsetX+ball.x,offsetY+ball.y
        local angle = Util:yawAngle(mx-bx,my-by)

        return "plin:dash"..ball.ID.."_"..angle.."_"..(1000).."_\n"
    end)

    abilitySwitch:addCase("rope",function(ball)
        local mx,my = love.mouse.getPosition()
        local offsetX,offsetY = World:getOffset()
        local rx,ry = mx - offsetX, my - offsetY

        return "plin:rope_"..ball.ID.."_"..rx.."_"..ry.."_\n"
    end)

    abilitySwitch:addCase("shoot",function(ball)
        local mx,my = love.mouse.getPosition()
        local offsetX,offsetY = World:getOffset()
        local bx,by = offsetX+ball.x,offsetY+ball.y
        local angle = Util:yawAngle(mx-bx,my-by)

        return "plin:dash"..ball.ID.."_"..angle.."_"..(3000).."_\n"
    end)

    --Buttons for changing the selected abilities
    newButton(1,"<",63,434,95,466,function()
        changeAbiltiy(1,false)
    end)
    newButton(1,">",137,434,169,466,function()
        changeAbiltiy(1,true)
    end)
    newButton(1,"<",63,470,95,502,function()
        changeAbiltiy(2,false)
    end)
    newButton(1,">",137,470,169,502,function()
        changeAbiltiy(2,true)
    end)

    love.graphics.setBackgroundColor( 0,0,0 )

    newButton(1,"ready",600,500,750,550,function()
        local ready = LobbyPlayer:getReady(player.ID)
        LobbyPlayer:setReady(player.ID,not ready)
        player:send("updt:"..player.ID.."_ready_"..tostring(not ready).."_\n")
    end)

    abilitySwitch = Switch:new()

    lState[1] = state[1]
end)

newStateSwitch:addCase("editing message",function()
    clearButtons()

    editingText  = ""
    editingIndex = 1

    local send = newButton(2,"send",450,400,550,420,function()
        sendMessage()
    end)
    send:preset("confirm")
    lState[2] = state[2]
end)

newStateSwitch:addCase("hosting game",function()
    if not (server and mainClient) then return end
    clearButtons()

    love.graphics.setBackgroundColor( 0,0.2,0 )

    LobbyPlayer:setInLobby(mainClient.ID,false)
    
    --Load the map file
    ReadMap:open(maps:getVal())

    World.ballsList:prev()
    local playerBall = World.ballsList:getVal()
    World:setFocus(playerBall)

    World:generateIDs()

    World:assignAll(LobbyPlayer:getIDs())

    local gameState = World:getUpgm()
    for i, ball in ipairs(gameState) do
        server:send("all",ball)
    end
    server:send("all",World:getAsgn())

    lState[1] = state[1]
end)

newStateSwitch:addCase("in game",function()
    if not player then return end
    clearButtons()

    love.graphics.setBackgroundColor( 0,0.2,0 )

    lState[1] = state[1]
end)

newStateSwitch:addCase("end screen",function()
    if not player then return end
    clearButtons()

    newButton(2,"Return to lobby",300,300,500,350,function()
        --Last state set to in game to stop IDs being dropped
        LobbyPlayer:setInLobby(player.ID,true)
        if server then
            state[2]  = nil
            lState[2] = nil
            lState[1] = "in game"
            state[1]  = "hosting lobby"
            order     = 1
            server:send("all","updt:"..player.ID.."_in lobby_true_\n")
        else
            state[2]  = nil
            lState[2] = nil
            lState[1] = "in game"
            state[1]  = "in lobby"
            order     = 1
            player:send("updt:"..player.ID.."_in lobby_true_\n")
        end
    end)

    lState[2] = state[2]
end)

newStateSwitch:addCase("lobby pause screen",function()
    if not player then return end
    clearButtons()

    newButton(2,"back",300,300,500,350, function()
        state[2]  = nil
        lState[2] = nil
        order     = 1
    end)

    if server then
        newButton(2,"game settings",300,375,500,425, function()
            lState[3] = nil
            state[3]  = "game settings"
            order     = 3
        end)
        newButton(2,"close lobby",300,450,500,500, function()
            for i, ID in ipairs(LobbyPlayer:getIDs()) do
                if ID ~= player.ID then server:send("all","kick:"..ID.."_\n") end
            end
            player:send("clse:"..server.ID.."_\n")
            toChangeState = "searching for lobby"
            JoinableLobby:clear()
            tempTick      = 30
            state[2]      = nil
            order         = 1
        end)
    else
        newButton(2,"exit lobby",300,375,500,425, function()
            player:send("econ:"..player.ID.."_\n")
        end)
    end
    lState[2] = state[2]
end)

newStateSwitch:addCase("game settings",function()
    if not server then return end
    clearButtons()
    local function goBack()
        lState[3] = nil
        state[3]  = nil
        order     = 2
    end
    newButton(3,"back",360,325,440,365, function()
        goBack()
    end)

    --kill buttons
    for i = 1,3 do
        newButton(3,(i*5).." kills",260 + 100 * (i-1),375,340 + 100 * (i-1),415, function()
            server:send("all","sgoal:kills_"..i*5)
            World:setGoal("kills",i*5)
            goBack()
        end)
    end

    --damage buttons
    for i = 1,3 do
        newButton(3,"deal "..(i*250).."\ndamage",260 + 100 * (i-1),425,340 + 100 * (i-1),465, function()
            server:send("all","sgoal:damage dealt_"..i*250)
            World:setGoal("damage dealt",i*250)
            goBack()
        end)
    end

    --deaths buttons
    for i = 1,3 do
        newButton(3,(i*5).." lives",260 + 100 * (i-1),475,340 + 100 * (i-1),515, function()
            server:send("all","sgoal:deaths_"..i*5)
            World:setGoal("deaths",i*5)
            goBack()
        end)
    end
    
    lState[3] = state[3]
end)

-- ============================================================================================-- 
-- ============================================================================================-- 

drawStateSwitch:addCase("main menu",function()
    love.graphics.setColor(1,1,1)
    love.graphics.print("This is the main menu",300,100)
    drawButtons(1)
end)

drawStateSwitch:addCase("gamemode select",function()
    love.graphics.setColor(1,1,1)
    love.graphics.print("Leaderboard",300,50)
    drawButtons(1)
end)

drawStateSwitch:addCase("connecting to server",function()
    drawButtons(1)
end)

drawStateSwitch:addCase("connection error",function()
    drawButtons(1)
    love.graphics.setColor(1,1,1)
    love.graphics.print("connection error",300,100)
end)

drawStateSwitch:addCase("hosting main",function()
    if not server then return end
    drawButtons(1)
    love.graphics.setColor(1,1,1)
    love.graphics.print("You are now the main host",300,500)
    
    love.graphics.print("player Count: "..server.playerCount,300,400)
end)

drawStateSwitch:addCase("user settings",function()
    love.graphics.setColor(0.5,0.5,0.5)
    love.graphics.rectangle("fill",250,250,300,300)
    drawButtons(order)
end)

drawStateSwitch:addCase("configure game settings",function()
    love.graphics.setColor(0.5,0.5,0.5)
    love.graphics.rectangle("fill",250,250,300,300)
    drawButtons(order)
end)

drawStateSwitch:addCase("searching for lobby",function()
    if not mainClient then return end
    drawLobbyButtons()
    love.graphics.setColor(0,0,0)
    love.graphics.rectangle("fill",0,0,800,100)
    love.graphics.rectangle("fill",0,375,800,225)
    drawButtons(1)
    
    love.graphics.setColor(1,1,1)
    -- Drawing the player name onto the edit player name button
    local playerNameText
    if editingText and getState(2) == "editing player name" then playerNameText = editingText
    else playerNameText = mainClient.name end
    if playerNameText then love.graphics.print(playerNameText,300,25) end
end)

drawStateSwitch:addCase("editing player name",function()
    drawButtons(2)
    if tick % 30 > 30 / 2 then
        love.graphics.setColor(0.4,0.4,0.4,0.7)
        love.graphics.rectangle("fill",300 - 2.5 + (editingIndex-1)*9,25,5,17.5)
    end
end)

drawStateSwitch:addCase("lobby creation",function()
    love.graphics.setColor(0.5,0.5,0.5)
    love.graphics.rectangle("fill",280,280,240,240)
    drawButtons(2)
end)

drawStateSwitch:addCase("lobby settings",function()
    love.graphics.setColor(0.5,0.5,0.5)
    love.graphics.rectangle("fill",280,280,240,240)
    drawButtons(3)

    love.graphics.setColor(1,1,1)
    -- Drawing the lobby name onto the edit lobby name button
    local LobbyNameText
    if editingText and getState(4) == "editing lobby name" then LobbyNameText = editingText
    else LobbyNameText = lobbyToCreate.name end
    if LobbyNameText then love.graphics.print(LobbyNameText,300,300) end
end)

drawStateSwitch:addCase("editing lobby name",function()
    drawButtons(4)
    if tick % 30 > 30 / 2 then
        love.graphics.setColor(0.4,0.4,0.4,0.7)
        love.graphics.rectangle("fill",300 - 2.5 + (editingIndex-1)*9,300,5,17.5)
    end
end)

drawStateSwitch:addCase("hosting lobby",function()
    if not server then return end
    drawMessages()
    drawButtons(1)
    drawKickButtons()
    drawTeamButtons()
    love.graphics.setColor(1,1,1)
    for i, ID in ipairs(LobbyPlayer:getIDs()) do
        local name  = LobbyPlayer:getName(ID)
        local ready = Util:toBool(LobbyPlayer:getReady(ID))
        local readyString = "not ready"
        if ready then readyString = "ready"end
        local lobby = Util:toBool(LobbyPlayer:getInLobby(ID))
        local inLobbyString = "in game"
        if lobby then inLobbyString = "in lobby"end
        local team  = LobbyPlayer:getTeam(ID)

        if name and ready ~= nil and team then
            love.graphics.print(name,0,20*i)
            love.graphics.print(readyString,200,20*i)
            love.graphics.print(inLobbyString,300,20*i)
            love.graphics.print(team,400,20*i)
        end
    end

    love.graphics.draw(iconDict[aAbility],100,434,0,0.5,0.5)
    love.graphics.draw(iconDict[bAbility],100,470,0,0.5,0.5)

    love.graphics.print("map",100,500)
    love.graphics.print(getMap(),100,520)

end)

drawStateSwitch:addCase("connecting to lobby",function( )
    love.graphics.setColor(1,1,1)
    love.graphics.print("connecting to lobby...",100,100)
end)

drawStateSwitch:addCase("in lobby",function()
    drawMessages()
    drawButtons(1)
    love.graphics.setColor(1,1,1)
    for i, ID in ipairs(LobbyPlayer:getIDs()) do
        local name  = LobbyPlayer:getName(ID)
        local ready = Util:toBool(LobbyPlayer:getReady(ID))
        local readyString = "not ready"
        if ready then readyString = "ready"end
        local lobby = Util:toBool(LobbyPlayer:getInLobby(ID))
        local inLobbyString = "in game"
        if lobby then inLobbyString = "in lobby"end
        local team  = LobbyPlayer:getTeam(ID)

        if name and ready ~= nil and team then
            love.graphics.print(name,0,20*i)
            love.graphics.print(readyString,200,20*i)
            love.graphics.print(inLobbyString,300,20*i)
            love.graphics.print(team,400,20*i)
        end
    end

    love.graphics.draw(iconDict[aAbility],100,434,0,0.5,0.5)
    love.graphics.draw(iconDict[bAbility],100,470,0,0.5,0.5)

end)

drawStateSwitch:addCase("editing message",function()
    drawButtons(2)
    love.graphics.setColor(1,1,1)
    if editingText then
        love.graphics.print(editingText,50,400)
    end
    if tick % 30 > 30 / 2 then
        love.graphics.setColor(0.4,0.4,0.4,0.7)
        love.graphics.rectangle("fill",50 - 2.5 + (editingIndex-1)*9,400,5,17.5)
    end
end)

drawStateSwitch:addCase("in game",function()
    World:draw()
    love.graphics.setColor(1,1,1)
    for i,poly in ipairs(polyCoords) do
        if #poly % 2 == 0 then
            love.graphics.polygon("fill",poly)
        end
    end
    drawIcons()
    drawMessages()
end)

drawStateSwitch:addCase("hosting game",function()
    World:draw()
    drawIcons()
    drawMessages()
end)

drawStateSwitch:addCase("end screen",function()
    love.graphics.setColor(0.5,0.5,0.5)
    love.graphics.rectangle("fill",200,280,400,240)
    drawButtons(2)

    love.graphics.setColor(1,1,1)
    --Display the winning team
    love.graphics.print("Winning team: "..World.gameResults["winner"],220,370)

    --Display the MVP players
    local kills  = World.gameResults["kills"]
    local deaths = World.gameResults["deaths"]
    local damageDealt = World.gameResults["damage dealt"]
    local damageTaken = World.gameResults["damage taken"]

    love.graphics.print(LobbyPlayer:getName(kills[1]).." got "..kills[2].." kills",220,390)
    love.graphics.print(LobbyPlayer:getName(deaths[1]).." got "..deaths[2].." deaths",220,410)
    love.graphics.print(LobbyPlayer:getName(damageDealt[1]).." did "..math.floor(damageDealt[2]).." damage",220,430)
    love.graphics.print(LobbyPlayer:getName(damageTaken[1]).." took "..math.floor(damageTaken[2]).." damage",220,450)
end)

drawStateSwitch:addCase("lobby pause screen",function()
    love.graphics.setColor(0.5,0.5,0.5)
    love.graphics.rectangle("fill",280,280,240,240)
    drawButtons(2)
end)

drawStateSwitch:addCase("game settings",function()
    love.graphics.setColor(0.5,0.5,0.5)
    love.graphics.rectangle("fill",240,275,320,250)
    love.graphics.setColor(1,1,1)
    local goal = World:getGoal()
    love.graphics.print("Victory conditon: "..goal[1].." "..goal[2],245,280)
    drawButtons(3)
end)

-- ============================================================================================-- 
-- ============================================================================================-- 

-- Send a message to players, relays this message to other players as the server
netSwitch:addCase("msg",function(args)
    local splitData = Util:split(args,"_")
    local sender    = splitData[1]
    local message   = splitData[2]

    if server then server:send("all","msg:"..sender.."_"..message.."_\n") end

    newMessage(sender,message)
end)

netSwitch:addCase("kick",function(args)
    if not player or server then return end
    local splitData = Util:split(args,"_")
    local playerID  = splitData[1]
    player:send("econ:"..playerID.."_\n")
end)

netSwitch:addCase("clse",function(args)
    if not player then return end
    local splitData = Util:split(args,"_")

    local lobbyID = splitData[1]
    local button = LobbyButton:get(lobbyID)

    if button then
        removeButton(1,button)
        LobbyButton:remove(button)
        lobbyButtons:removeItem(button)
    end
end)

-- New connection, sends initial information about the player
netSwitch:addCase("ncon",function(args)
    print("ncon message received")
    if server then
        print("new connection")
        local splitData = Util:split(args,"_")

        local ID   = splitData[1]
        local name = splitData[2]

        print("confirmed connection")
        LobbyPlayer:new(ID)
        LobbyPlayer:setName(ID,name)
        LobbyPlayer:setReady(ID,false)
        LobbyPlayer:setInLobby(ID,true)
        LobbyPlayer:setTeam(ID,"team 1")

        --Creates player specific kick and team button for the host to use
        local y         = #LobbyPlayer:getIDs() * 20
        local nKickButton   = Button:new("kick",0,450,y,500, y + 17.5)

        nKickButton.command = function()
            server:send("all","kick:"..ID.."_\n")
        end
        nKickButton:preset("cancel")
        kickButtons:append(nKickButton)
        KickButton:new(ID,nKickButton)

        local nTeamButton = Button:new("",0,450,y,500, y + 17.5,function()
            local nTeam = nextTeam[LobbyPlayer:getTeam(ID)]
            LobbyPlayer:setTeam(ID,nTeam)
        end)
        nTeamButton:preset("text editing")

        teamButtons:append(nTeamButton)
        TeamButton:new(ID,nTeamButton)

        server:send("all","ncon:"..ID.."_"..name.."_confirm_\n")
    end

    if player then
        local splitData = Util:split(args,"_")

        local ID   = splitData[1]
        local name = splitData[2]
        local conf = splitData[3]

        if conf == "confirm" and ID == player.ID then
            print("successfully joined lobby")
            -- On confirmation, make a LobbyPlayer object with player's details
            LobbyPlayer:clear()
            LobbyPlayer:new(player.ID)
            LobbyPlayer:setName(player.ID,player.name)
            LobbyPlayer:setReady(player.ID,false)
            LobbyPlayer:setInLobby(player.ID,true)
            LobbyPlayer:setTeam(player.ID,"team 1")
            if getState(1) == "connecting to lobby" then
                lState[1]  = nil
                state[1]   = "in lobby"
            end
        end
    end
end)

-- End connection with main server
netSwitch:addCase("econ",function(args)
    if server then
        local splitData = Util:split(args,"_")
        local ID        = splitData[1]
        server:send("all","econ:"..ID.."_".."false".."_\n")
        toRemoveIDs:push(ID)
        local button = KickButton:get(ID)
        kickButtons:removeItem(button)
        KickButton:remove(ID)
    elseif player then
        local splitData = Util:split(args,"_")
        local playerID  = splitData[1]
        local isMain    = splitData[2]

        if playerID    == player.ID then
            toClosePlayer = false

            if Util:toBool(isMain) then
                
            else
                tempTick      = 30
                toConnectMain = true
            end
            lState[2] = nil
            state[2]  = nil
            lState[1] = nil

            JoinableLobby:clear()
            LobbyPlayer:clear()

            clearMessages()
        else
            toRemoveIDs:push(playerID)
        end
    end
end)

-- Update player info, for when player changes ready state or name
netSwitch:addCase("updt",function(args)
    local splitData = Util:split(args,"_")
    -- sender ID
    local ID    = splitData[1]
    local field = splitData[2]
    local value = splitData[3]

    if not LobbyPlayer:getName(ID) then LobbyPlayer:new(ID) end

    if field     == "name"         then LobbyPlayer:setName(ID,value)
    elseif field == "ready"        then LobbyPlayer:setReady(ID,value)
    elseif field == "in lobby"     then LobbyPlayer:setInLobby(ID,value)
    elseif field == "team"         then LobbyPlayer:setTeam(ID,value)
    end
end)

-- Request and confirm joining a new lobby
netSwitch:addCase("join",function(args)
    if not mainClient then return end
    local splitData  = Util:split(args,"_")
    local ID   = splitData[1]
    local IP   = splitData[2]
    local port = splitData[3]

    if ID == mainClient.ID then
        local nPlayer   = Player:new(IP,port)
        if nPlayer then
            toChangeState   = "connecting to lobby"
            tempTick        = 30

            nPlayer.name    = mainClient.name
            nPlayer.ID      = mainClient.ID

            toConnectPlayer = nPlayer
        end
    end
end)

-- Create a new lobby and confirm creation
netSwitch:addCase("create",function(args)
    if not mainClient then return end
    local splitData   = Util:split(args,"_")

    local hostID      = splitData[1]
    local lobbyID     = splitData[2]
    local lobbyName   = splitData[3]
    local IP          = splitData[4]
    local port        = splitData[5]
    local maxPlayers  = splitData[6]

    if mainClient.ID  == hostID then

        -- Host has both a server and player object, player object is kept
        toChangeState = "hosting lobby"
        tempTick      = 30

        server        = Lobby:new(lobbyID,lobbyName,port,IP,mainClient.ID,maxPlayers)

    end
end)

-- Update lobby list
netSwitch:addCase("uplobs",function(args)
    local splitData   = Util:split(args,"_")

    local lobbyID     = splitData[1]
    local lobbyName   = splitData[2]
    local hostName    = splitData[3]
    local IP          = splitData[4]
    local port        = splitData[5]
    local playerCount = splitData[6]
    local maxPlayers  = splitData[7]

    if not JoinableLobby:has(lobbyID) then
        
        JoinableLobby:new(lobbyID)
        JoinableLobby:setName(lobbyID,lobbyName)
        JoinableLobby:setHostName(lobbyID,hostName)
        JoinableLobby:setIP(lobbyID,IP)
        JoinableLobby:setPort(lobbyID,port)
        JoinableLobby:setPlayerCount(lobbyID,playerCount)
        JoinableLobby:setMaxPlayers(lobbyID,8)

        local y = #JoinableLobby.IDTable * 40
        local nButton = Button:new("lobby name: "..lobbyName.." host name: "..hostName.." count: "..playerCount.."/"..maxPlayers,0,100,100 + y,700,135 + y,function()
            if mainClient then
                mainClient:join(lobbyID)
            end
        end)
        lobbyButtons:append(nButton)
        LobbyButton:new(lobbyID,nButton)
    else
        JoinableLobby:setPlayerCount(lobbyID, playerCount)
        LobbyButton:setText(lobbyID,"lobby name: "..lobbyName.." host name: "..hostName.." count: "..playerCount.."/"..maxPlayers)
    end
end)

-- Start a new game
netSwitch:addCase("start",function(args)
    if not player then return end
    -- Remove any graphics from menus, eg pause menu
    state[2]  = nil
    lState[2] = nil
    state[1]  = "in game"
    lState[1] = nil
    order     = 1
    LobbyPlayer:setInLobby(player.ID,false)
    player:send("updt:"..player.ID.."_in lobby_false".."_\n")
    -- Clears all existing balls
    World:clear()
end)

-- Asign ball ID to a player
netSwitch:addCase("asgn",function(args)
    if not player then return end
    local splitData = Util:split(args,"_")

    for i = 1,#splitData / 2 do
        local ballID   = splitData[i*2-1]
        local playerID = splitData[i*2]
        World:assign(playerID,ballID)
        if player.ID         == playerID then
            player.ballID     = ballID
            local playerBall  = World:getByID(ballID)
            World:setFocus(playerBall)
        end
    end
end)

-- Take player input from clients
netSwitch:addCase("plin",function(args)
    if not server then return end

    local splitData = Util:split(args,"_")

    local command   = splitData[1]
    local ID        = splitData[2]
    if command == "move" then
        local x         = splitData[3]
        local y         = splitData[4]

        local ballID    = LobbyPlayer:getBallID(ID)
        local ball      = World:getByID(ballID)

        applyMove(ball,x,y)
    end
    if command == "dash" then
        local angle     = splitData[3]
        local force     = splitData[4]

        local ball      = World:getByID(ID)

        ball:dash(angle,force)
    end
    if command == "rope" then
        local rx     = splitData[3]
        local ry     = splitData[4]

        local ball   = World:getByID(ID)

        ball:rope(rx,ry)
    end

    if command == "shoot" then
        local angle  = splitData[3]
        local force  = splitData[4]

        local ball   = World:getByID(ID)

        ball:shoot(angle,force)
    end

end)

-- Update gamestate
netSwitch:addCase("upgm",function(args)
    if not player then return end

    local splitData = Util:split(args,"_")
    local objType   = splitData[1]
    -- Changes = {{ID1,x1,y1},{ID2,x2,y2},{ID3,x3,y3}}
    local changes   = {}
    if objType == "ball" then
        for i,msg in ipairs(splitData) do
            local ind   = i - 2
            if changes[math.floor(ind/3)+1] == nil then
                changes[math.floor(ind/3)+1] = {}
            end
            changes[math.floor(ind/3)+1][(ind%3) + 1] = msg
        end

        for i, change in ipairs(changes) do
            local ID        = change[1]
            local ascX      = change[2]
            local ascY      = change[3]
            if ID and ascX and ascY then
                local ball  = World:getByID(ID)
                local x,y   = Util:hexToCoord(ascX,ascY)
                if ball then
                    ball.x  = x
                    ball.y  = y
                else
                    local nball = World:newBall(x,y,true)
                    World:assignID(nball,ID,0)
                end
            end
        end
    elseif objType == "poly" then
        local coords = {}
        local offsetX,offsetY = World:getOffset()
        for i = 1,((#splitData)-1)/2 do
            local ascX = splitData[i*2]
            local ascY = splitData[1+i*2]
            if ascX and ascY then
                local x,y  = Util:hexToCoord(ascX,ascY)
                table.insert(coords,x + offsetX)
                table.insert(coords,y + offsetY)
            end
        end
        table.insert(polyCoords,coords)
    end
end)

netSwitch:addCase("damg",function(args)
    if not player then return end
    local splitData          = Util:split(args,"_")
    local ballID             = splitData[1]
    local health             = Util:hexToNum(splitData[2])/10
    local force              = Util:hexToNum(splitData[3])/10
    local centreX,centreY    = Util:hexToCoord(splitData[4],splitData[5])
    local ball               = World:getByID(ballID)
    if ball then ball.health = health end
    if force and centreX and centreY then
        World:newParticle("spark",centreX,centreY,math.floor(force)*1.5 / 2,force/2)
        World:newParticle("spark",centreX,centreY,math.floor(force) / 2    ,1)
    end
end)

--Objective message
netSwitch:addCase("objv",function(args)
    if not player then return end
    local splitData          = Util:split(args,"_")
    local event              = splitData[1]
    local team               = splitData[2]
    local value              = splitData[3]
    World:setScore(event,team,value)
end)

--Set the goal score message
netSwitch:addCase("sgoal",function(args)
    if not player then return end
    local splitData          = Util:split(args,"_")
    local event              = splitData[1]
    local value              = splitData[2]
    World:setGoal(event,value)
end)

--Active teams message
netSwitch:addCase("actm",function(args)
    local teamSet   = Set:new()
    local splitData = Util:split(args,"_")
    for i,team in ipairs(splitData) do
        teamSet:add(team)
    end
    World:setActiveTeams(teamSet)
end)

netSwitch:addCase("nrope",function(args)
    if not player then return end
    local splitData = Util:split(args,"_")
    local ID1    = splitData[1]
    local ID2    = splitData[2]

    World:newRope(ID1,ID2,0,0)
end)

-- End game and display the end screen
netSwitch:addCase("endgm",function(args)
    local splitData   = Util:split(args,"_")
    
    World.gameResults["winner"]  = splitData[1]
    World.gameResults["kills"]          = {splitData[2],tonumber(splitData[3])}
    World.gameResults["deaths"]         = {splitData[4],tonumber(splitData[5])}
    World.gameResults["damage dealt"]   = {splitData[6],tonumber(splitData[7])}
    World.gameResults["damage taken"]   = {splitData[8],tonumber(splitData[9])}

    state[2]  = "end screen"
    lState[2] = nil
    order     = 2
end)

-- ============================================================================================-- 
-- ============================================================================================-- 

-- Handles keyboard inputs for writing text
function love.textinput(t)
    if not editingText then                  return end
    if not (player or mainClient) then       return end
    if t == nil or t == ":" or t == "_" then return end

    -- Adds text at the editing index and incriments the index
    editingText  = string.sub(editingText,1,editingIndex-1)..t..string.sub(editingText,editingIndex,#editingText)
    editingIndex = editingIndex + 1
end

--Scroll the lobbys list with wheel
function love.wheelmoved( dx, dy )
    if state[1] ~= "searching for lobby" then return end
    local scrollSpeed = 100
    lobbyScrollVel = lobbyScrollVel + dy * scrollSpeed
end



local editingTextSwitch = Switch:new()

editingTextSwitch:addCase("escape", function(args)
    local text,index = args[1],args[2]
    state[order]  = nil
    lState[order] = nil
    order         = order - 1
    text          = nil
    index         = 1

    return text,index
end)

editingTextSwitch:addCase("return", function(args)
    local text,index = args[1],args[2]
    if     getState(2) == "editing player name" then changePlayerName()
    elseif getState(2) == "editing message"     then sendMessage()
    elseif getState(4) == "editing lobby name"  then changeLobbyName()
    end
    return editingText,editingIndex
end)

editingTextSwitch:addCase("delete",function(args)
    local text,index = args[1],args[2]
    -- Delete everything after the index when ctrl + delete
    if love.keyboard.isDown("lctrl") or love.keyboard.isDown("rctrl") then
        text  = string.sub(text,1,index-1)

    -- Deletes the text at the editing index
    elseif index <= #text then
        text  = string.sub(text,1,index-1)..string.sub(text,index+1,#text)
    end

    return text,index
end)

editingTextSwitch:addCase("backspace",function(args)
    local text,index = args[1],args[2]
    -- Delete everything before the index when ctrl + backspace
    if love.keyboard.isDown("lctrl") or love.keyboard.isDown("rctrl") then
        text  = string.sub(text,index,#text)
        index = 1

    -- Deletes the text before the editing index and decriments the index
    elseif index > 1 then
        text  = string.sub(text,1,index-2)..string.sub(text,index,#text)
        index = index - 1
    end
    return text,index
end)

editingTextSwitch:addCase("left",function(args)
    local text,index = args[1],args[2]
    if index > 1 then 
        index = index - 1
    end
    return text,index
end)

editingTextSwitch:addCase("right",function(args)
    local text,index = args[1],args[2]
    if index < #text + 1 then
        index = index + 1
    end
    return text,index
end)

-- Handle keyboard inputs
function love.keypressed(key)
    if order == 1 and state[1] == "hosting lobby" then
        if key == "left" then maps:prev() end
        if key == "right" then maps:next() end
    end
    if editingText and (player or mainClient) and editingTextSwitch:isCase(key) then
        --update the editing text and index corresponding to the given "special" input (e.g. backspace, left/right arrow)
        editingText,editingIndex = editingTextSwitch:case(key,{editingText,editingIndex})
    elseif key == "escape" then
        -- If in an offline state
        if not inLobby() and state[1] ~= "end screen" then
            -- If in a menu, esc closes that menu
            if order > 1   then
                state[order]  = nil
                lState[order] = nil
                order         = order - 1

            -- If not in a menu, esc opens options
            else
                order         = 2
                lState[2]     = nil
                state[2]      = "user settings"
            end
        -- If in and online state
        else
            if order > 1 then
                state[order]  = nil
                lState[order] = nil
                order         = order - 1
            else
                order         = 2
                lState[2]     = nil
                state[2]      = "lobby pause screen"
            end
        end
    elseif key == "t" and inLobby() and state[2] ~= "end screen" then
        lState[2] = nil
        state[2]  = "editing message"
        order     = 2
    end
end

function love.quit()
    -- return true to prevent quitting?
    return not offline()
end

function love.load()
    love.keyboard.setKeyRepeat(true)
end

-- Process each frame
function love.update(dt)

    if state[order] == nil then
        order = 1
    end

    updateButtons()
    updateScroll(dt)
    -- Loop through all state changes this frame
    local nState = getNewState()
    while nState do
        newStateSwitch:case(nState)
        nState   = getNewState()
    end

    for i = 1,maxOrder do
        stateSwitch:case(getState(i),dt)
    end

    if toClosePlayer   then
        player          = nil
        toClosePlayer   = false
    end

    if toConnectPlayer then
        player          = toConnectPlayer
        toConnectPlayer = nil
        print("player: ",player)
    end

    if toConnectMain and player and tempTick == 1 then
        player:close()
        player:connectToMain()
        state[1]        = "searching for lobby"
        toConnectMain   = false
    end

    -- Allows for delays in changing state
    if toChangeState and tempTick == 1 then
        lState[1]     = nil
        state[1]      = toChangeState
        state[2]      = nil
        state[3]      = nil
        toChangeState = nil
        order         = 1
    end

    while toRemoveIDs:getVal() do
        local ID = toRemoveIDs:pop()
        print("RemovingID: "..ID)
        LobbyPlayer:removeID(ID)
    end

    tick = tick + 1
    if tempTick > 0    then tempTick = tempTick - 1 end
end

-- Draw each frame
function love.draw()
    for i = 1,maxOrder do
        drawStateSwitch:case(getState(i))
    end
end

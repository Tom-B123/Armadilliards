require("lists")

local trackingKeys = {}
local trackingDict = {}

local resolution = 60

local track = {}

function track:new(event)
    table.insert(trackingKeys,event)
    trackingDict[event] = List:new()
end

local function updateEvent(list)
    list:append(Socket.gettime())
    if list.length > resolution then list:pop() end
end

function track:startEvent(event)
    local list = trackingDict[event]
    list:enqueue(Socket.gettime*10000)
end

function track:endEvent(event)
    local list = trackingDict[event]
    
end

track:updateTime()

return track
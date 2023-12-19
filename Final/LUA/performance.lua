require("lists")

local trackingDict = {}

local resolution = 60

local track = {}

function track:new(event)
    trackingDict[event] = List:new()
end

local function getTime()
    return Socket.gettime()*10000
end

function track:start(event)
    local list = trackingDict[event]
    list:enqueue(getTime())
end

function track:finish(event)
    local list = trackingDict[event]
    local lastTime = list:getVal()
    local deltaTime = getTime() - lastTime
    list:setVal(deltaTime)
    return deltaTime
end

track:new("event1")
track:new("event2")
track:start("event1")
local b = 0
for i = 1,100000 do b = b + i^0.5 end
print(b)
track:start("event2")
b = 0
for i = 1,1000000 do b = b + i^0.5 end
print(b)
print("time 1: "..track:finish("event1"))
print("time 2: "..track:finish("event2"))

return track
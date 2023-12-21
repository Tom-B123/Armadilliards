require("lists")

local trackingDict = {}

local resolution = 60

local track = {}

function track:new(event)
    trackingDict[event] = List:new()
end

local function getTime()
    return Socket.gettime()*1000
end

function track:start(event)
    local list = trackingDict[event]
    list:enqueue(getTime())
    if list.length == resolution then list:dequeue() end
end

function track:finish(event)
    local list = trackingDict[event]
    local lastTime = list:getVal()
    local deltaTime = getTime() - lastTime
    list:setVal(deltaTime)
    return deltaTime
end

function track:getTime(event)
    local sum = 0
    local list = trackingDict[event]
    for i, time in list:iterator() do
        sum = sum + time
    end
    return sum / list.length
end

return track
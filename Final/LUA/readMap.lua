require("solver")
require("switch")
require("util")

local readMap = {}

function readMap:get()
    local files = love.filesystem.getDirectoryItems("Maps")
    local ind = 0
    return function()
        if ind <= #files then
            ind = ind + 1
            return files[ind]
        end
    end
end

local processSwitch = Switch:new()

--Neutral ball
processSwitch:addCase(0,function(args)
    local x = args[1]
    local y = args[2]
    World:newBall(x,y,false)
end)

--Player controlled ball
processSwitch:addCase(1,function(args)
    local x = args[1]
    local y = args[2]
    World:newBall(x,y,true)
end)

--Square object
processSwitch:addCase(2,function(args)
    local x      = args[1]
    local y      = args[2]
    local length = args[3]
    World:square(x,y,length)
end)

--Hole object
processSwitch:addCase(3,function(args)
    local x      = args[1]
    local y      = args[2]
    World:newHole(x,y)
end)

local function process(object,args)
    processSwitch:case(object,args)
end

--Opens the file, processes each line, then closes it
function readMap:open(filename)
    local file = love.filesystem.lines("Maps/"..filename)
    if not file then
        print("invalid spanner name")
        return nil
    end
    for line in file do
        local splitData = Util:split(line,":")
        local object    = tonumber(splitData[1])
        local pos       = splitData[2]
        local objData   = Util:split(pos,",")
        local args = {}
        for i,arg in ipairs(objData) do
            table.insert(args,tonumber(arg))
        end
        process(object,args)
    end
end

return readMap
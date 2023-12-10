require("solver")
require("switch")
require("util")

local readMap = {}

-- --Get the path of this file, src: https://forum.cockos.com/showthread.php?s=01b3ea9e105506e782eb48031cb1f382&t=166043 only works outside of love 2d
-- local function getScriptPath()
--     local info = debug.getinfo(1,'S');
--     local script_path = info.source:match[[^@?(.*[\/])[^\/]-$]]
--     return script_path
-- end

-- --Return an iterable of all found files in "Maps" Only works outside of love 2d
-- function readMap:get()
--     local dir = getScriptPath()
--     local files = {}
--     for file in io.popen('dir "'..dir..'\\Maps'..'" /b'):lines() do
--         table.insert(files, file)
--     end
--     local ind = 0
--     return function()
--         ind = ind + 1
--         if files[ind] then
--             return files[ind]
--         end
--     end
-- end

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

for file in readMap:get() do
    print(file)
end

local processSwitch = Switch:new()

--Neutral ball
processSwitch:addCase(0,function(pos)
    World:newBall(pos.x,pos.y,false)
end)

-- --Player controlled ball
processSwitch:addCase(1,function(pos)
    World:newBall(pos.x,pos.y,true)
end)

local function process(object,x,y)
    local pos = {x=x,y=y}
    processSwitch:case(object,pos)
end

--Opens the file, processes each line, then closes it
function readMap:open(filename)
    local file = love.filesystem.lines("Maps/"..filename)
    if not file then
        print("invalid map name")
        return nil
    end
    for line in file do
        local splitData = Util:split(line,":")
        local object    = tonumber(splitData[1])
        local pos       = splitData[2]
        local posData   = Util:split(pos,",")
        local x         = tonumber(posData[1])
        local y         = tonumber(posData[2])
        process(object,x,y)
    end
end

return readMap
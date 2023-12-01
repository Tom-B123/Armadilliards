
Util = {}
--Splits a string by the seperator into a table of substrings
function Util:split (inputstr, sep)
    if sep == nil then
        sep = "%s"
    end
    local t={}
    for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
        table.insert(t, str)
    end
    return t
end

--Returns a psudo-random string of numbers, with set length
function Util:calculateID(length,salt)
    local seed = Socket.gettime() * 10000
    if salt then seed = seed + salt end
    math.randomseed(seed)
    local out = tostring(math.random(0,10^length - 1))
    while #out < length do
        out = "0"..out
    end
    return out
end

function Util:convertToAsc(num)
    if num < 0 then return -1 end
    local out = ""
    repeat
        local char = string.char(num % 256)
        out = char..out
        num = math.floor(num / 256)
    until  num == 0
    return out
end

function Util:convertToNum(asc)
    if #asc > 7 then return -1 end
    local sum = 0
    local mult = 1
    for i = #asc,1,-1 do
        local char = asc:sub(i,i)
        sum = sum + (string.byte(char) * mult)
        mult = mult * 256
    end
    return sum
end

function Util:processGameInputs()
    local x = 0
    local y = 0
    if love.keyboard.isDown("w") then y = y - 1 end
    if love.keyboard.isDown("a") then x = x - 1 end
    if love.keyboard.isDown("s") then y = y + 1 end
    if love.keyboard.isDown("d") then x = x + 1 end
    return x,y
end

function Util:findDistance(x,y)
    return (x*x + y*y)^0.5
end

local toBoolDict = {}

toBoolDict["true"] = true
toBoolDict["false"] = false

--Convert a string or bool into a bool
function Util:toBool(string)
    --If already a bool, return the bool
    if type(string) == "boolean" then return string end
    return toBoolDict[string]
end
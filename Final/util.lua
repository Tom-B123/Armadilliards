
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
    print(self:convertToAsc(tonumber(out)))
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

local vectorTable = {}
vectorTable["w"] = {0,-1}
vectorTable["a"] = {-1,0}
vectorTable["s"] = {0,1}
vectorTable["d"] = {1,0}

function Util:convertToVector(key)
    local vect =  vectorTable[key]
    if not vect then return nil end
    return vect[1],vect[2]
end

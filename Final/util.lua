
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
function Util:calculateID(length)
    local seed = Socket.gettime() * 10000
    math.randomseed(seed)
    return tostring(math.random(0,10^length - 1))
end
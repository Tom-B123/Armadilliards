--Util:

Util        = {}
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

--Number to Hex
local numHex = {}
--Hex to number
local hexNum = {}
local extra = 0
for i = 0,15 do
    if i <= 9 then extra = 48
    else           extra = 55 end
    local char   = string.char(i+extra)
    numHex[i]    = char
    hexNum[char] = i
end

function Util:numToHex(num)
    if num < 0 then return -1 end
    
    local out = ""
    repeat
        local charNum = math.floor(num % 16)
        local char = numHex[charNum]
        out = char..out
        num = math.floor(num / 16)
    until  num == 0
    return out
end

function Util:hexToNum(hex)
    local sum = 0
    local mult = 1
    for i = #hex,1,-1 do
        local char = hex:sub(i,i)
        sum = sum + (hexNum[char] * mult)
        mult = mult * 16
    end
    return sum
end

function Util:numToAsc(num)
    if num < 0 then return -1 end
    local out = ""
    repeat
        local charNum = math.floor(num % 256)
        local char = string.char(charNum)
        if char == "_" then char = string.char(charNum+1) end
        if char == ":" then char = string.char(charNum+1) end
        out = char..out
        num = math.floor(num / 256)
    until  num == 0
    return out
end

function Util:ascToNum(asc)
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

function Util:coordToHex(x,y)
    if x > 4096 then x = 4096 end
    if y > 4096 then y = 4096 end
    if x < 0 then    x = 0 end
    if y < 0 then    y = 0 end
    local hexX = self:numToHex(x*10)
    local hexY = self:numToHex(y*10)
    return hexX,hexY
end

function Util:hexToCoord(hexX,hexY)
    local numX = self:hexToNum(hexX) / 10
    local numY = self:hexToNum(hexY) / 10
    return numX,numY
end

local a = 0
local b = 0

function Util:processGameInputs()
    local x = 0
    local y = 0
    
    --a and b are set to -1 for 1 tick
    if a < 0 then a = 0 end
    if b < 0 then b = 0 end

    if love.keyboard.isDown("w") then y = y - 1 end
    if love.keyboard.isDown("a") then x = x - 1 end
    if love.keyboard.isDown("s") then y = y + 1 end
    if love.keyboard.isDown("d") then x = x + 1 end

    --a and b incriment while they are held, then set to -1 for 1 tick.
    if love.mouse.isDown(1)      then a = a + 1
    elseif a > 0 then a = -1 end
    if love.mouse.isDown(2)      then b = b + 1
    elseif b > 0 then b = -1 end

    return x,y,a,b
end

function Util:findDistance(x,y)
    return (x*x + y*y)^0.5
end

function Util:manhattanDistance(x,y)
    return math.abs(x) + math.abs(y)
end

function Util:pitchAngle(distance,radius)
    local angle = distance / radius
    return angle
end

function Util:yawAngle(x,y)
    local ax,ay = math.abs(x),math.abs(y)
    if x > 0 and y >= 0 then
        return math.atan(ay/ax)
    elseif x <= 0 and y > 0 then
        return math.atan(ax/ay) + math.pi / 2
    elseif x < 0 and y <= 0 then
        return math.atan(ay/ax) + math.pi
    elseif x >= 0 and y < 0 then
        return math.atan(ax/ay) + math.pi * 3 / 2
    end
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

local primesTable = {2}

local function canBePrime(num)
    local mod6 = num % 6
    return num < 6 or mod6 == 1 or mod6 == 5
end

local function expensivePrimeCheck(num)
    if not canBePrime(num) then
        return false
    end
    for check = 2,num-1 do
        if num % check == 0 then
            return false
        end
    end
    return true
end

local function generatePrimes(n)
    local start = primesTable[#primesTable]
    --If n is already generated, return
    if start > n then return end
    

    --Checks the primeness of every number between the largest generated prime
    --and the given number.
    for candidate = start + 1,n do
        if expensivePrimeCheck(candidate) then
            primesTable[#primesTable+1] = candidate
        end
    end
end

function Util:fastPrimeCheck(num)
    if not canBePrime(num) then return false end
    if num > primesTable[#primesTable] then generatePrimes(num) end
    for i,prime in ipairs(primesTable) do
        if num % prime == 0  and prime < num then
            return false
        end
    end
    return true
end

local function getNearPrimes(num)
    if not Util:fastPrimeCheck(num) then
        return getNearPrimes(num+1)
    else
        return num
    end
end
function Util:nearPrime(num)
    return getNearPrimes(num)
end

function Util:hashIDs(IDs,ballCountPrime)
    local sum = 0
    for i,ID in ipairs(IDs) do
        local numID = tonumber(ID)
        sum = sum + (numID * numID)
    end
    --Returns the shortend index, then the true sum, to use in case of collisions
    if sum % ballCountPrime == 0 then return 1,sum end
    return sum % ballCountPrime,sum
end

function Util:fastSqrt(num,steps)
    local tmp = num/2
    for i = 1,steps do
        tmp = tmp - (((tmp*tmp) - num) / (2*tmp))
    end
    return tmp
end

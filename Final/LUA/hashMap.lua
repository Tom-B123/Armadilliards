local hashMap = {}

hashMap.__index = hashMap

function hashMap:new()
    local object = {}
    setmetatable(object,hashMap)
    object.values = {}
    object.keys   = {}
    return object
end

function hashMap:add(hash,value)
    if self:contains(hash,value) then return end
    if not self.values[hash] then
        self.values[hash] = {value}
        print("added "..hash.." to keys.")
        self.keys[#self.keys+1] = hash
        return
    end
    print("hashMap collision")
    self.values[hash][#self.values[hash]+1] = value
end

function hashMap:contains(hash,value)
    local values = self.values[hash]
    if not values then return false end

    for i,tableValue in ipairs(values) do
        if tableValue == value then return true end
    end

    return false
end

function hashMap:remove(hash,value)
    if not self:contains(hash,value) then return end

    local values = self:get(hash)

    local toClear = {}

    for i, foundValue in ipairs(values) do
        if value == foundValue then
            toClear[#toClear+1] = i
        end
    end
    for i,index in ipairs(toClear) do
        print("removed "..value.." from index "..index)
        values[index] = nil
    end
end

function hashMap:get(hash)
    local values = self.values[hash]
    return values
end

function hashMap:pairs()
    local indKey = #self.keys
    local indVal = 0
    local ind    = 0
    local values = {}
    local key    = 0
    return function()
        if indKey > 0 then
            ind = ind + 1
            indVal = indVal - 1
            if indVal <= 0 and indKey > 0 then
                key = self.keys[indKey]
                print("getting values from key index: "..indKey)
                values = self:get(key)
                indVal = 1
                if values then indVal = #values end
                indKey = indKey - 1
            end
            return ind, indKey,indVal,values[indVal]
        end
    end
end

function hashMap:clear()
    for i,key in ipairs(self.keys) do
        print(self.values[key])
        self.values[key] = nil
    end
    self.keys = {}
end

local map = hashMap:new()

map:add(1,10)
map:add(1,20)
map:add(2,10)

for a,b,c,d in map:pairs() do
    -- print(a,b,c,d)
end

return hashMap
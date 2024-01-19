local hashMap = {}

hashMap.__index = hashMap

function hashMap:new()
    local object = {}
    setmetatable(object,hashMap)
    object.values = {}
    object.keys   = {}
    return object
end

function hashMap:add(hash,sum,value)
    if self:contains(hash,value) then return end
    if not self.values[hash] then
        --Stores the true sum to allow individual values to be distinguished
        self.values[hash] = {{value,sum}}
        print("added "..hash.." ("..sum..") to keys.")
        self.keys[#self.keys+1] = hash
        return
    end
    print("hashMap collision")
    self.values[hash][#self.values[hash]+1] = {value,sum}
end

function hashMap:contains(hash,value)
    local values = self.values[hash]
    if not values then return false end

    for i,tableValue in ipairs(values) do
        if tableValue == value then return true end
    end

    return false
end

function hashMap:hasKey(hash)
    if self.values[hash] == nil then return 0 end
    for i, key in ipairs(self.keys) do
        if key == hash then return i end
    end
    return 0
end

function hashMap:remove(hash)
    local ind = self:hasKey(hash)
    --If the hash isn't a key, do nothing
    if ind < 0 then return end

    --Removes the value    
    self.values[hash] = nil

    --Removes the key
    local nKeys = {}
    for i,key in ipairs(self.keys) do
        if i ~= ind then nKeys[#nKeys+1] = key end
    end
    self.keys = nKeys
end

function hashMap:removeBySum(hash,sum)
    if not self:hasKey(hash) then return end

    print("removing "..hash.." ("..sum..")")

    local values = self:get(hash)

    local indVal = 0

    for i, foundValue in ipairs(values) do
        if foundValue then
            if foundValue[2] == sum then
                indVal = i
            end
        end
    end
    
    if indVal == 0 then return end
    
    print("there are "..#values.." values")

    local nValues = {}
    for i,val in ipairs(values) do
        if val then
            if val[2] ~= sum then
                print("adding "..val[2])
                nValues[#nValues+1] = val
            else print("value was at: "..i) end
        end
    end

    if #nValues == 0 then
        nValues = nil
        self:remove(hash)
    end

    values = nValues
end

function hashMap:get(hash)
    local values = self.values[hash]
    return values
end

--Gets returns each key and the corresponding values, as k,v pairs.
--Returns multiple values per key if collisions occur
function hashMap:pairs()
    local indKey = #self.keys + 1
    local indVal = 0
    local ind    = 0
    local values = {}
    local key    = 0
    return function()
        if indKey > 0 then
            ind = ind + 1
            indVal = indVal - 1
            if indVal <= 0 then
                indKey = indKey - 1
                if indKey == 0 then return end
                key = self.keys[indKey]
                values = self:get(key)
                indVal = 1
                if values then indVal = #values end
            end
            local value = values[indVal]
            --Returns key, value, true sum
            return key, value[1],value[2]
        end
    end
end

--Returns the values of a specific key
function hashMap:keyPairs(hashKey)
    local values = self:get(hashKey)
    local ind    = 0
    --return a generator for just one value
    if values == nil then 
        return function()
            if ind == 0 then
                ind = ind + 1
                return nil,nil
            end
        end
    end
    local indVal = #values + 1
    --return a generator for all values
    return function()
        if indVal > 0 then
            indVal = indVal - 1
            ind = ind + 1
            if values[indVal] then
                --Returns the value index, the value and the true sum
                return indVal, values[indVal][1], values[indVal][2]
            end
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

return hashMap
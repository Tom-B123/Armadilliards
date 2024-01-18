local hashMap = {}

hashMap.__index = hashMap

function hashMap:new()
    local object = {}
    setmetatable(object,hashMap)
    object.table = {}
    
    return object
end

function hashMap:add(hash,value)
    if hashMap:contains(hash,value) then return end
    if not self.table[hash] then
        self.table[hash] = {value}
        return
    end
    print("hashMap collisions")
    self.table[hash.value][#self.table[hash.value]+1] = value
end

function hashMap:contains(hash,value)
    if not self.table then print("table not exisitng"); return end
    local values = self.table[hash]
    if not values then return false end

    for i,tableValue in ipairs(values) do
        if tableValue == value then return true end
    end

    return false
end

function hashMap:get(hash)
    local values = self.table[hash]
    return values
end

local map = hashMap:new()

map:add(1,2)

return hashMap
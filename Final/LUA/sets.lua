Set = {}
Set.__index = Set

function Set:new()
    local object = {}
    setmetatable(object,Set)
    object.dict = {}
    return object
end

function Set:add(value)
    self.dict[value] = true
end

function Set:remove(value)
    self.dict[value] = nil
end

function Set:has(value)
    return self.dict[value]
end

function Set:clear()
    self.dict = {}
end

function Set:pairs()
    return pairs(self.dict)
end
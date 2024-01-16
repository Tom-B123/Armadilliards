--Sets

Set = {}
Set.__index = Set

function Set:new()
    local object = {}
    setmetatable(object,Set)
    object.dict   = {}
    object.length = 0
    return object
end

function Set:add(value)
    if not self:has(value) then
        self.dict[value] = true
        self.length = self.length + 1
    end
end

function Set:remove(value)
    if self:has(value) then
        self.dict[value] = nil
        self.length = self.length - 1
    end
end

function Set:has(value)
    return self.dict[value]
end

function Set:clear()
    self.dict   = {}
    self.length = 0
end

function Set:pairs()
    return pairs(self.dict)
end
Switch = {}
Switch.__index = Switch

function Switch:new()
    local object = {}
    setmetatable(object,Switch)
    object.cases = {}
    return object
end

function Switch:addCase(value,result)
    self.cases[value] = result
end

function Switch:isCase(value)
    return self.cases[value]
end

function Switch:case(value)
    if self.cases[value] then
        self.cases[value]()
    end
end

return Switch
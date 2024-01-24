--Switch:

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

function Switch:case(value,args)
    if not self:isCase(value) then
        return nil
    end
    return self.cases[value](args)
end

return Switch
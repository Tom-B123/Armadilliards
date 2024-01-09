require("lists")

local objectiveDict = {}

local objective = {}

function objective:new(event)
    objectiveDict[event] = List:new()
end


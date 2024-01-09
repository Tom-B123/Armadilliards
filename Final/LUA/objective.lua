require("lists")
require("util")

--Converts the objective name into an ID
local objectiveDict = {}

local teamDict      = {}
for i = 1,8 do
    teamDict["team "..i] = {}
end

local objective     = {}

--Create a new objective ID from the event name
function objective:new(event,salt)
    objectiveDict[event] = Util:calculateID(5,salt)
end

--Get the objective ID
function objective:getID(event)
    return objectiveDict[event]
end

--Get the score corresponding to the team and event
function objective:getScore(event,team)
    local ID = self:getID(event)
    local scores = teamDict[team]
    if scores[event] then
        return scores[event]
    end
end

--Sets the score corresponding to the team and event
function objective:setScore(event,team,nScore)
    local ID = self:getID(event)
    local scores = teamDict[team]
    scores[event] = nScore
end

--Adds an amount to the current score for that team
function objective:addScore(event,team,amount)
    local cScore = self:getScore(event,team)
    self:setScore(cScore + amount)
end

return objective
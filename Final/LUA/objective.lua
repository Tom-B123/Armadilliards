require("lists")

--Holds multiple teams, each of which holds a dictionary of events and scores
local teamDict      = {}
for i = 1,8 do
    teamDict["team "..i] = {}
end

--Holds the functions for creating and using objectives
local objective     = {}

--Create a new objective for all teams, setting their score to 0
function objective:new(event)
    for team,v in pairs(teamDict) do
        local scores = teamDict[team]
        scores[event] = 0
    end
end

--Get the score corresponding to the team and event
function objective:getScore(event,team)
    local scores = teamDict[team]
    if scores[event] then
        return scores[event]
    end
end

--Sets the score corresponding to the team and event
function objective:setScore(event,team,nScore)
    local scores = teamDict[team]
    scores[event] = nScore
end

--Adds an amount to the current score for that team
function objective:addScore(event,team,amount)
    local cScore = self:getScore(event,team)
    self:setScore(cScore + amount)
end

return objective
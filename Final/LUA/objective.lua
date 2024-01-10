require("lists")

--Holds multiple teams, each of which holds a dictionary of events and scores
local teamDict      = {}
for i = 1,8 do
    teamDict["team "..i] = {}
end

--Holds the functions for creating and using objectives
Objective     = {}

--Create a new objective for all teams, setting their score to 0
function Objective:new(event)
    for team,v in pairs(teamDict) do
        teamDict[team][event] = 0
    end
end

--Get the score corresponding to the team and event
function Objective:getScore(event,team)
    local scores = teamDict[team]
    if scores[event] then
        return scores[event]
    end
end

--Sets the score corresponding to the team and event
function Objective:setScore(event,team,nScore)
    teamDict[team][event] = nScore
end

--Adds an amount to the current score for that team
function Objective:addScore(event,team,amount)
    local cScore = self:getScore(event,team)
    self:setScore(event,team,cScore + amount)
end

return Objective
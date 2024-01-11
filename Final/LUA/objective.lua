require("lists")

--Holds multiple teams, each of which holds a dictionary of events and scores
local teamDict  = {}
for i = 1,8 do
    teamDict["team "..i] = {}
end

--Holds the event and score for the victory condition
local goal      = {"kills",5}

--Holds the functions for creating and using objectives
local objective = {}

--Create a new objective for all teams, setting their score to 0
function objective:new(event)
    for team,v in pairs(teamDict) do
        teamDict[team][event] = 0
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
    teamDict[team][event] = nScore
end

--Adds an amount to the current score for that team
function objective:addScore(event,team,amount)
    local cScore = self:getScore(event,team)
    self:setScore(event,team,cScore + amount)

    if self:atGoal(event,team) then
        return true
    end
end

function objective:resetScores()
    for team,scores in pairs(teamDict) do
        for event,score in pairs(scores) do
            teamDict[team][event] = 0
        end
    end
end

--Sets the victory condition
function objective:setGoal(event,amount)
    goal = {event,amount}
end

--Returns the current victory condition as a string
function objective:getGoal()
    return {goal[2],goal[1]}
end


function objective:atGoal(event,team)
    if event == goal[1] and self:getScore(event,team) >= goal[2] then
        return true
    end
end

return objective
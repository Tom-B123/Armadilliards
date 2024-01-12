require("lists")
require("sets")
--Holds multiple teams, each of which holds a dictionary of events and scores
local teamDict  = {}
for i = 1,8 do
    teamDict["team "..i] = {}
end

local activeTeams = Set:new()

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
    if not activeTeams:has(team) then return end

    local scores = teamDict[team]
    if scores[event] then
        return scores[event]
    end
end

--Returns an iterator to get all teams scores in an event, used for drawing victory progress
function objective:getAllScores(event)
    local teams = {}
    for team,v in activeTeams:pairs() do
        teams[#teams+1] = team
    end

    local ind = 1
    return function()
        if ind <= #teams then
            local team = teams[ind]
            ind = ind + 1
            return ind,team,teamDict[team][event]
        end
    end
end

--Sets the score corresponding to the team and event
function objective:setScore(event,team,nScore)
    if not activeTeams:has(team) then return end

    teamDict[team][event] = nScore
end

--Adds an amount to the current score for that team
function objective:addScore(event,team,amount)
    if not activeTeams:has(team) then return end

    local cScore = self:getScore(event,team)
    self:setScore(event,team,cScore + amount)

    if self:atGoal(event,team) then
        return true
    end
end

--Resets all team's scores to 0
function objective:resetScores()
    for team,scores in pairs(teamDict) do
        for event,score in pairs(scores) do
            teamDict[team][event] = 0
        end
    end
    activeTeams:clear()
end

--Sets the victory condition
function objective:setGoal(event,amount)
    goal = {event,amount}
end

--Returns the current victory condition as a string
function objective:getGoal()
    return {goal[2],goal[1]}
end

--Returns true if the team has reached the victory / loss condition
function objective:atGoal(event,team)
    if not activeTeams:has(team) then return end

    if event == goal[1] and self:getScore(event,team) >= goal[2] then
        return true
    end
end

--Changes the set of all teams that are active in the current game.
function objective:setActiveTeams(nActiveTeams)
    activeTeams = nActiveTeams
end

return objective
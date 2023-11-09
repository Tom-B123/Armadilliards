local routines = {}
local grids = {}
for i = 1,9 do
    grids[i] = {}
    for j = 1,2^i do
        grids[i][j] = {}
        for k = 1,2^i do
            grids[i][j][k] = 0
        end
    end
end

local function recSearch(level,lx,ly)
    lx = lx - 1
    ly = ly - 1
    local x = 2^(lx * level) - 1
    local y = 2^(ly * level) - 1
    print("level: "..level.." x: "..x.." y:"..y)
end

for i = 1,9 do
    recSearch(i,1,1)
    recSearch(i,1,2)
    recSearch(i,2,1)
    recSearch(i,2,2)
end

local function updateRoutines()
    for i,co in ipairs(routines) do
        if not coroutine.resume(co) then
            table.remove(routines,i)
        end
    end
end

while 1 do
    updateRoutines()
end
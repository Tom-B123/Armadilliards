local routines = {}
local grids = {}
for i = 1,9 do
    grids[i] = {}
    for j = 1,2^i do
        grids[i][j] = {}
        for k = 1,2^i do
            grids[i][j][k] = k
        end
    end
end

local steps = 9
local found = 0
local checks = 0
local function findOccupiedCells(step, x, y)
    checks = checks + 1
    if step == steps + 1 then
        found = found + 1
    else
        --check the internal cells of the previously occupied cells
        for subX = 0, 1 do
            for subY = 0, 1 do
                local nX = ((2 * x) - 1) + subX
                local nY = ((2 * y) - 1) + subY
                if grids[step][nY][nX] > 0 then findOccupiedCells(step + 1, nX, nY) end
            end
        end
    end
end
print("start")
findOccupiedCells(1,1,1)
print("found: "..found.." possible: "..(512*512).." checked: "..checks)
print("end")
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
Grid = {}

Grid.__index = Grid

function Grid:new(size,resolution)
    local object = {}
    setmetatable(object,Grid)
    --maximum bounds of the world
    object.size = size
    --diameter of balls
    object.resolution = resolution
    --number of grid levels
    object.levels = math.floor(math.log((size / resolution),2)) + 1

    object.grid = {}

    local maxLength = 2^(object.levels + 1) - 1
    for x = 1,maxLength do
        object.grid[x] = {}
    end
    return object
end

function Grid:lookup(x,y,level)
    local nx = x + 2^(level-1) - 1
    local ny = y
    if y > 2^(level-1) or x > 2^(level-1) or level > self.levels then
        return "invalid position"
    end
    return self.grid[nx][ny]
end

function Grid:store(x,y,level,val)
    local nx = x + 2^(level-1) - 1
    local ny = y
    if y > 2^(level-1) or x > 2^(level-1) or level > self.levels then
        return "invalid position"
    end
    self.grid[nx][ny] = val
end

function Grid:search()
    local out = {}
    local function recSearch(x,y,level)
        --grid x and y
        local gx = 2 * x - 1
        local gy = 2 * y - 1
        print("level: "..level.." x: "..x.." y: "..y)
        if self:lookup(x,y,level) == nil then
            return
        end
        if level >= self.levels then
            return
        end
        for lx = 0,1 do
            for ly = 0,1 do
                recSearch(gx + lx, gy + ly, level + 1)
            end
        end
    end
    recSearch(1,1,1)
end

local grid = Grid:new(2048,512)
grid:search()
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

    for level = 1,object.levels do
        local extraX = 2^(level-1)-1
        for x = 1,2^(level-1) do
            object.grid[x + extraX] = {}
            for y = 1,2^(level-1) do
                if level == object.levels then
                    object.grid[x + extraX][y] = {}
                else
                    object.grid[x + extraX][y] = 0
                end
            end
        end
    end
    return object
end

function Grid:reset()
    for level = 1,self.levels do
        local extraX = 2^(level-1)-1
        for x = 1,2^(level-1) do
            self.grid[x + extraX] = {}
            for y = 1,2^(level-1) do
                if level == self.levels then
                    self.grid[x + extraX][y] = {}
                else
                    self.grid[x + extraX][y] = 0
                end
            end
        end
    end
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
        --If the searched cell is empty, it has no children so can't contain a ball, so return
        if self:lookup(x,y,level) == 0 then
            return
        end
        --Terminate search at the finest detail.
        if level >= self.levels then
            local found = self:lookup(x,y,level)
            if type(found) == "table" then
                for i, ID in ipairs(found) do
                    table.insert(out,{x,y,ID})
                end
            end
            return
        end
        --grid x and y
        local gx = 2 * x - 1
        local gy = 2 * y - 1
        
        for lx = 0,1 do
            for ly = 0,1 do
                recSearch(gx + lx, gy + ly, level + 1)
            end
        end
    end
    recSearch(1,1,1)
    return out
end

function Grid:populate(x,y,id)
    if x < 0 or x > self.size or y < 0 or y > self.size then
        return "invalid position"
    end
    for level = 1,self.levels do
        local cells = 2^(level-1)
        local div = self.size / cells
        local nx = math.floor(x / div) + 1
        local ny = math.floor(y / div) + 1
        local val
        if level < self.levels then
            val = self:lookup(nx,ny,level) + 1
        else
            val = self:lookup(nx,ny,level)
            if type(val) == "table" then
                table.insert(val,id)
            end
        end
        self:store(nx,ny,level,val)
    end
end
require("switch")

Button = {}

Button.__index = Button

--Create a new button object
function Button:new(text,font,x1,y1,x2,y2,command,params)
    local object          = {}
    setmetatable(object,Button)
    object.defValues      = {
        textColour        = {1,1,1},
        outlineColour     = {0,0,0},
        fillColour        = {0,0,0},
        text              = text,
        font              = font,
        x1                = x1,
        y1                = y1,
        x2                = x2,
        y2                = y2,
        scale             = 0
    }
    object.textColour     = {1,1,1}
    object.outlineColour  = {0,0,0}
    object.fillColour     = {0,0,0}
    object.scale          = 0
    object.targValues     = {
        textColour        = {0,0,0},
        outlineColour     = {0,0,0},
        fillColour        = {0,0,0},
        scale             = 0
    }
    object.text           = text
    object.font           = font
    object.x1             = x1
    object.y1             = y1
    object.x2             = x2
    object.y2             = y2
    object.command        = command
    object.onHover        = nil
    object.hoverTime      = 0
    object.onClick        = nil
    object.params         = params
    object.mouseState     = false

    --Total time to transition from not hovered to hovered
    object.transitionTime = 5
    --Current frame of the transition
    object.transitionTick = 0
    --Direction, pos, zero or neg
    object.transitionDir  = 0

    object:loadPresets()
    object:preset("basic")
    return object
end

function Button:updateStats()
    if self.transitionDir == 0 then return end
    if self.transitionDir < 0 and self.transitionTick < 0 then
        self.transitionDir  = 0
        self.transitionTick = 0
        return
    end
    if self.transitionDir > 0 and self.transitionTick > self.transitionTime then
        self.transitionDir  = 0
        self.transitionTick = self.transitionTime
        return
    end

    local dTColour = {}
    local dOColour = {}
    local dFColour = {}
    local dScale   = (self.targValues.scale - self.defValues.scale) / self.transitionTime
    --Delta values for transitioning values (change per tick)
    for i = 1,3 do
        dTColour[i] = (self.targValues.textColour[i]    - self.defValues.textColour[i])    / self.transitionTime
        dOColour[i] = (self.targValues.outlineColour[i] - self.defValues.outlineColour[i]) / self.transitionTime
        dFColour[i] = (self.targValues.fillColour[i]    - self.defValues.fillColour[i])    / self.transitionTime
         

        self.textColour[i]     = self.defValues.textColour[i] + (dTColour[i] * self.transitionTick)
        self.outlineColour[i]  = self.defValues.outlineColour[i] + (dOColour[i] * self.transitionTick)
        self.fillColour[i]     = self.defValues.fillColour[i] + (dFColour[i] * self.transitionTick)
    end

    self.scale          = self.defValues.scale + dScale   * self.transitionTick

    self.transitionTick = self.transitionTick + self.transitionDir
end

local presetSwitch = Switch:new()
--Defines all presets
function Button:loadPresets()
    presetSwitch:addCase("basic",function()
        self.defValues.fillColour    = {0,0,0}
        self.defValues.outlineColour = {1,1,1}
        self.defValues.textColour    = {1,1,1}

        self.fillColour    = {0,0,0}
        self.outlineColour = {1,1,1}
        self.textColour    = {1,1,1}
        
        self.defValues.scale         = 0
        self.onHover = function()
            self.transitionDir = 1
        end
        self.targValues        = {
            fillColour         = {1,1,1},
            outlineColour      = {1,1,1},
            textColour         = {0,0,0},
            scale              = 4
        }
    end)

    presetSwitch:addCase("text editing",function()
        self.defValues.fillColour    = {0.1,0.1,0.1}
        self.defValues.outlineColour = {1,1,1}
        self.defValues.textColour    = {0,0,0}

        self.fillColour    = {0.1,0.1,0.1}
        self.outlineColour = {1,1,1}
        self.textColour    = {0,0,0}

        self.defValues.scale         = 0
        self.onHover = function()
            self.transitionDir = 1
        end
        self.targValues        = {
            fillColour         = {0.2,0.2,0.2},
            outlineColour      = {1,1,1},
            textColour         = {0,0,0},
            scale              = 4
        }
    end)

    presetSwitch:addCase("confirm",function()
        self.defValues.fillColour    = {0,0,0}
        self.defValues.outlineColour = {0,1,0}
        self.defValues.textColour    = {0,1,0}

        self.fillColour    = {0,0,0}
        self.outlineColour = {0,1,0}
        self.textColour    = {0,1,0}

        self.defValues.scale         = 0
        self.onHover = function()
            self.transitionDir = 1
        end
        self.targValues        = {
            fillColour         = {0,1,0},
            outlineColour      = {0,0,0},
            textColour         = {0,0,0},
            scale              = 2
        }
    end)

    presetSwitch:addCase("cancel",function()
        self.defValues.fillColour    = {0,0,0}
        self.defValues.outlineColour = {1,0,0}
        self.defValues.textColour    = {1,0,0}

        self.fillColour    = {0,0,0}
        self.outlineColour = {1,0,0}
        self.textColour    = {1,0,0}

        self.defValues.scale         = 0
        self.onHover = function()
            self.transitionDir = 1
        end
        self.targValues        = {
            fillColour         = {1,0,0},
            outlineColour      = {0,0,0},
            textColour         = {0,0,0},
            scale              = 2
        }
    end)
end

--Applies a preset to a button
function Button:preset(preset)
    if not presetSwitch:isCase(preset) then return end
    presetSwitch:case(preset)
end

--Restores the default button graphics (when not hovered or clicked)
function Button:restoreDefaults()
    self.text          = self.defValues.text
    self.textColour    = self.defValues.textColour
    self.outlineColour = self.defValues.outlineColour
    self.fillColour    = self.defValues.fillColour
    self.font          = self.defValues.font
    self.x1            = self.defValues.x1
    self.y1            = self.defValues.y1
    self.x2            = self.defValues.x2
    self.y2            = self.defValues.y2
    self.scale         = self.defValues.scale
end

function Button:setCoords(x1,y1,x2,y2)
    self.x1 = x1
    self.y1 = y1
    self.x2 = x2
    self.y2 = y2
end

function Button:setText(text)
    self.text = text
end

--Execute the command stored by the button
function Button:execute()
    return self.command(self.params)
end

--Returns true if the mouse is over the button
function Button:isHovered()
    local x,y = love.mouse.getPosition()
    return  x >= self.x1 and
            x <= self.x2 and
            y >= self.y1 and
            y <= self.y2
end

--Returns true only when the mouse is released
function Button:getClick()
    return not love.mouse.isDown(1) and self.mouseState
end

--Checks for hover and click events
function Button:update()
    self:updateStats()
    if self:isHovered() and self.onHover then
        self.onHover()
        self.hoverTime = self.hoverTime + 1
    elseif not self:isHovered() and self.hoverTime > 0 then
        self.transitionDir = -1
        self.hoverTime = 0
    end
    if self:isHovered() and self:getClick() then
        if self.onClick then self.onClick() end
        self:execute()
    end
    self.mouseState = love.mouse.isDown(1)
end

--Draws buttons using their outline, fill and text colours
function Button:draw()

    love.graphics.setColor(self.fillColour)
    love.graphics.rectangle(
        "fill",
        self.x1-self.scale,
        self.y1-self.scale,
        self.x2-self.x1+self.scale*2,
        self.y2-self.y1+self.scale*2
    )

    love.graphics.setColor(self.outlineColour)
    love.graphics.rectangle(
        "line",
        self.x1-self.scale,
        self.y1-self.scale,
        self.x2-self.x1+self.scale*2,
        self.y2-self.y1+self.scale*2
    )

    love.graphics.setColor(self.textColour)
    for i = 1,4 do
        love.graphics.print(self.text,self.x1,self.y1)
    end
end

return Button
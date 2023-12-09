require("switch")

Button = {}

Button.__index = Button

--Create a new button object
function Button:new(text,font,x1,y1,x2,y2,command,params)
    local object      = {}
    setmetatable(object,Button)
    object.defValues  = {
        textColour    = {1,1,1},
        outlineColour = {1,1,1},
        fillColour    = {1,1,1},
        text          = text,
        font          = font,
        x1            = x1,
        y1            = y1,
        x2            = x2,
        y2            = y2,
        scale         = 0
    }
    object.textColour    = {1,1,1}
    object.outlineColour = {1,1,1}
    object.fillColour    = {1,1,1}
    object.scale      = 0
    object.text       = text
    object.font       = font
    object.x1         = x1
    object.y1         = y1
    object.x2         = x2
    object.y2         = y2
    object.command    = command
    object.onHover    = nil
    object.hoverTime  = 0
    object.onClick    = nil
    object.params     = params
    object.mouseState = false
    object:loadPresets()
    object:preset("basic")
    return object
end

local presetSwitch = Switch:new()
--Defines all presets
function Button:loadPresets()
    presetSwitch:addCase("basic",function()
        self:setFillColour({0,0,0,0})
        self.onHover = function()
            self.fillColour = {1,1,1}
            self.textColour = {0,0,0}
            self.scale = 4
        end
    end)
    presetSwitch:addCase("text editing",function()
        self:setFillColour({0.1,0.1,0.1})
        self.onHover = function()
            self.fillColour = {0.2,0.2,0.2}
            self.scale = 2
        end
    end)
    presetSwitch:addCase("confirm",function()
        self:setFillColour(   {0,0,0,0})
        self:setOutlineColour({0,1,0})
        self:setTextColour(   {0,1,0})
        self.onHover = function()
            self.fillColour = {0,1,0}
            self.textColour = {0,0,0}
            self.scale = 2
        end
    end)
    presetSwitch:addCase("cancel",function()
        self:setFillColour(   {0,0,0,0})
        self:setOutlineColour({1,0,0})
        self:setTextColour(   {1,0,0})
        self.onHover = function()
            self.fillColour = {1,0,0}
            self.textColour = {0,0,0}
            self.scale = 2
        end
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

function Button:setOutlineColour(colour)
    self.outlineColour = colour
    self.defValues.outlineColour = colour
end

function Button:setFillColour(colour)
    self.fillColour = colour
    self.defValues.fillColour = colour
end

function Button:setTextColour(colour)
    self.textColour = colour
    self.defValues.textColour = colour
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
    if self:isHovered() and self.onHover then
        self.onHover()
        self.hoverTime = self.hoverTime + 1
    elseif not self:isHovered() and self.hoverTime > 0 then
        self:restoreDefaults()
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
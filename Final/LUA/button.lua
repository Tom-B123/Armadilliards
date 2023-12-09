Button = {}

Button.__index = Button

--Create a new button object
function Button:new(text,colour,font,x1,y1,x2,y2,command,params)
    local object      = {}
    setmetatable(object,Button)
    object.defValues  = {
        textColour    = colour,
        outlineColour = colour,
        fillColour    = colour,
        text          = text,
        font          = font,
        x1            = x1,
        y1            = y1,
        x2            = x2,
        y2            = y2,
        scale         = 0
    }
    object.textColour    = colour
    object.outlineColour = colour
    object.fillColour    = colour
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
    return object
end

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
    print("colour to",colour)
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

--Update function, called every frame.
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
        "fill",
        self.x1-self.scale,
        self.y1-self.scale,
        self.x2-self.x1+self.scale*2,
        self.y2-self.y1+self.scale*2
    )

    love.graphics.setColor(self.textColour)
    love.graphics.print(self.text,self.x1,self.y1)
end

return Button
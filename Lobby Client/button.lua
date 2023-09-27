Button = {}

Button.__index = Button

--Create a new button object
function Button:new(text,x1,y1,x2,y2,command,params)
    local object = {}
    setmetatable(object,Button)
    object.colour = {0,0,0}
    object.text = text
    object.x1 = x1
    object.y1 = y1
    object.x2 = x2
    object.y2 = y2
    object.command = command
    object.params = params
    object.mouseState = false
    return object
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

    if self:isHovered() and self:getClick() then
        self:execute()
    end
    self.mouseState = love.mouse.isDown(1)
end
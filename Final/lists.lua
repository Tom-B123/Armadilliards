--Creates a new node object
local function newNode(val)
    return {val = val, next = nil, prev = nil}
end

List = {}

List.__index = List

--Creates a new list object
function List:new()
    local object = {}
    setmetatable(object,List)
    object.head = nil
    object.length = 0
    return object
end

--Returns the current head value
function List:getVal()
    if self.head then
        return self.head.val
    end
    return nil
end

--Returns the length of the list
function List:getLength()
    return self.length
end

--Moves the head forwards one place
function List:next()
    if self.head then
        self.head = self.head.next
        return self
    end
    return false
end

--Moves the head back one place
function List:prev()
    if self.head then
        self.head = self.head.prev
        return self
    end
    return false
end

--Adds a new value to the head of the list
function List:push(val)
    if self.length == 0 then
        self.head = newNode(val)
        self.head.next = self.head
        self.head.prev = self.head
    elseif self.length == 1 then
        local nNode = newNode(val)
        nNode.next = self.head
        nNode.prev = self.head
        self.head.next = nNode
        self.head.prev = nNode
        self.head = nNode
    elseif self.length >= 2 then
        local nNode = newNode(val)
        nNode.next = self.head
        nNode.prev = self.head.prev
        self.head.prev.next = nNode
        self.head.prev = nNode
        self.head = nNode
    end
    self.length = self.length + 1
end

--Removes and returns the head value of the list
function List:pop()
    local val
    if self.length <= 0 then
        return nil
    elseif self.length == 1 then
        val = self.head.val
        self.head = nil
    elseif self.length >= 2 then
        val = self.head.val
        self.head.prev.next = self.head.next
        self.head.next.prev = self.head.prev
        self.head = self.head.next
    end
    self.length = self.length - 1
    return val
end

--Adds a new value to the head of the list
function List:enqueue(val)
    self:push(val)
end

--Removes and returns the end value of the list
function List:dequeue()
    local val
    if self.length <= 0 then
        return nil
    elseif self.length == 1 then
        val = self.head.val
        self.head = nil
    elseif self.length >= 2 then
        val = self.head.prev.val
        self.head.prev.prev.next = self.head
        self.head.prev = self.head.prev.prev
    end
    self.length = self.length - 1
    return val
end

--Adds a value to the end of the list
function List:append(val)
    if self.length == 0 then
        self.head = newNode(val)
        self.head.next = self.head
        self.head.prev = self.head
    elseif self.length == 1 then
        local nNode = newNode(val)
        nNode.next = self.head
        nNode.prev = self.head
        self.head.next = nNode
        self.head.prev = nNode
    elseif self.length >= 2 then
        local nNode = newNode(val)
        nNode.next = self.head
        nNode.prev = self.head.prev
        self.head.prev.next = nNode
        self.head.prev = nNode
    end
    self.length = self.length + 1
end

--Returns an iterator function to read the Linked List closer to an array
function List:iterator()
    local current = self.head
    local firstIteration = true
    return function ()
        if current then
            local val = current.val
            current = current.next
            if current == self.head and not firstIteration then
                current = nil
            end
            firstIteration = false
            return val
        end
    end
end

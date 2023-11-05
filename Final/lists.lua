Node = {}

Node.__index = Node

function Node:new(val,next,prev)
    local object = {}
    setmetatable(object,Node)
    object.val = val
    object.next = next
    object.prev = prev
    return object
end

function Node:add(head,val)
    self.next = self:new(val,head,self)
    head.prev = self.next
    return head
end

List = {}

List.__index = List

function List:new()
    local object = {}
    setmetatable(object,List)
    object.head = nil
    object.length = 0
    return object
end

function List:getVal()
    if self.head then
        return self.head.val
    end
    return nil
end

function List:getLength()
    return self.length
end

function List:next()
    if self.head then
        self.head = self.head.next
        return self
    end
    return false
end

function List:prev()
    if self.head then
        self.head = self.head.prev
        return self
    end
    return false
end

function List:push(val)
    if self.length == 0 then
        self.head = Node:new(val)
        self.head.next = self.head
        self.head.prev = self.head
    elseif self.length == 1 then
        local nNode = Node:new(val)
        nNode.next = self.head
        nNode.prev = self.head
        self.head.next = nNode
        self.head.prev = nNode
        self.head = nNode
    elseif self.length >= 2 then
        local nNode = Node:new(val)
        nNode.next = self.head
        nNode.prev = self.head.prev
        self.head.prev.next = nNode
        self.head.prev = nNode
        self.head = nNode
    end
    self.length = self.length + 1
end

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

function List:enqueue(val)
    self:push(val)
end

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

function List:pushBack(val)
    if self.length == 0 then
        self.head = Node:new(val)
        self.head.next = self.head
        self.head.prev = self.head
    elseif self.length == 1 then
        local nNode = Node:new(val)
        nNode.next = self.head
        nNode.prev = self.head
        self.head.next = nNode
        self.head.prev = nNode
    elseif self.length >= 2 then
        local nNode = Node:new(val)
        nNode.next = self.head
        nNode.prev = self.head.prev
        self.head.prev.next = nNode
        self.head.prev = nNode
    end
    self.length = self.length + 1
end

local list = List:new()
local nList = list
nList:enqueue(5)
nList:enqueue(10)
nList:enqueue(15)
nList:enqueue(20)
nList:enqueue(25)

for i = 1,10 do
    print(nList:dequeue())
end
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
    return self.head.val
end

function List:next()
    self.head = self.head.next
    return self
end

function List:prev()
    self.head = self.head.prev
    return self
end

function List:addStart(val)
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
    else
        local nNode = Node:new(val)
        nNode.next = self.head
        nNode.prev = self.head.prev
        self.head.prev.next = nNode
        self.head.prev = nNode
        self.head = nNode
    end
    self.length = self.length + 1
end

function List:addEnd(val)
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
    else
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
nList:addStart("middle")
nList:addEnd("End")
nList:addStart("Start")
for i = 1,50 do
    print(nList:getVal())
    nList:prev()
end
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

return Node
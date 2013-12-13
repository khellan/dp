------------------------------------------------------------------------
--[[ Model ]]--
-- Module Adapter, Component
-- Could allow for reimplementation of each nn.Module
-- to allow for automatic reshapes, set_input_space, as in pylearn2?
------------------------------------------------------------------------

local Model = torch.class("dp.Model")
Model.isModel = true

function Model:__init(...)
   local args, typename, tags, mvstate = xlua.unpack(
      {... or {}},
      'Model', nil,
      {arg='typename', type='string', req=true, 
       help='identifies Model type in reports.'},
      {arg='tags', type='table', default={},
       help='table of tags used for determining which visitors ' ..
       'are allowed to visit the model'},
      {arg='mvstate', type='table', default={},
       help='model-visitor state'}
   )
   self._typename = typename
   -- input state
   self.istate = {}
   -- output state
   self.ostate = {}
   -- model-visitor state (double dispatch)
   self.mvstate = {}
   -- params
   self._params = {}
   -- statistics
   self._stats = {}
   -- tags
   self._tags = tags
end

function Model:setup(...)
   local args, mediator, id, predecessor, successor, container,
      data_view
      = xlua.unpack(
      {... or {}},
      'Model:setup', nil,
      {arg='mediator', type='dp.Mediator'},
      {arg='id', type='dp.ObjectID'},
      {arg='predecessor', type='dp.Model'},
      {arg='successor', type='dp.Model'},
      {arg='container', type='dp.CompositeModel'},
      {arg='data_view', type='string | table', 
       help='Used by a Sampler during setup to determine the view of' ..
       'input DataTensors.' ..
       "Possible values include 'image', 'imageCUDA', 'feature'"}
   )
   self._data_view = data_view
   self._mediator = mediator
   -- the id should be given by the experiment since the same 
   -- model is shared by all propagators.
   self._id = id
   -- context
   self._predecessor = predecessor
   self._successor = successor
   self._container = container
   -- share pointers to states
   if predecessor then
      self.istate = self._predecessor.ostate
   end
   mediator:subscribe("doneEpoch", self, "doneEpoch")
end

function Model:id()
   return self._id
end

function Model:name()
   return self._id:name()
end

function Model:tags()
   return self._tags
end

function Model:dataView()
   return self._data_view
end

--returns a report of the Model.
--if statistics were being gathered, this is the time to report them.
--Expect a report to be called at least every epoch.
function Model:report()
   
end

function Model:doneEpoch(report, ...)
   --zeros statistics
   self:zeroStatistics()
end


function Model:parameters()
   return self._params
end

function Model:forward(gstate)
   self:_forward(gstate)
   self.forwarded = true
end

function Model:_forward(gstate)
   
end

--like forward, but for evaluation purposes (valid/test).
--this is useful for stochastic Modules like Dropout, which have 
--different behavior for training than for evaluation.
function Model:evaluate(gstate)
   self:_evaluate(gstate)
   self.evaluated = true
   self.forwarded = true
end
--default is to call forward (no difference)
function Model:_evaluate(gstate)
   self:_forward(gstate)
end

function Model:backward(gstate, scale)
   self:_backward(gstate, scale)
   self.backwarded = true
end

function Model:_backward(gstate, scale)

end

function Model:update(gstate)
   --TODO (implement stats gathering in visitor?):
   --statistics on gradOutputs
   --statistics on updates
   --statistics on parameters
   
   --update parameters
   self:_update(gstate)
   self.updated = true
end

function Model:_update(gstate)
   return
end

function Model:accept(visitor)
   self.visited = true
   self:_accept(visitor)
end

function Model:_accept(visitor)
   return visitor:visitModel(self)
end

function Model:doneBatch(...)
   self:_doneBatch(...)
   self:zeroGradParameters()
   self.forwarded = false
   self.backwarded = false
   self.evaluated = false
   self.updated = false
   self.visited = false
end

function Model:_doneBatch(...)

end

function Model:zeroGradParameters()
   for param_name, param_table in pairs(self:parameters()) do
      param_table.grad:zero()
   end
end

function Model:zeroStatistics()
   
end

function Model:clone()
   local f = torch.MemoryFile("rw"):binary()
   f:writeObject(self)
   f:seek(1)
   local clone = f:readObject()
   f:close()
   return clone
end

function Model:type(type)
   -- find all tensors and convert them
   for param_name, param_table in pairs(self._params) do
      for key, tensor in pairs(param_table) do
         if torch.typename(tensor) and torch.typename(tensor):find('torch%..+Tensor') then
            param_table[key] = tensor:type(type)
         end
      end
   end
   return self
end

function Model:float()
   return self:type('torch.FloatTensor')
end

function Model:double()
   return self:type('torch.DoubleTensor')
end

function Model:cuda()
   return self:type('torch.CudaTensor')
end

function Model:reset()
end

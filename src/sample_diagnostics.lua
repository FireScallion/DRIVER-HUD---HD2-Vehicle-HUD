-- Shared global batch budget; the second return value exposes the gate.
local function sample(session,id)
 local now=M.clock
 batch_tokens=math.min(4,batch_tokens+math.max(0,now-batch_clock)*40);batch_clock=now
 if batch_frame~=M.frame then batch_frame=M.frame;batch_count=0 end
 if batch_tokens<1 or batch_count>=4 then return nil,'budget' end
 if type(id)~='number' then return nil,'invalid_id' end
 local exists=call(GS.game_object_exists,session,id)
 if exists~=true then return nil,'exists_'..tostring(exists) end
 if type(GS.game_object_field_batched)~='function' then return nil,'api_absent' end
 batch_tokens=batch_tokens-1;batch_count=batch_count+1
 local ok,f=pcall(GS.game_object_field_batched,session,id,{})
 if not ok then return nil,'api_error' end
 if type(f)~='table' then return nil,'api_'..type(f) end
 return f,'table'
end

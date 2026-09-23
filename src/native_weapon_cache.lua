-- Included INSIDE Native's lexical scope. Read-only component snapshots; no FFI calls
-- into game functions. Layout derives from the supplied 73374bd4 loaded module.
-- Each attempt re-resolves GOID -> descriptor -> entity -> component owner.
N.weapon_guards={
 {0x76e1da,"4c8b156784bb02"},
 {0x76e1ea,"458b4a284533c048895c2430418b5a3048896c24"},
 {0x76e259,"8bd0488d0452488d0c8500000000498b4250c7040100000000498b42384d8b42504c03c1488b0cd0ba8b9164ec8b49104883c428"},
 {0x76e339,"8bd0488d0452488d0c8500000000498b425044897401044d8b4250498b42384983c0044c03c1488b0cd0ba3ed6a5d78b49104883c420415ee9"},
 {0x76fece,"0f57c0418bc048c1e004480343480f1100488b433848893cc8488d4b208b5708e8cdf7fb00ff430c"},
 {0x77760f,"4c8b155af4ba02"},
 {0x77769a,"8bc84584ff498b42504c8b7c2420488d14888b0488740e0bc3eb0e"},
 {0x7776c3,"8902babc9d88cd498b42504c8d0488498b4238488b0cc88b4910"},
 {0x77a11a,"488b3dcfcbba02"},
 {0x77a04b,"448b49304533c048895c24308b5938"},
 {0x77a0b9,"8bd0488d0492488d0c8500000000498b425844897401044d8b4258498b42404983c0044c03c1488b0cd0bad5f04ea78b49104883c42041"},
 {0x77a203,"4c8b47584983c0084d8d0490ba955bec048bf0488b47402bf14a8b0cf08b4910e8b8f58500"},
 {0x77a1cd,"4c8b47584983c00c4d8d0490ba9cfa25e5"},
}
function N.check_weapon_module(read,base)
 for _,v in ipairs(N.weapon_guards) do
  local want=v[2]:gsub('..',function(h)return string.char(tonumber(h,16))end)
  if read(base+v[1],#want)~=want then return false,string.format('weapon code guard 0x%X',v[1]) end
 end
 return true
end
function G:weapon_component(d,root_rva,to,dp,array_offset,stride,n)
 local manager=ptr(self:watch(self.base+root_rva,8),0)
 if manager==0 then return nil end
 local j,owner=self:component(manager,d.entity,to,dp)
 if j==nil then return nil end
 if not same(owner,d) then error('weapon component owner mismatch',0) end
 local array=ptr(self:watch(manager+array_offset,8),0)
 -- Values copied once; validate identity/table/array pointers after the copy.
 return self:read(array+j*stride,n)
end
function G:weapon(goid,previous)
 local net=self:root('network');local d=self:net(net,goid,false)
 if not d then error('weapon GOID absent',0) end
 self:roundtrip(net,d)
 if previous and not same(d,previous) then error('weapon identity changed',0) end
 local out={descriptor=d}
 local mag=self:weapon_component(d,0x3326648,0x20,0x38,0x50,12,9)
 if mag then out.magazine={reserve=i32(mag,0),current=i32(mag,4),chamber_empty=mag:byte(9)} end
 local rounds=self:weapon_component(d,0x3326CF0,0x28,0x40,0x58,20,17)
 if rounds then out.rounds={reserve=i32(rounds,0),selected=i32(rounds,4),rounds_0=i32(rounds,8),rounds_1=i32(rounds,12),chamber_empty=rounds:byte(17)} end
 local reload=self:weapon_component(d,0x3326A70,0x20,0x38,0x50,4,4)
 if reload then local state=u32(reload,0);if state<=7 then out.state=state end end
 self:validate();out.calls=self.calls;out.bytes=self.bytes
 return out
end
function N.weapon(goid,previous)
 if not N.ready or not N.win then return nil,'native version not validated' end
 if N.weapon_base~=N.base then
  N.weapon_base=N.base
  N.win.begin_sample()
  local ok,valid,why=pcall(N.check_weapon_module,N.win.read,N.base)
  N.weapon_ready=ok and valid;N.weapon_reason=why or tostring(valid)
 end
 if not N.weapon_ready then return nil,N.weapon_reason end
 local ok,value=pcall(function()return N.sample_graph():weapon(goid,previous)end)
 if ok then return value end
 return nil,tostring(value)
end

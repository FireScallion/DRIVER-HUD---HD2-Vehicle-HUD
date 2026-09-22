-- Change-only observations expanded at 5 Hz using last observed values.
-- This tests the model against captured transitions; NOT network read availability.
local ROOT=arg[1] or '.'
local function read(p)local f=assert(io.open(p,'rb'));local s=f:read('*a');f:close();return s end
local env=setmetatable({arg={ROOT},os=setmetatable({getenv=function(k)if k=='HUD_TEST_HELPERS'then return '1'end;return os.getenv(k)end},{__index=os})},{__index=_G})
local fn=assert(loadstring(read(ROOT..'/tests/test_integration.lua')));setfenv(fn,env);local H=fn()
local fixtures=assert(loadfile(ROOT..'/tests/tank_capture_fixture.lua'))()
local checks=0
for kind,rows in pairs(fixtures)do
 local h=H.fresh();local T=h.a.Tank;local r=T.new_reload(kind)
 local previous=nil;local commits,pauses,resumes=0,0,0
 for _,row in ipairs(rows)do
  if previous then
   local t=previous[1]+.2
   while t<row[1] do T.feed_reload(r,{reserve=previous[2],current=previous[3],state=previous[4]},t);t=t+.2 end
  end
  local before=r.phase
  T.feed_reload(r,{reserve=row[2],current=row[3],state=row[4]},row[1])
  assert(r.reserve==row[2] and r.current==row[3],'ammo modified by model')
  if previous and row[2]<previous[2] then commits=commits+1 end
  if r.phase=='paused' and before~='paused' then pauses=pauses+1 end
  if before=='paused' and r.phase=='running' then resumes=resumes+1 end
  checks=checks+1;previous=row
 end
 assert(commits>=2,kind..' expected captured commits')
 assert(pauses>=1 and resumes>=1,kind..' pause and resume evidence')
 print('DETAIL replay '..kind..' rows='..#rows..' commits='..commits..' pauses='..pauses..' resumes='..resumes)
end
print('RESULT TANK_CAPTURE_REPLAY transitions='..checks..' fails=0')

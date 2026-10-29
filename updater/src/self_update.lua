-- Disabled in 1.1.6 following the console restart report.
-- Not bundled into the released plugin. Do not restore without native validation.
local M={}
function M.script()error('Self import is temporarily disabled after a console restart report')end
function M.run()error('Self import is temporarily disabled after a console restart report')end
return M

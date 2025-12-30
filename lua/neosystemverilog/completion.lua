-- #######################################
-- file: lua/neosystemverilog/completion.lua
-- author: aha
-- #######################################


local M = {}

M.source = {}

function M.source:complete(params, callback)
  -- TODO: Implement completion source
  callback({ items = {} })
end

function M.source:is_available()
  return vim.bo.filetype == 'systemverilog' or vim.bo.filetype == 'verilog'
end

return M


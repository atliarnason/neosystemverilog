-- #######################################
-- file: lua/neosystemverilog/parser.lua
-- author: aha
-- #######################################

local M = {}

function M.check_syntax()
  -- TODO: Implement Verilator/Iverilog syntax checking
  require('neosystemverilog.utils').info('Syntax checking not yet implemented')
end

function M.update_index()
  -- TODO: Implement project-wide indexing
  require('neosystemverilog.utils').info('Index update not yet implemented')
end

function M.update_file_index(file)
  -- TODO: Implement single file indexing
end

return M


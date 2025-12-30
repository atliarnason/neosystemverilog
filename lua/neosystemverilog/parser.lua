-- #######################################
-- file: lua/neosystemverilog/parser.lua
-- author: aha
-- #######################################

local M = {}

function M.check_syntax()
  -- TODO: elaborate this function 
  local config = require('neosystemverilog.config')
  local utils = require('neosystemverilog.utils')
  
  local file = vim.fn.expand('%:p')
  
  if config.get().linter.tool == 'verilator' then
    local verilator = config.get().linter.verilator_path
    local cmd = string.format('%s --lint-only %s 2>&1', verilator, file)
    
    local output, exit_code = utils.execute_command(cmd)
    
    if exit_code == 0 then
      utils.info('No syntax errors found')
    else
      utils.warn('Syntax errors detected')
      -- You can populate quickfix here later
      for _, line in ipairs(output) do
        print(line)
      end
    end
  end 
end

function M.update_index()
  -- TODO: Implement project-wide indexing
  require('neosystemverilog.utils').info('Index update not yet implemented')
end

function M.update_file_index(file)
  -- TODO: Implement single file indexing
end

return M


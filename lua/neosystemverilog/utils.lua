-- #######################################
-- file: lua/neosystemverilog/utils.lua
-- author: aha
-- #######################################

local M = {}

local config = require('neosystemverilog.config')

---Log message with level
---@param msg string
---@param level number
local function log(msg, level)
  if level >= config.get().log_level then
    vim.notify('[NeoSystemVerilog] ' .. msg, level)
  end
end

---Log info message
---@param msg string
function M.info(msg)
  log(msg, vim.log.levels.INFO)
end

---Log warning message
---@param msg string
function M.warn(msg)
  log(msg, vim.log.levels.WARN)
end

---Log error message
---@param msg string
function M.error(msg)
  log(msg, vim.log.levels.ERROR)
end

---Log debug message
---@param msg string
function M.debug(msg)
  log(msg, vim.log.levels.DEBUG)
end

---Check if a file exists
---@param path string
---@return boolean
function M.file_exists(path)
  local stat = vim.loop.fs_stat(path)
  return stat ~= nil and stat.type == 'file'
end

---Read file contents
---@param path string
---@return string|nil
function M.read_file(path)
  local file = io.open(path, 'r')
  if not file then
    return nil
  end
  
  local content = file:read('*all')
  file:close()
  return content
end

---Get project root directory
---@return string|nil
function M.get_project_root()
  -- Look for common project markers
  local markers = {
    '.git',
    'Makefile',
    'makefile',
    '*.f',
    'filelist.f',
  }
  
  local current_dir = vim.fn.expand('%:p:h')
  
  while current_dir ~= '/' do
    for _, marker in ipairs(markers) do
      local marker_path = current_dir .. '/' .. marker
      if vim.fn.glob(marker_path) ~= '' then
        return current_dir
      end
    end
    current_dir = vim.fn.fnamemodify(current_dir, ':h')
  end
  
  -- Fallback to current working directory
  return vim.fn.getcwd()
end

---Find files matching patterns
---@param patterns string[]
---@param root string|nil
---@param exclude string[]|nil
---@return string[]
function M.find_files(patterns, root, exclude)
  root = root or M.get_project_root()
  exclude = exclude or {}
  
  local files = {}
  local seen = {}
  
  for _, pattern in ipairs(patterns) do
    local found = vim.fn.globpath(root, '**/' .. pattern, false, true)
    for _, file in ipairs(found) do
      -- Check if file should be excluded
      local should_exclude = false
      for _, exclude_pattern in ipairs(exclude) do
        if file:match(exclude_pattern) then
          should_exclude = true
          break
        end
      end
      
      if not should_exclude and not seen[file] then
        table.insert(files, file)
        seen[file] = true
      end
    end
  end
  
  return files
end

---Get word under cursor
---@return string
function M.get_word_under_cursor()
  return vim.fn.expand('<cword>')
end

---Get current buffer content
---@return string[]
function M.get_buffer_lines()
  return vim.api.nvim_buf_get_lines(0, 0, -1, false)
end

---Execute shell command and return output
---@param cmd string
---@return string[], number exit_code
function M.execute_command(cmd)
  local output = vim.fn.systemlist(cmd)
  local exit_code = vim.v.shell_error
  return output, exit_code
end

---Deep copy table
---@param tbl table
---@return table
function M.deepcopy(tbl)
  return vim.deepcopy(tbl)
end

return M


-- #######################################
-- file: lua/neosystemverilog/config.lua
-- author: aha
-- #######################################


local M = {}

---@class NeoSystemVerilogConfig
---@field linter table Linter configuration
---@field completion table Completion configuration
---@field instantiation table Module instantiation configuration
---@field keymaps table Keymap configuration
---@field navigation table Navigation configuration
---@field index table Indexing configuration
---@field auto_index_on_startup boolean Auto-index project on startup
---@field auto_update_index boolean Auto-update index on file changes
---@field log_level string|number Log level

---Default configuration
M.defaults = {
  -- Linter settings
  linter = {
    tool = 'verilator', -- 'verilator' or 'iverilog'
    verilator_path = 'verilator',
    verilator_args = {
      '--lint-only',
      '-Wall',
      '--error-limit', '100',
    },
    iverilog_args = {
      '-tnull',
      '-Wall',
    },
    auto_lint_on_save = true,
    show_diagnostics = true,
  },
  
  -- Completion settings
  completion = {
    enable = true,
    enable_struct_members = true,
    enable_interface_members = true,
    enable_module_ports = true,
    enable_parameters = true,
    max_items = 50,
    priority = 100, -- Priority in completion menu
  },
  
  -- Module instantiation settings
  instantiation = {
    style = 'named', -- 'named', 'positional', 'auto'
    indent_size = 2,
    auto_align = true,
    add_instance_name = true,
    instance_name_suffix = '_u',
    add_parameter_override = true,
    use_telescope = true, -- Use telescope for module selection
  },
  
  -- Keymap settings
  keymaps = {
    enable = true,
    mappings = {
      instantiate = '<leader>si',
      goto_definition = 'gd',
      check_syntax = '<leader>sc',
      hover = 'K',
      show_hierarchy = '<leader>sh',
    },
  },
  
  -- Navigation settings
  navigation = {
    enable_hover = true,
    enable_goto_definition = true,
    enable_hierarchy = true,
    search_paths = {}, -- Additional search paths for modules
  },
  
  -- Indexing settings
  index = {
    file_patterns = {
      '*.sv',
      '*.svh',
      '*.v',
      '*.vh',
    },
    exclude_patterns = {
      '**/build/**',
      '**/simulation/**',
      '**/.git/**',
    },
    cache_dir = vim.fn.stdpath('cache') .. '/neosystemverilog',
    max_file_size = 1024 * 1024, -- 1MB max file size for indexing
  },
  
  -- Auto-indexing
  auto_index_on_startup = true,
  auto_update_index = true,
  
  -- Logging
  log_level = vim.log.levels.INFO,
}

---Current configuration
M.options = vim.deepcopy(M.defaults)

---Setup configuration with user options
---@param opts table|nil User configuration
function M.setup(opts)
  M.options = vim.tbl_deep_extend('force', M.defaults, opts or {})
  
  -- Ensure cache directory exists
  local cache_dir = M.options.index.cache_dir
  if vim.fn.isdirectory(cache_dir) == 0 then
    vim.fn.mkdir(cache_dir, 'p')
  end
  
  -- Set log level
  if type(M.options.log_level) == 'string' then
    M.options.log_level = vim.log.levels[M.options.log_level:upper()] or vim.log.levels.WARN
  end
end

---Get current configuration
---@return NeoSystemVerilogConfig
function M.get()
  return M.options
end

---Get specific configuration option
---@param key string Dot-separated key path (e.g., 'linter.tool')
---@return any
function M.get_option(key)
  local keys = vim.split(key, '.', { plain = true })
  local value = M.options
  
  for _, k in ipairs(keys) do
    if type(value) ~= 'table' then
      return nil
    end
    value = value[k]
  end
  
  return value
end

---Validate configuration
---@return boolean, string|nil
function M.validate()
  local opts = M.options
  
  -- Validate linter tool
  if opts.linter.tool ~= 'verilator' and opts.linter.tool ~= 'iverilog' then
    return false, 'Invalid linter tool: ' .. opts.linter.tool
  end
  
  -- Validate instantiation style
  local valid_styles = { 'named', 'positional', 'auto' }
  if not vim.tbl_contains(valid_styles, opts.instantiation.style) then
    return false, 'Invalid instantiation style: ' .. opts.instantiation.style
  end
  
  return true, nil
end

return M


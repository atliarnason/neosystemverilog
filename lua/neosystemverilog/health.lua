-- #######################################
-- file: lua/neosystemverilog/health.lua
-- author: aha
-- #######################################


local M = {}

local health = vim.health or require('health')
local config = require('neosystemverilog.config')

function M.check()
  health.start('NeoSystemVerilog Plugin Health Check')
  
  -- Check Neovim version
  local nvim_version = vim.version()
  if nvim_version.major == 0 and nvim_version.minor < 9 then
    health.error('Neovim >= 0.9.0 is required')
  else
    health.ok(string.format('Neovim version: %d.%d.%d', nvim_version.major, nvim_version.minor, nvim_version.patch))
  end
  
  -- Check for Verilator
  if config.get().linter.tool == 'verilator' then
    local verilator_path = config.get().linter.verilator_path
    if vim.fn.executable(verilator_path) == 1 then
      local version = vim.fn.system(verilator_path .. ' --version')
      health.ok('Verilator found: ' .. vim.trim(version:match('[^\n]+')))
    else
      health.error('Verilator not found at: ' .. verilator_path,
        'Install with: brew install verilator')
    end
  end
  
  -- Check for Iverilog
  if config.get().linter.tool == 'iverilog' then
    if vim.fn.executable('iverilog') == 1 then
      local version = vim.fn.system('iverilog -V')
      health.ok('Iverilog found: ' .. vim.trim(version:match('[^\n]+')))
    else
      health.error('Iverilog not found',
        'Install with: brew install icarus-verilog')
    end
  end
  
  -- Check for Tree-sitter
  local has_ts, ts_parsers = pcall(require, 'nvim-treesitter.parsers')
  if has_ts then
    health.ok('nvim-treesitter found')
    if ts_parsers.has_parser('verilog') then
      health.ok('Tree-sitter verilog parser installed')
    else
      health.warn('Tree-sitter verilog parser not installed',
        'Install with: :TSInstall verilog')
    end
  else
    health.warn('nvim-treesitter not found',
      'Install for better syntax parsing')
  end
  
  -- Check for nvim-cmp
  if config.get().completion.enable then
    local has_cmp = pcall(require, 'cmp')
    if has_cmp then
      health.ok('nvim-cmp found')
    else
      health.warn('nvim-cmp not found, completion disabled')
    end
  end
  
  -- Check for Telescope
  if config.get().instantiation.use_telescope then
    local has_telescope = pcall(require, 'telescope')
    if has_telescope then
      health.ok('telescope.nvim found')
    else
      health.warn('telescope.nvim not found, using vim.ui.select fallback')
    end
  end
  
  -- Check cache directory
  local cache_dir = config.get().index.cache_dir
  if vim.fn.isdirectory(cache_dir) == 1 then
    health.ok('Cache directory exists: ' .. cache_dir)
  else
    health.error('Cache directory does not exist: ' .. cache_dir)
  end
  
  -- Validate configuration
  local valid, err = config.validate()
  if valid then
    health.ok('Configuration is valid')
  else
    health.error('Configuration error: ' .. err)
  end
end

return M


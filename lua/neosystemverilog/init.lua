-- #######################################
-- file: lua/neosystemverilog/init.lua
-- author: aha
-- #######################################

local M = {}

local config = require('neosystemverilog.config')
local parser = require('neosystemverilog.parser')
local utils = require('neosystemverilog.utils')

-- Plugin state
M.state = {
  initialized = false,
  index = {},
  augroup = nil,
}

---Setup the plugin with user configuration
---@param opts table|nil User configuration options
function M.setup(opts)
  -- Merge user config with defaults
  config.setup(opts)
  
  -- Validate environment
  if not M.validate_environment() then
    utils.error('NeoSystemVerilog plugin setup failed: missing dependencies')
    return
  end
  
  -- Setup autocommands
  M.setup_autocommands()
  
  -- Setup keymaps if configured
  if config.options.keymaps.enable then
    M.setup_keymaps()
  end
  
  -- Setup completion if nvim-cmp is available
  if config.options.completion.enable then
    M.setup_completion()
  end
  
  -- Initial project indexing
  if config.options.auto_index_on_startup then
    vim.schedule(function()
      parser.update_index()
    end)
  end
  
  M.state.initialized = true
  utils.info('NeoSystemVerilog plugin initialized')
end

---Validate that required external tools are available
---@return boolean
function M.validate_environment()
  local tools_ok = true
  
  -- Check for Verilator or Iverilog
  if config.options.linter.tool == 'verilator' then
    if vim.fn.executable(config.options.linter.verilator_path) == 0 then
      utils.warn('Verilator not found at: ' .. config.options.linter.verilator_path)
      tools_ok = false
    end
  elseif config.options.linter.tool == 'iverilog' then
    if vim.fn.executable('iverilog') == 0 then
      utils.warn('Iverilog not found in PATH')
      tools_ok = false
    end
  end
  
  -- Check for tree-sitter parser
  local has_ts, ts_parsers = pcall(require, 'nvim-treesitter.parsers')
  if has_ts then
    if not ts_parsers.has_parser('verilog') then
      utils.warn('Tree-sitter verilog parser not installed')
      utils.info('Install with: :TSInstall verilog')
    end
  end
  
  return tools_ok
end

---Setup autocommands for the plugin
function M.setup_autocommands()
  M.state.augroup = vim.api.nvim_create_augroup('NeoSystemVerilog', { clear = true })
  
  -- Run syntax check on save
  if config.options.linter.auto_lint_on_save then
    vim.api.nvim_create_autocmd('BufWritePost', {
      group = M.state.augroup,
      pattern = {'*.sv', '*.svh', '*.v', '*.vh'},
      callback = function()
        vim.schedule(function()
          parser.check_syntax()
        end)
      end,
      desc = 'Run SystemVerilog syntax check on save',
    })
  end
  
  -- Update index when files change
  if config.options.auto_update_index then
    vim.api.nvim_create_autocmd({'BufWritePost', 'BufEnter'}, {
      group = M.state.augroup,
      pattern = {'*.sv', '*.svh', '*.v', '*.vh'},
      callback = function(args)
        vim.schedule(function()
          parser.update_file_index(args.file)
        end)
      end,
      desc = 'Update SystemVerilog index on file changes',
    })
  end
  
  -- Setup buffer-local keymaps
  if config.options.keymaps.enable then
    vim.api.nvim_create_autocmd('FileType', {
      group = M.state.augroup,
      pattern = {'systemverilog', 'verilog'},
      callback = function(args)
        M.setup_buffer_keymaps(args.buf)
      end,
      desc = 'Setup SystemVerilog buffer keymaps',
    })
  end
end

---Setup global keymaps
function M.setup_keymaps()
  local maps = config.options.keymaps.mappings
  local opts = { silent = true, noremap = true }
  
  if maps.instantiate then
    vim.keymap.set('n', maps.instantiate, function()
      require('neosystemverilog.instantiate').instantiate_module()
    end, vim.tbl_extend('force', opts, { desc = 'Instantiate SystemVerilog module' }))
  end
  
  if maps.goto_definition then
    vim.keymap.set('n', maps.goto_definition, function()
      require('neosystemverilog.navigation').goto_definition()
    end, vim.tbl_extend('force', opts, { desc = 'Go to definition' }))
  end
  
  if maps.check_syntax then
    vim.keymap.set('n', maps.check_syntax, function()
      require('neosystemverilog.parser').check_syntax()
    end, vim.tbl_extend('force', opts, { desc = 'Check syntax' }))
  end
end

---Setup buffer-local keymaps
---@param bufnr number
function M.setup_buffer_keymaps(bufnr)
  local maps = config.options.keymaps.mappings
  local opts = { silent = true, noremap = true, buffer = bufnr }
  
  -- Additional buffer-local mappings can be added here
  if maps.hover then
    vim.keymap.set('n', maps.hover, function()
      require('neosystemverilog.navigation').hover()
    end, vim.tbl_extend('force', opts, { desc = 'Show hover information' }))
  end
end

---Setup completion source
function M.setup_completion()
  local ok, cmp = pcall(require, 'cmp')
  if not ok then
    utils.warn('nvim-cmp not found, completion disabled')
    return
  end
  
  local completion = require('neosystemverilog.completion')
  cmp.register_source('neosystemverilog', completion.source)
  
  -- Add to cmp sources if not already present
  local cmp_config = cmp.get_config()
  local sources = cmp_config.sources or {}
  
  -- Check if already registered
  local already_registered = false
  for _, source in ipairs(sources) do
    if source.name == 'neosystemverilog' then
      already_registered = true
      break
    end
  end
  
  if not already_registered then
    table.insert(sources, { name = 'neosystemverilog' })
    cmp.setup.filetype({'systemverilog', 'verilog'}, {
      sources = sources
    })
  end
end

---Get plugin state (useful for debugging)
---@return table
function M.get_state()
  return M.state
end

return M



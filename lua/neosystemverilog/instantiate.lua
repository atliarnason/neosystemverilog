-- #######################################
-- file: lua/neosystemverilog/instantiate.lua
-- author: aha
-- #######################################

local M = {}


local config = require('neosystemverilog.config')
local parser = require('neosystemverilog.parser')
local utils = require('neosystemverilog.utils')

---Get list of all available modules for completion
---@return string[]
function M.get_module_list()
  local modules = {}
  
  -- Get from cache
  for name, _ in pairs(parser.cache.modules) do
    table.insert(modules, name)
  end
  
  table.sort(modules)
  return modules
end

---Main instantiation function
---@param module_name string|nil Module name (nil to show picker)
function M.instantiate_module(module_name)
  -- If no module name provided, show picker
  if not module_name or module_name == '' then
    M._show_module_picker()
    return
  end
  
  -- Find module definition
  local module_def = parser.cache.modules[module_name]
  
  if not module_def then
    -- Try to find it by searching
    module_def = parser.find_module_definition(module_name)
  end
  
  if not module_def then
    utils.error('Module not found: ' .. module_name)
    utils.info('Try running :SVUpdateIndex first')
    return
  end
  
  -- Generate instantiation
  local instantiation = M._generate_instantiation(module_def)
  
  -- Insert at cursor
  M._insert_instantiation(instantiation)
  
  utils.info('Instantiated module: ' .. module_name)
end

---Show module picker (Telescope or vim.ui.select)
function M._show_module_picker()
  local modules = M.get_module_list()
  
  if #modules == 0 then
    utils.error('No modules found in index')
    utils.info('Run :SVUpdateIndex to index your project')
    return
  end
  
  local cfg = config.get()
  
  -- Try Telescope first if configured
  if cfg.instantiation.use_telescope then
    local ok = pcall(M._show_telescope_picker, modules)
    if ok then
      return
    end
    utils.debug('Telescope not available, falling back to vim.ui.select')
  end
  
  -- Fallback to vim.ui.select
  M._show_vim_select_picker(modules)
end

---Show Telescope picker
---@param modules string[]
function M._show_telescope_picker(modules)
  local pickers = require('telescope.pickers')
  local finders = require('telescope.finders')
  local conf = require('telescope.config').values
  local actions = require('telescope.actions')
  local action_state = require('telescope.actions.state')
  
  -- Create entries with module info
  local entries = {}
  for _, name in ipairs(modules) do
    local module_def = parser.cache.modules[name]
    local display = string.format('%s (%s:%d)', 
      name, 
      vim.fn.fnamemodify(module_def.file, ':.'),
      module_def.line)
    
    table.insert(entries, {
      value = name,
      display = display,
      ordinal = name,
      module_def = module_def,
    })
  end
  
  pickers.new({}, {
    prompt_title = 'Select Module to Instantiate',
    finder = finders.new_table({
      results = entries,
      entry_maker = function(entry)
        return {
          value = entry.value,
          display = entry.display,
          ordinal = entry.ordinal,
          module_def = entry.module_def,
        }
      end,
    }),
    sorter = conf.generic_sorter({}),
    attach_mappings = function(prompt_bufnr, map)
      actions.select_default:replace(function()
        actions.close(prompt_bufnr)
        local selection = action_state.get_selected_entry()
        M.instantiate_module(selection.value)
      end)
      return true
    end,
  }):find()
end

---Show vim.ui.select picker
---@param modules string[]
function M._show_vim_select_picker(modules)
  -- Add module info to display
  local display_items = {}
  for _, name in ipairs(modules) do
    local module_def = parser.cache.modules[name]
    local display = string.format('%s (%s:%d)', 
      name,
      vim.fn.fnamemodify(module_def.file, ':.'),
      module_def.line)
    table.insert(display_items, display)
  end
  
  vim.ui.select(display_items, {
    prompt = 'Select module to instantiate:',
    format_item = function(item)
      return item
    end,
  }, function(choice, idx)
    if choice then
      M.instantiate_module(modules[idx])
    end
  end)
end

---Generate instantiation text
---@param module_def table Module definition
---@return string[] Lines of instantiation
function M._generate_instantiation(module_def)
  local cfg = config.get().instantiation
  local lines = {}
  
  -- Generate instance name
  local instance_name = module_def.name
  if cfg.add_instance_name then
    instance_name = instance_name .. cfg.instance_name_suffix
  end
  
  -- Start with module name and parameters
  local header = module_def.name
  
  -- Add parameter override if configured and parameters exist
  if cfg.add_parameter_override and #module_def.parameters > 0 then
    table.insert(lines, header .. ' #(')
    
    for i, param in ipairs(module_def.parameters) do
      local comma = i < #module_def.parameters and ',' or ''
      local param_line = string.format('  .%s(%s)%s', 
        param.name, 
        param.value or param.name:upper(),
        comma)
      table.insert(lines, param_line)
    end
    
    table.insert(lines, ') ' .. instance_name .. ' (')
  else
    table.insert(lines, header .. ' ' .. instance_name .. ' (')
  end
  
  -- Add ports based on style
  if cfg.style == 'named' then
    M._add_named_ports(lines, module_def.ports, cfg)
  elseif cfg.style == 'positional' then
    M._add_positional_ports(lines, module_def.ports, cfg)
  elseif cfg.style == 'auto' then
    M._add_auto_ports(lines, module_def.ports, cfg)
  end
  
  table.insert(lines, ');')
  
  return lines
end

---Add named port connections
---@param lines string[]
---@param ports table[]
---@param cfg table
function M._add_named_ports(lines, ports, cfg)
  if #ports == 0 then
    return
  end
  
  -- Calculate alignment if needed
  local max_name_len = 0
  if cfg.auto_align then
    for _, port in ipairs(ports) do
      max_name_len = math.max(max_name_len, #port.name)
    end
  end
  
  for i, port in ipairs(ports) do
    local comma = i < #ports and ',' or ''
    
    if cfg.auto_align then
      local padding = string.rep(' ', max_name_len - #port.name)
      local port_line = string.format('  .%s%s(%s)%s',
        port.name,
        padding,
        port.name,
        comma)
      table.insert(lines, port_line)
    else
      local port_line = string.format('  .%s(%s)%s',
        port.name,
        port.name,
        comma)
      table.insert(lines, port_line)
    end
  end
end

---Add positional port connections
---@param lines string[]
---@param ports table[]
---@param cfg table
function M._add_positional_ports(lines, ports, cfg)
  if #ports == 0 then
    return
  end
  
  for i, port in ipairs(ports) do
    local comma = i < #ports and ',' or ''
    local port_line = string.format('  %s%s', port.name, comma)
    table.insert(lines, port_line)
  end
end

---Add auto-wired port connections (matches signal names)
---@param lines string[]
---@param ports table[]
---@param cfg table
function M._add_auto_ports(lines, ports, cfg)
  if #ports == 0 then
    return
  end
  
  -- Get signals from current buffer
  local buffer_signals = M._get_buffer_signals()
  
  -- Calculate alignment if needed
  local max_name_len = 0
  if cfg.auto_align then
    for _, port in ipairs(ports) do
      max_name_len = math.max(max_name_len, #port.name)
    end
  end
  
  for i, port in ipairs(ports) do
    local comma = i < #ports and ',' or ''
    
    -- Try to find matching signal
    local signal = M._find_matching_signal(port.name, buffer_signals)
    
    if cfg.auto_align then
      local padding = string.rep(' ', max_name_len - #port.name)
      local port_line = string.format('  .%s%s(%s)%s',
        port.name,
        padding,
        signal,
        comma)
      table.insert(lines, port_line)
    else
      local port_line = string.format('  .%s(%s)%s',
        port.name,
        signal,
        comma)
      table.insert(lines, port_line)
    end
  end
end

---Get signals declared in current buffer
---@return table<string, boolean>
function M._get_buffer_signals()
  local signals = {}
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  
  for _, line in ipairs(lines) do
    -- Match signal declarations: wire/reg/logic name
    local signal_name = line:match('%s*(?:wire|reg|logic|bit)%s+[%w%[%]:%s]*%s*([%w_]+)')
    if signal_name then
      signals[signal_name] = true
    end
    
    -- Match input/output declarations
    signal_name = line:match('%s*(?:input|output|inout)%s+[%w%[%]:%s]*%s*([%w_]+)')
    if signal_name then
      signals[signal_name] = true
    end
  end
  
  return signals
end

---Find matching signal for port
---@param port_name string
---@param signals table<string, boolean>
---@return string
function M._find_matching_signal(port_name, signals)
  -- Direct match
  if signals[port_name] then
    return port_name
  end
  
  -- Try common variations
  local variations = {
    port_name:lower(),
    port_name:upper(),
    'i_' .. port_name,  -- input prefix
    'o_' .. port_name,  -- output prefix
    port_name .. '_i',
    port_name .. '_o',
  }
  
  for _, variant in ipairs(variations) do
    if signals[variant] then
      return variant
    end
  end
  
  -- No match found, return port name with comment
  return port_name .. ' /* TODO: connect */'
end

---Insert instantiation at cursor
---@param lines string[]
function M._insert_instantiation(lines)
  local cursor = vim.api.nvim_win_get_cursor(0)
  local row = cursor[1]
  local cfg = config.get().instantiation
  
  -- Add indentation to all lines
  local indent = string.rep(' ', cfg.indent_size)
  for i, line in ipairs(lines) do
    lines[i] = indent .. line
  end
  
  -- Insert lines at cursor position
  vim.api.nvim_buf_set_lines(0, row, row, false, lines)
  
  -- Move cursor to after instantiation
  vim.api.nvim_win_set_cursor(0, {row + #lines, 0})
end

---Instantiate module under cursor
function M.instantiate_under_cursor()
  local word = utils.get_word_under_cursor()
  
  if word == '' then
    utils.error('No word under cursor')
    return
  end
  
  M.instantiate_module(word)
end

---Show module information (hover-style)
---@param module_name string
function M.show_module_info(module_name)
  local module_def = parser.cache.modules[module_name]
  
  if not module_def then
    utils.warn('Module not found: ' .. module_name)
    return
  end
  
  local lines = {}
  
  table.insert(lines, string.format('Module: %s', module_def.name))
  table.insert(lines, string.format('File: %s:%d', 
    vim.fn.fnamemodify(module_def.file, ':.'),
    module_def.line))
  table.insert(lines, '')
  
  -- Parameters
  if #module_def.parameters > 0 then
    table.insert(lines, 'Parameters:')
    for _, param in ipairs(module_def.parameters) do
      local value = param.value and (' = ' .. param.value) or ''
      table.insert(lines, string.format('  %s%s', param.name, value))
    end
    table.insert(lines, '')
  end
  
  -- Ports
  if #module_def.ports > 0 then
    table.insert(lines, 'Ports:')
    for _, port in ipairs(module_def.ports) do
      table.insert(lines, string.format('  %s %s %s',
        port.direction,
        port.type,
        port.name))
    end
  end
  
  utils.show_float(lines, 'Module: ' .. module_def.name)
end

---Generate testbench instantiation (creates a basic testbench)
---@param module_name string
function M.generate_testbench(module_name)
  -- If no module name provided, show picker
  if not module_name or module_name == '' then
    M._show_module_picker()
    return
  end

  local module_def = parser.cache.modules[module_name]
  
  if not module_def then
    utils.error('Module not found: ' .. module_name)
    return
  end
  
  local lines = {}
  
  -- Testbench header
  table.insert(lines, string.format('module tb_%s;', module_name))
  table.insert(lines, '')
  
  -- Generate signals
  table.insert(lines, '  // Clock and reset')
  table.insert(lines, '  logic clk = 0;')
  table.insert(lines, '  logic rst = 1;')
  table.insert(lines, '')
  
  table.insert(lines, '  // Testbench signals')
  for _, port in ipairs(module_def.ports) do
    local signal_dir = port.direction == 'input' and 'logic' or 'wire'
    if port.direction == 'input' then
      table.insert(lines, string.format('  logic %s;', port.name))
    else
      table.insert(lines, string.format('  wire %s;', port.name))
    end
  end
  table.insert(lines, '')
  
  -- DUT instantiation
  table.insert(lines, '  // Device Under Test')
  local inst_lines = M._generate_instantiation(module_def)
  for _, line in ipairs(inst_lines) do
    table.insert(lines, '  ' .. line)
  end
  table.insert(lines, '')
  
  -- Clock generation
  table.insert(lines, '  // Clock generation')
  table.insert(lines, '  always #5 clk = ~clk;')
  table.insert(lines, '')
  
  -- Initial block
  table.insert(lines, '  initial begin')
  table.insert(lines, '    // Initialize signals')
  for _, port in ipairs(module_def.ports) do
    if port.direction == 'input' then
      table.insert(lines, string.format('    %s = 0;', port.name))
    end
  end
  table.insert(lines, '')
  table.insert(lines, '    // Reset sequence')
  table.insert(lines, '    #10 rst = 1;')
  table.insert(lines, '    #20 rst = 0;')
  table.insert(lines, '')
  table.insert(lines, '    // Test sequence')
  table.insert(lines, '    #100;')
  table.insert(lines, '')
  table.insert(lines, '    $finish;')
  table.insert(lines, '  end')
  table.insert(lines, '')
  
  -- Waveform dump
  table.insert(lines, '  initial begin')
  table.insert(lines, '    $dumpfile("dump.vcd");')
  table.insert(lines, '    $dumpvars(0, tb_' .. module_name .. ');')
  table.insert(lines, '  end')
  table.insert(lines, '')
  
  table.insert(lines, 'endmodule')
  
  -- Create new buffer with testbench
  vim.cmd('vnew')
  vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
  vim.bo.filetype = 'systemverilog'
  vim.api.nvim_buf_set_name(0, 'tb_' .. module_name .. '.sv')
  
  utils.info('Generated testbench for: ' .. module_name)
end

return M




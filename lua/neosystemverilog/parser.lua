-- #######################################
-- file: lua/neosystemverilog/parser.lua
-- author: aha
-- #######################################

-- lua/neosystemverilog/parser.lua
local M = {}

local ts_utils = require('nvim-treesitter.ts_utils')

local config = require('neosystemverilog.config')
local utils = require('neosystemverilog.utils')

-- Cache for parsed data
M.cache = {
  modules = {}, -- module_name -> { file, ports, parameters, line }
  interfaces = {}, -- interface_name -> { file, members, line }
  structs = {}, -- struct_name -> { file, members, line }
  typedefs = {}, -- typedef_name -> { file, type, line }
  files = {}, -- file -> { modules, interfaces, structs, last_modified }
}

---Check syntax using configured linter
function M.check_syntax()
  local cfg = config.get()
  local file = vim.fn.expand('%:p')
  
  if not utils.file_exists(file) then
    utils.error('File does not exist: ' .. file)
    return
  end
  
  if cfg.linter.tool == 'verilator' then
    M._check_syntax_verilator(file)
  elseif cfg.linter.tool == 'iverilog' then
    M._check_syntax_iverilog(file)
  else
    utils.error('Unknown linter tool: ' .. cfg.linter.tool)
  end
end

---Check syntax using Verilator
---@param file string
function M._check_syntax_verilator(file)
  local cfg = config.get()
  local verilator = cfg.linter.verilator_path
  
  -- Build command
  local args = table.concat(cfg.linter.verilator_args, ' ')
  local cmd = string.format('%s %s %s 2>&1', verilator, args, vim.fn.shellescape(file))
  
  utils.debug('Running: ' .. cmd)
  
  local output, exit_code = utils.execute_command(cmd)
  
  if exit_code == 0 then
    utils.info('No syntax errors found')
    if cfg.linter.show_diagnostics then
      vim.diagnostic.reset(vim.api.nvim_create_namespace('neosystemverilog'), 0)
    end
  else
    utils.warn('Syntax errors detected')
    if cfg.linter.show_diagnostics then
      M._parse_verilator_output(output, file)
    else
      -- Just show in messages
      for _, line in ipairs(output) do
        print(line)
      end
    end
  end
end

---Parse Verilator output and create diagnostics
---@param output string[]
---@param file string
function M._parse_verilator_output(output, file)
  local diagnostics = {}
  local ns = vim.api.nvim_create_namespace('neosystemverilog')
  
  for _, line in ipairs(output) do
    -- Verilator format: %Error: file:line:col: message
    -- or %Warning: file:line:col: message
    local severity, file_path, lnum, col, msg = line:match('%%(%w+):%s*([^:]+):(%d+):(%d+):%s*(.*)')
    
    if severity and file_path and lnum then
      -- Only show diagnostics for current file
      if vim.fn.fnamemodify(file_path, ':p') == file then
        local diag_severity = vim.diagnostic.severity.ERROR
        if severity == 'Warning' then
          diag_severity = vim.diagnostic.severity.WARN
        elseif severity == 'Info' then
          diag_severity = vim.diagnostic.severity.INFO
        end
        
        table.insert(diagnostics, {
          lnum = tonumber(lnum) - 1, -- 0-indexed
          col = tonumber(col) - 1,
          severity = diag_severity,
          source = 'verilator',
          message = msg,
        })
      end
    end
  end
  
  vim.diagnostic.set(ns, 0, diagnostics, {})
end

---Check syntax using Iverilog
---@param file string
function M._check_syntax_iverilog(file)
  local cfg = config.get()
  
  -- Build command
  local args = table.concat(cfg.linter.iverilog_args, ' ')
  local cmd = string.format('iverilog %s %s 2>&1', args, vim.fn.shellescape(file))
  
  utils.debug('Running: ' .. cmd)
  
  local output, exit_code = utils.execute_command(cmd)
  
  if exit_code == 0 then
    utils.info('No syntax errors found')
    if cfg.linter.show_diagnostics then
      vim.diagnostic.reset(vim.api.nvim_create_namespace('neosystemverilog'), 0)
    end
  else
    utils.warn('Syntax errors detected')
    if cfg.linter.show_diagnostics then
      M._parse_iverilog_output(output, file)
    else
      for _, line in ipairs(output) do
        print(line)
      end
    end
  end
end

---Parse Iverilog output and create diagnostics
---@param output string[]
---@param file string
function M._parse_iverilog_output(output, file)
  local diagnostics = {}
  local ns = vim.api.nvim_create_namespace('neosystemverilog')
  
  for _, line in ipairs(output) do
    -- Iverilog format: file:line: error/warning: message
    local file_path, lnum, severity, msg = line:match('([^:]+):(%d+):%s*(%w+):%s*(.*)')
    
    if file_path and lnum then
      if vim.fn.fnamemodify(file_path, ':p') == file then
        local diag_severity = vim.diagnostic.severity.ERROR
        if severity:lower():match('warn') then
          diag_severity = vim.diagnostic.severity.WARN
        end
        
        table.insert(diagnostics, {
          lnum = tonumber(lnum) - 1,
          col = 0,
          severity = diag_severity,
          source = 'iverilog',
          message = msg,
        })
      end
    end
  end
  
  vim.diagnostic.set(ns, 0, diagnostics, {})
end

---Update project-wide index
function M.update_index()
  local cfg = config.get()
  local root = utils.get_project_root()
  
  utils.info('Updating project index from: ' .. root)
  
  -- Find all SystemVerilog files
  local files = utils.find_files(
    cfg.index.file_patterns,
    root,
    cfg.index.exclude_patterns
  )
  
  utils.debug(string.format('Found %d files to index', #files))
  
  -- Clear old cache
  M.cache = {
    modules = {},
    interfaces = {},
    structs = {},
    typedefs = {},
    files = {},
  }



---Get tree-sitter parser for current buffer
---@return table|nil parser
---@return table|nil tree
local function get_ts_parser()
  local has_parser, parser = pcall(vim.treesitter.get_parser, 0, 'verilog')
  if not has_parser then
    utils.warn('Tree-sitter verilog parser not available')
    return nil, nil
  end
  
  local tree = parser:parse()[1]
  return parser, tree
end

---Extract module name from node
---@param node table Tree-sitter node
---@return string|nil
local function get_node_text(node)
  if not node then return nil end
  return vim.treesitter.get_node_text(node, 0)
end

---Find all module instantiations in a file
---@param file string File path
---@return table[] List of {module_name, file, line}
function M.find_module_instantiations(file)
  local instantiations = {}
  
  -- Read file content
  local content = utils.read_file(file)
  if not content then
    utils.error('Could not read file: ' .. file)
    return instantiations
  end
  
  -- Parse with tree-sitter
  local parser = vim.treesitter.get_string_parser(content, 'verilog')
  local tree = parser:parse()[1]
  local root = tree:root()
  
  -- Query for module instantiations
  local query_str = [[
    (module_instantiation
      (simple_identifier) @module_type
      (name_of_instance
        (instance_identifier) @instance_name))
  ]]
  
  local ok, query = pcall(vim.treesitter.query.parse, 'verilog', query_str)
  if not ok then
    -- Fallback to regex-based parsing
    return M._find_instantiations_regex(content, file)
  end
  
  for id, node, metadata in query:iter_captures(root, content, 0, -1) do
    local capture_name = query.captures[id]
    if capture_name == 'module_type' then
      local module_name = get_node_text(node)
      local start_row = node:range()
      
      table.insert(instantiations, {
        module_name = module_name,
        file = file,
        line = start_row + 1,
      })
    end
  end
  
  return instantiations
end

---Fallback regex-based instantiation finder
---@param content string
---@param file string
---@return table[]
function M._find_instantiations_regex(content, file)
  local instantiations = {}
  local lines = vim.split(content, '\n')
  
  for i, line in ipairs(lines) do
    -- Match: module_name instance_name ( or module_name #(...) instance_name (
    local module_name = line:match('^%s*(%w+)%s+#?%s*%(')
    if not module_name then
      module_name = line:match('^%s*(%w+)%s+#%s*%(.-%)')
    end
    if not module_name then
      module_name = line:match('^%s*(%w+)%s+(%w+)%s*%(')
    end
    
    -- Skip keywords
    local keywords = {
      'module', 'endmodule', 'input', 'output', 'inout', 'wire', 'reg',
      'logic', 'bit', 'byte', 'if', 'else', 'case', 'for', 'while',
      'always', 'initial', 'assign', 'parameter', 'localparam'
    }
    
    if module_name and not vim.tbl_contains(keywords, module_name) then
      table.insert(instantiations, {
        module_name = module_name,
        file = file,
        line = i,
      })
    end
  end
  
  return instantiations
end

---Find all include directives in a file
---@param file string File path
---@return string[] List of included file paths
function M.find_includes(file)
  local includes = {}
  local content = utils.read_file(file)
  if not content then
    return includes
  end
  
  local file_dir = vim.fn.fnamemodify(file, ':h')
  
  -- Match `include "file.svh" or `include <file.svh>
  for include_file in content:gmatch('`include%s+["\']([^"\']+)["\']') do
    local full_path = file_dir .. '/' .. include_file
    if utils.file_exists(full_path) then
      table.insert(includes, full_path)
    else
      -- Try search paths
      local cfg = config.get()
      for _, search_path in ipairs(cfg.navigation.search_paths) do
        full_path = search_path .. '/' .. include_file
        if utils.file_exists(full_path) then
          table.insert(includes, full_path)
          break
        end
      end
    end
  end
  
  return includes
end

---Parse module definition from file using tree-sitter
---@param file string
---@param module_name string
---@return table|nil Module info {name, ports, parameters, file, line}
function M.parse_module_definition(file, module_name)
  local content = utils.read_file(file)
  if not content then
    return nil
  end
  
  local parser = vim.treesitter.get_string_parser(content, 'verilog')
  local tree = parser:parse()[1]
  local root = tree:root()
  
  -- Query for module declaration
  local query_str = [[
    (module_declaration
      (module_header
        name: (simple_identifier) @module_name
        (list_of_port_declarations)? @ports))
  ]]
  
  local ok, query = pcall(vim.treesitter.query.parse, 'verilog', query_str)
  if not ok then
    return M._parse_module_regex(content, file, module_name)
  end
  
  for id, node, metadata in query:iter_captures(root, content, 0, -1) do
    local capture_name = query.captures[id]
    if capture_name == 'module_name' then
      local name = get_node_text(node)
      if name == module_name then
        local start_row = node:range()
        
        -- Extract ports
        local ports = M._extract_ports_from_node(node:parent():parent(), content)
        local parameters = M._extract_parameters_from_node(node:parent():parent(), content)
        
        return {
          name = name,
          file = file,
          line = start_row + 1,
          ports = ports,
          parameters = parameters,
        }
      end
    end
  end
  
  return nil
end

---Extract ports from module node
---@param module_node table
---@param content string
---@return table[] ports
function M._extract_ports_from_node(module_node, content)
  local ports = {}
  
  -- This is a simplified version - you may need to adjust based on tree-sitter grammar
  for child in module_node:iter_children() do
    local type = child:type()
    if type:match('port') or type:match('declaration') then
      local port_text = get_node_text(child)
      if port_text then
        -- Parse port direction and name
        local direction, port_type, name = port_text:match('(%w+)%s+(%w+)%s+(%w+)')
        if not direction then
          direction, name = port_text:match('(%w+)%s+(%w+)')
        end
        
        if name then
          table.insert(ports, {
            name = name,
            direction = direction or 'unknown',
            type = port_type or 'logic',
          })
        end
      end
    end
  end
  
  return ports
end

---Extract parameters from module node
---@param module_node table
---@param content string
---@return table[] parameters
function M._extract_parameters_from_node(module_node, content)
  local parameters = {}
  
  for child in module_node:iter_children() do
    local type = child:type()
    if type:match('parameter') then
      local param_text = get_node_text(child)
      if param_text then
        -- Parse parameter: parameter TYPE NAME = VALUE
        local name, value = param_text:match('parameter%s+%w*%s*(%w+)%s*=%s*(.+)')
        if name then
          table.insert(parameters, {
            name = name,
            value = value and vim.trim(value) or nil,
          })
        end
      end
    end
  end
  
  return parameters
end

---Fallback regex-based module parser
---@param content string
---@param file string
---@param module_name string
---@return table|nil
function M._parse_module_regex(content, file, module_name)
  local lines = vim.split(content, '\n')
  
  for i, line in ipairs(lines) do
    local name = line:match('^%s*module%s+(%w+)')
    if name == module_name then
      local ports = {}
      local parameters = {}
      
      -- Simple port extraction (this is very basic)
      local j = i + 1
      while j <= #lines and not lines[j]:match('^%s*endmodule') do
        local port_line = lines[j]
        
        -- Match: input/output/inout [type] name
        local direction, port_name = port_line:match('^%s*(%w+)%s+%w*%s*(%w+)')
        if direction and (direction == 'input' or direction == 'output' or direction == 'inout') then
          table.insert(ports, {
            name = port_name,
            direction = direction,
            type = 'logic',
          })
        end
        
        -- Match parameters
        local param_name = port_line:match('^%s*parameter%s+%w*%s*(%w+)')
        if param_name then
          table.insert(parameters, {
            name = param_name,
            value = nil,
          })
        end
        
        j = j + 1
      end
      
      return {
        name = name,
        file = file,
        line = i,
        ports = ports,
        parameters = parameters,
      }
    end
  end
  
  return nil
end

---Elaborate current file and all dependencies
---@param start_file string|nil Starting file (default: current buffer)
---@return table Elaboration result {files, modules, hierarchy, includes}
function M.elaborate(start_file)
  start_file = start_file or vim.fn.expand('%:p')
  
  if not utils.file_exists(start_file) then
    utils.error('File does not exist: ' .. start_file)
    return { files = {}, modules = {}, hierarchy = {}, includes = {} }
  end
  
  utils.info('Elaborating from: ' .. start_file)
  
  local result = {
    files = {},      -- All files processed
    modules = {},    -- All module definitions found
    hierarchy = {},  -- Module instantiation hierarchy
    includes = {},   -- Include file relationships
  }
  
  local visited_files = {}
  local visited_modules = {}
  
  ---Recursively elaborate a file
  ---@param file string
  ---@param depth number
  local function elaborate_file(file, depth)
    if visited_files[file] then
      return
    end
    
    if depth > 20 then
      utils.warn('Maximum elaboration depth reached for: ' .. file)
      return
    end
    
    visited_files[file] = true
    table.insert(result.files, file)
    
    utils.debug(string.format('%sElaborating: %s', string.rep('  ', depth), file))
    
    -- Find and process includes
    local includes = M.find_includes(file)
    for _, include_file in ipairs(includes) do
      result.includes[file] = result.includes[file] or {}
      table.insert(result.includes[file], include_file)
      elaborate_file(include_file, depth + 1)
    end
    
    -- Find module instantiations
    local instantiations = M.find_module_instantiations(file)
    
    for _, inst in ipairs(instantiations) do
      local module_name = inst.module_name
      
      utils.debug(string.format('%s  Found instantiation: %s', string.rep('  ', depth), module_name))
      
      -- Add to hierarchy
      result.hierarchy[file] = result.hierarchy[file] or {}
      table.insert(result.hierarchy[file], {
        module = module_name,
        line = inst.line,
      })
      
      -- Skip if already processed
      if visited_modules[module_name] then
        goto continue
      end
      
      -- Find module definition
      local module_def = M.find_module_definition(module_name)
      
      if module_def then
        visited_modules[module_name] = true
        result.modules[module_name] = module_def
        
        -- Recursively elaborate the module's file
        if module_def.file ~= file then
          elaborate_file(module_def.file, depth + 1)
        end
      else
        utils.warn(string.format('Module definition not found: %s (instantiated in %s:%d)', 
          module_name, file, inst.line))
      end
      
      ::continue::
    end
  end
  
  -- Start elaboration
  elaborate_file(start_file, 0)
  
  utils.info(string.format('Elaboration complete: %d files, %d modules', 
    #result.files, vim.tbl_count(result.modules)))
  
  return result
end

---Find module definition in index or by searching files
---@param module_name string
---@return table|nil Module definition
function M.find_module_definition(module_name)
  -- Check cache first
  if M.cache.modules[module_name] then
    return M.cache.modules[module_name]
  end
  
  -- Search all indexed files
  local cfg = config.get()
  local root = utils.get_project_root()
  local files = utils.find_files(cfg.index.file_patterns, root, cfg.index.exclude_patterns)
  
  for _, file in ipairs(files) do
    local module_def = M.parse_module_definition(file, module_name)
    if module_def then
      -- Cache it
      M.cache.modules[module_name] = module_def
      return module_def
    end
  end
  
  return nil
end

---Display elaboration results
---@param elab_result table Elaboration result
function M.show_elaboration_results(elab_result)
  local lines = {}
  
  table.insert(lines, '=== Elaboration Results ===')
  table.insert(lines, '')
  
  -- Files
  table.insert(lines, string.format('Files processed: %d', #elab_result.files))
  for _, file in ipairs(elab_result.files) do
    table.insert(lines, '  ' .. vim.fn.fnamemodify(file, ':.'))
  end
  table.insert(lines, '')
  
  -- Modules
  table.insert(lines, string.format('Modules found: %d', vim.tbl_count(elab_result.modules)))
  for name, mod in pairs(elab_result.modules) do
    table.insert(lines, string.format('  %s (%s:%d)', name, 
      vim.fn.fnamemodify(mod.file, ':.'), mod.line))
    if #mod.ports > 0 then
      table.insert(lines, '    Ports: ' .. #mod.ports)
    end
    if #mod.parameters > 0 then
      table.insert(lines, '    Parameters: ' .. #mod.parameters)
    end
  end
  table.insert(lines, '')
  
  -- Hierarchy
  table.insert(lines, 'Module Hierarchy:')
  for file, instances in pairs(elab_result.hierarchy) do
    table.insert(lines, '  ' .. vim.fn.fnamemodify(file, ':.'))
    for _, inst in ipairs(instances) do
      table.insert(lines, string.format('    -> %s (line %d)', inst.module, inst.line))
    end
  end
  
  -- Create a new buffer to display results
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(buf, 'modifiable', false)
  vim.api.nvim_buf_set_option(buf, 'filetype', 'text')
  
  -- Open in a new window
  vim.cmd('vsplit')
  local win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(win, buf)
  vim.api.nvim_buf_set_name(buf, 'Elaboration Results')
end

-- Keep all your existing functions (check_syntax, update_index, etc.)


-- #######################################
-- file: plugin/neosystemverilog.lua
-- author: aha
-- #######################################


if vim.g.loaded_systemverilog then
  return
end
vim.g.loaded_systemverilog = 1


------------------------------------------------------------------------
-- user commands 
------------------------------------------------------------------------

-- instantiate
-- Module instantiation commands
vim.api.nvim_create_user_command('SVInstantiate', function(opts)
  require('neosystemverilog.instantiate').instantiate_module(opts.args)
end, {
  nargs = '?',
  desc = 'Instantiate a SystemVerilog module',
  complete = function()
    return require('neosystemverilog.instantiate').get_module_list()
  end,
})

vim.api.nvim_create_user_command('SVInstantiateUnderCursor', function()
  require('neosystemverilog.instantiate').instantiate_under_cursor()
end, {
  desc = 'Instantiate module under cursor',
})

vim.api.nvim_create_user_command('SVModuleInfo', function(opts)
  local module_name = opts.args ~= '' and opts.args or 
                      require('neosystemverilog.utils').get_word_under_cursor()
  require('neosystemverilog.instantiate').show_module_info(module_name)
end, {
  nargs = '?',
  complete = function()
    return require('neosystemverilog.instantiate').get_module_list()
  end,
  desc = 'Show module information',
})

vim.api.nvim_create_user_command('SVGenerateTestbench', function(opts)
  require('neosystemverilog.instantiate').generate_testbench(opts.args)
end, {
  nargs = 1,
  complete = function()
    return require('neosystemverilog.instantiate').get_module_list()
  end,
  desc = 'Generate testbench for module',
})
})

-- goto definition
vim.api.nvim_create_user_command('SVGotoDefinition', function()
  require('neosystemverilog.navigation').goto_definition()
end, {
  desc = 'Go to SystemVerilog module/interface definition',
})

-- check syntax - run linter
vim.api.nvim_create_user_command('SVCheckSyntax', function()
  require('neosystemverilog.parser').check_syntax()
end, {
  desc = 'Run Verilator syntax check on current file',
})

-- uodate project index
vim.api.nvim_create_user_command('SVUpdateIndex', function()
  require('neosystemverilog.parser').update_index()
end, {
  desc = 'Update SystemVerilog project index',
})

-- show module hierarchy
vim.api.nvim_create_user_command('SVShowHierarchy', function()
  require('neosystemverilog.navigation').show_hierarchy()
end, {
  desc = 'Show module hierarchy',
})

vim.api.nvim_create_user_command('SVElaborate', function(opts)
  require('neosystemverilog.utils').show_float({
    'Parsing starting!',
  }, 'Parse Summary')
  local parser = require('neosystemverilog.parser')
  local file = opts.args ~= '' and opts.args or nil
  local result = parser.elaborate(file)
  parser.show_elaboration_results(result)
end, {
  nargs = '?',
  complete = 'file',
  desc = 'Elaborate SystemVerilog design hierarchy',
})

vim.api.nvim_create_user_command('SVElaborateQuiet', function(opts)
  local parser = require('neosystemverilog.parser')
  local file = opts.args ~= '' and opts.args or nil
  local result = parser.elaborate(file)
  
  print(string.format('Elaborated: %d files, %d modules', 
    #result.files, vim.tbl_count(result.modules)))
end, {
  nargs = '?',
  complete = 'file',
  desc = 'Elaborate SystemVerilog design (quiet mode)',
})


vim.api.nvim_create_user_command('SVCacheStats', function()
  local parser = require('neosystemverilog.parser')
  local cache = parser.cache
  
  print('=== NeoSystemVerilog Cache Statistics ===')
  print(string.format('Modules: %d', vim.tbl_count(cache.modules)))
  for k, v in pairs(cache.modules) do
    print(string.format("\t%s in file: %s", k, v.file))
    if table.getn(v.ports) ~= 0 then
      for port in v.ports do
        print(string.format("\t\t%s",  port.name))
      end
    end
  end
  print(string.format('Interfaces: %d', vim.tbl_count(cache.interfaces)))
  print(string.format('Structs: %d', vim.tbl_count(cache.structs)))
  print(string.format('Typedefs: %d', vim.tbl_count(cache.typedefs)))
  print(string.format('Files indexed: %d', vim.tbl_count(cache.files)))
end, {
  desc = 'Show SystemVerilog index cache statistics',
})

vim.api.nvim_create_user_command('SVCacheClear', function()
  local parser = require('neosystemverilog.parser')
  parser.cache = {
    modules = {},
    interfaces = {},
    structs = {},
    typedefs = {},
    files = {},
  }
  parser._save_cache_to_disk()
  print('Cache cleared')
end, {
  desc = 'Clear SystemVerilog index cache',
})



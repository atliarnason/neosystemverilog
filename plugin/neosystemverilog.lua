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
vim.api.nvim_create_user_command('SVInstantiate', function(opts)
  require('neosystemverilog.instantiate').instantiate_module(opts.args)
end, {
  nargs = '?',
  desc = 'Instantiate a SystemVerilog module',
  complete = function()
    return require('neosystemverilog.instantiate').get_module_list()
  end,
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



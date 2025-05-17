vim.cmd('set rtp+=./deps/mini.nvim')
vim.cmd('set rtp+=.')

require('mini.test').setup({
  collect = {
    find_files = function()
      return vim.fn.globpath('tests', '**/*_spec.lua', true, true)
    end,
  },
})

require('fateweaver').setup({
  max_changes_in_context = 5,
  max_tracked_buffers = 3,
})

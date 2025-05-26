local logger = require("fateweaver.logger")
local config = require("fateweaver.config")
local changes = require("fateweaver.changes")
local debouncer = require("fateweaver.debouncer")
local completer = require("fateweaver.completer")

local function is_real_file(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  local filename = vim.api.nvim_buf_get_name(bufnr)
  if filename == "" then
    return false
  end

  local buf_type = vim.bo[bufnr].buftype
  if buf_type ~= "" then
    return false
  end

  local filetype = vim.bo[bufnr].filetype
  local skip_filetypes = {
    "qf", "help", "terminal", "oil", "fugitive", "NvimTree",
    "TelescopePrompt", "dirvish", "netrw"
  }

  for _, ft in ipairs(skip_filetypes) do
    if filetype == ft then
      return false
    end
  end

  return true
end

local M = {}

function M.setup()
  vim.api.nvim_create_autocmd({ "BufEnter" }, {
    pattern = "*",
    callback = function(args)
      if is_real_file(args.buf) then
        changes.cache_buffer(args.buf)
      end
    end
  })

  vim.api.nvim_create_autocmd({ "BufLeave" }, {
    pattern = "*",
    callback = function(args)
      if is_real_file(args.buf) then
        debouncer.cancel(args.buf)
        completer.clear()
      end
    end
  })

  vim.api.nvim_create_autocmd("InsertLeave", {
    pattern = "*",
    callback = function(args)
      if is_real_file(args.buf) then
        changes.save_change(args.buf)
      end
    end
  })

  vim.api.nvim_create_autocmd("TextChanged", {
    pattern = "*",
    callback = function(args)
      if is_real_file(args.buf) then
        changes.save_change(args.buf)
      end
    end
  })

  vim.api.nvim_create_autocmd("TextChangedI", {
    pattern = "*",
    callback = function(args)
      if is_real_file(args.buf) then
        local debounce_time = config.get().debounce_ms
        local bufnr = args.buf
        debouncer.debounce(debounce_time, args.buf, function()
          local additional_change = changes.calculate_change(args.buf)
          completer.propose_completions(bufnr, additional_change)
        end)
      end
    end
  })

  logger.debug("Change tracking autocommands created")
end

return M

local logger = require("fateweaver.logger")
local config = require("fateweaver.config")
local changes = require("fateweaver.changes")
local debouncer = require("fateweaver.debouncer")
local completer = require("fateweaver.completer")

local function is_buffer_supported(bufnr)
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

local function checked_callback(callback)
  return function(args)
    if is_buffer_supported(args.buf) then
      callback(args)
    end
  end
end

local M = {}

function M.setup()
  vim.api.nvim_create_autocmd({ "BufEnter" }, {
    pattern = "*",
    callback = checked_callback(function(args)
      changes.track_buffer(args.buf)
    end)
  })

  vim.api.nvim_create_autocmd({ "BufLeave", "InsertLeave" }, {
    pattern = "*",
    callback = checked_callback(function(args)
      debouncer.cancel(args.buf)
      completer.clear()
    end)
  })

  vim.api.nvim_create_autocmd("InsertLeave", {
    pattern = "*",
    callback = checked_callback(function(args)
      changes.save_change(args.buf)
    end)
  })

  vim.api.nvim_create_autocmd("TextChanged", {
    pattern = "*",
    callback = checked_callback(function(args)
      changes.save_change(args.buf)
    end)
  })

  vim.api.nvim_create_autocmd({ "TextChangedP", "TextChangedI" }, {
    pattern = "*",
    callback = checked_callback(function(args)
      if vim.g.fateweaver_pause_completion then
        vim.g.fateweaver_pause_completion = false
        return
      end

      local debounce_time = config.get().debounce_ms
      local bufnr = args.buf
      debouncer.debounce(debounce_time, args.buf, function()
        local additional_change = changes.calculate_change(args.buf)
        completer.propose_completions(bufnr, additional_change)
      end)
    end)
  })

  logger.debug("Change tracking autocommands created")
end

return M

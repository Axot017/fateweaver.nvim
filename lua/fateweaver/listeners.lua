---@type fateweaver.Logger
local logger = require("fateweaver.logger")
---@type fateweaver.Changes
local changes = require("fateweaver.changes")
---@type fateweaver.CompletionEngine
local completion_engine = require("fateweaver.completion_engine")

---Determines if a buffer should be processed for completions
---@param bufnr? integer Buffer number to check, defaults to current buffer
---@return boolean supported Whether the buffer is supported for completion
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

---Wraps a callback with buffer support check
---@param callback fun(args: table): any The callback function to wrap
---@return fun(args: table): any wrapped_callback The wrapped callback function that only executes for supported buffers
local function checked_callback(callback)
  return function(args)
    if is_buffer_supported(args.buf) then
      callback(args)
    end
  end
end

---@class fateweaver.Listeners
---@field setup fun(): nil Initialize event listeners
local M = {}

---Sets up all event listeners for buffer changes and completion triggers
---@return nil
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
      completion_engine.clear()
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
      local bufnr = args.buf
      local additional_change = changes.calculate_change(args.buf)
      completion_engine.propose_completions(bufnr, additional_change)
    end)
  })

  logger.debug("Change tracking autocommands created")
end

return M

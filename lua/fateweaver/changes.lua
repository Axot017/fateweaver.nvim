---@type fateweaver.Logger
local logger = require("fateweaver.logger")
---@type fateweaver.Config
local config = require("fateweaver.config")

---@class fateweaver.Changes
---@field save_change fun(bufnr: integer): nil
---@field get_diffs fun(bufnr: integer): Changes
---@field init_buffer fun(bufnr: integer)
local M = {}

---@class Changes
---@field filename string The full path of the file
---@field diff string The diff between previous and current state
---@field timestamp number Unix timestamp when the change was recorded
---@field bufnr number The buffer number associated with this change

---@class HistoricalFileContent
---@field filename string The full path of the file
---@field content string[] The content of the file
---@field timestamp number Unix timestamp when the change was recorded
---@field bufnr number The buffer number associated with this change

local historical_contents = {}

--- Trims the history for a specific file to stay within configured limits
---@param filename string The filename to trim history for
local function trim_historical_content(filename)
  local max_changes = config.get().context_opts.max_history_per_buffer

  while #historical_contents[filename] > max_changes do
    table.remove(historical_contents[filename], 1)
  end
end

--- Manages the number of tracked buffers, removing the oldest ones when limit is exceeded
local function trim_tracked_buffers()
  local max_tracked_buffers = config.get().context_opts.max_tracked_buffers
  if #historical_contents > max_tracked_buffers then
    local oldest_change = nil
    for _, changes in pairs(historical_contents) do
      for _, change_in_buffer in pairs(changes) do
        if oldest_change == nil or change_in_buffer.timestamp < oldest_change.timestamp then
          oldest_change = change_in_buffer
        end
      end
    end
    historical_contents[oldest_change.filename] = nil
  end
end

--- Saves a change for the specified buffer and updates the buffer cache.
--- Manages history size according to configuration limits.
---@param bufnr number|nil Buffer number (defaults to current buffer if nil)
function M.save_change(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local filename = vim.api.nvim_buf_get_name(bufnr)

  if filename == "" then
    logger.log("No filename associated with buffer " .. bufnr, "warn")
    return
  end

  local current_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

  local historical_content = historical_contents[filename]
  if historical_content == nil then
    historical_content = {}
    historical_contents[filename] = historical_content
  end

  table.insert(historical_content, {
    filename = filename,
    content = current_lines,
    timestamp = os.time(),
    bufnr = bufnr,
  })
  historical_contents[filename] = historical_content

  trim_historical_content(filename)

  trim_tracked_buffers()
end

---@return Changes|nil
function M.get_diffs(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local filename = vim.api.nvim_buf_get_name(bufnr)
  local current_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local current_lines_string = table.concat(current_lines, "\n") .. "\n"

  local historical_content = historical_contents[filename]
  if historical_content == nil then
    return nil
  end

  local oldest_change = historical_content[1]

  if oldest_change == nil then
    return nil
  end

  local previous_lines_string = table.concat(oldest_change.content, "\n") .. "\n"
  local diffs = vim.diff(previous_lines_string, current_lines_string, { ctxlen = 3 })

  return {
    filename = filename,
    diff = diffs,
    timestamp = os.time(),
    bufnr = bufnr,
  }
end

function M.init_buffer(bufnr)
  local filename = vim.api.nvim_buf_get_name(bufnr)
  local historical_content = historical_contents[filename]
  if historical_content == nil then
    local current_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    historical_content = { {
      filename = filename,
      content = current_lines,
      timestamp = os.time(),
      bufnr = bufnr,
    } }
    historical_contents[filename] = historical_content
  end
end

return M

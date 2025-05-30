---@type fateweaver.Logger
local logger = require("fateweaver.logger")
---@type fateweaver.Config
local config = require("fateweaver.config")

---@class fateweaver.Changes
---@field track_buffer fun(bufnr: integer): nil
---@field save_change fun(bufnr: integer): nil
---@field calculate_change fun(bufnr: integer): Change
local M = {}

---@class Change
---@field filename string The full path of the file
---@field diff string The diff between previous and current state
---@field timestamp number Unix timestamp when the change was recorded
---@field bufnr number The buffer number associated with this change

local changes_history = {}
local tracked_buffers = {}

--- Trims the history for a specific file to stay within configured limits
---@param filename string The filename to trim history for
local function trim_changes_history(filename)
  local max_changes = config.get().context_opts.max_history_per_buffer

  while #changes_history[filename] > max_changes do
    table.remove(changes_history[filename], 1)
  end
end

--- Manages the number of tracked buffers, removing the oldest ones when limit is exceeded
local function trim_tracked_buffers()
  local max_tracked_buffers = config.get().context_opts.max_tracked_buffers
  if #changes_history > max_tracked_buffers then
    local oldest_change = nil
    for _, changes in pairs(changes_history) do
      for _, change_in_buffer in pairs(changes) do
        if oldest_change == nil or change_in_buffer.timestamp < oldest_change.timestamp then
          oldest_change = change_in_buffer
        end
      end
    end
    changes_history[oldest_change.filename] = nil
    tracked_buffers[oldest_change.filename] = nil
  end
end

--- Calculates the diff between the current buffer state and its cached state.
--- Returns a change object containing the filename, diff, timestamp, and buffer number.
---@param bufnr number|nil Buffer number (defaults to current buffer if nil)
---@return Change|nil Change object or nil if no change detected
function M.calculate_change(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local filename = vim.api.nvim_buf_get_name(bufnr)

  if filename == "" or not tracked_buffers[filename] then
    logger.debug("Skipping change in unnamed buffer or buffer not tracked")
    return nil
  end

  local current_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local current_lines_string = table.concat(current_lines, "\n")

  local previous_lines = tracked_buffers[filename].lines
  local previous_lines_string = table.concat(previous_lines, "\n")


  local diff = vim.diff(previous_lines_string, current_lines_string)

  if diff == nil or #diff == 0 then
    return nil
  end

  logger.debug("Calculated diff for " .. filename .. ":\n" .. diff)

  return {
    filename = filename,
    diff = diff,
    timestamp = os.time(),
    bufnr = bufnr
  }
end

--- Starts tracking of a buffer state for future diff calculations.
--- Stores the buffer's lines, filename, and timestamp.
---@param bufnr number|nil Buffer number (defaults to current buffer if nil)
function M.track_buffer(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local filename = vim.api.nvim_buf_get_name(bufnr)

  if filename == "" then
    return
  end

  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

  tracked_buffers[filename] = {
    filename = filename,
    lines = lines,
    timestamp = os.time()
  }

  logger.debug("Tracked buffer " .. bufnr .. " (" .. filename .. ")" .. " with " .. #lines .. " lines")
end

--- Saves a change for the specified buffer and updates the buffer cache.
--- Manages history size according to configuration limits.
---@param bufnr number|nil Buffer number (defaults to current buffer if nil)
function M.save_change(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local new_change = M.calculate_change(bufnr)

  if new_change == nil then
    return
  end

  if changes_history[new_change.filename] == nil then
    changes_history[new_change.filename] = {}
  end

  table.insert(changes_history[new_change.filename], new_change)

  logger.debug("Recorded change:\n" .. vim.inspect(new_change))

  trim_changes_history(new_change.filename)

  local filename = vim.api.nvim_buf_get_name(bufnr)

  local current_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

  tracked_buffers[filename] = {
    filename = filename,
    lines = current_lines,
    timestamp = os.time()
  }

  trim_tracked_buffers()
end

--- Returns all recorded diffs for a specific buffer.
---@param bufnr number|nil Buffer number (defaults to current buffer if nil)
---@return Change[] Array of change objects for the specified buffer
function M.get_buffer_diffs(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local filename = vim.api.nvim_buf_get_name(bufnr)
  if changes_history[filename] == nil then
    return {}
  end

  local diffs = {}
  for _, change in pairs(changes_history[vim.api.nvim_buf_get_name(bufnr)]) do
    if change.bufnr == bufnr then
      table.insert(diffs, change)
    end
  end

  return diffs
end

--- Returns all recorded diffs across all tracked buffers.
---@return Change[] Array of change objects, each containing filename, diff, timestamp, and bufnr
function M.get_all_diffs()
  local diffs = {}
  for _, change in pairs(changes_history) do
    for _, change_in_buffer in pairs(change) do
      table.insert(diffs, change_in_buffer)
    end
  end

  return diffs
end

return M

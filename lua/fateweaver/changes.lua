local logger = require("fateweaver.logger")
local config = require("fateweaver.config")

local M = {}

local changes_history = {}
local buffer_cache = {}

function M.calculate_change(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local filename = vim.api.nvim_buf_get_name(bufnr)

  if filename == "" or not buffer_cache[filename] then
    logger.debug("Skipping change in unnamed buffer or no cache exists")
    return
  end

  local current_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local current_lines_string = table.concat(current_lines, "\n")

  local previous_lines = buffer_cache[filename].lines
  local previous_lines_string = table.concat(previous_lines, "\n")


  local diff = vim.diff(previous_lines_string, current_lines_string)

  if diff == nil or #diff == 0 then
    return
  end

  logger.debug("Calculated diff for " .. filename .. ":\n" .. diff)

  return {
    filename = filename,
    diff = diff,
    timestamp = os.time(),
    bufnr = bufnr
  }
end

function M.cache_buffer(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local filename = vim.api.nvim_buf_get_name(bufnr)

  if filename == "" then
    return
  end

  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

  buffer_cache[filename] = {
    filename = filename,
    lines = lines,
    timestamp = os.time()
  }

  logger.debug("Cached buffer " .. bufnr .. " (" .. filename .. ")" .. " with " .. #lines .. " lines")
end

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
  local max_changes = config.get().max_changes_in_context

  if #changes_history[new_change.filename] > max_changes then
    table.remove(changes_history[new_change.filename], 1)
  end

  local filename = vim.api.nvim_buf_get_name(bufnr)

  local current_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

  buffer_cache[filename] = {
    filename = filename,
    lines = current_lines,
    timestamp = os.time()
  }

  local max_tracked_buffers = config.get().max_tracked_buffers
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
    buffer_cache[oldest_change.filename] = nil
  end
end

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

local logger = require("fateweaver.logger")
local config = require("fateweaver.config")

local M = {}

local changes_history = {}
local buffer_cache = {}

local function calculate_change(bufnr)
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


  local diff = vim.diff(previous_lines_string, current_lines_string, {
    ctxlen = 2,
  })

  if diff == nil or #diff == 0 then
    return
  end

  logger.debug("Calculated diff for " .. filename .. ": " .. vim.inspect(diff))

  return {
    filename = filename,
    diff = diff,
    timestamp = os.time(),
    bufnr = bufnr
  }
end

function M.setup()
  vim.api.nvim_create_autocmd({ "BufReadPost", "BufNewFile" }, {
    pattern = "*",
    callback = function(args)
      M.cache_buffer(args.buf)
    end
  })

  vim.api.nvim_create_autocmd("InsertLeave", {
    pattern = "*",
    callback = function(args)
      M.record_change(args.buf)
    end
  })

  vim.api.nvim_create_autocmd("TextChanged", {
    pattern = "*",
    callback = function(args)
      M.record_change(args.buf)
    end
  })

  logger.debug("Change tracking autocommands created")
end

-- Cache the current state of a buffer
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

function M.record_change(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local new_change = calculate_change(bufnr)

  if new_change == nil then
    return
  end

  if changes_history[new_change.filename] == nil then
    changes_history[new_change.filename] = {}
  end

  table.insert(changes_history[new_change.filename], new_change)

  logger.debug("Recorded change: " .. vim.inspect(new_change))
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
    for _, changes in ipairs(changes_history) do
      for _, change_in_buffer in ipairs(changes) do
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

  local diffs = {}
  for _, change in ipairs(changes_history[vim.api.nvim_buf_get_name(bufnr)]) do
    if change.bufnr == bufnr then
      table.insert(diffs, change)
    end
  end
end

function M.get_all_diffs()
  local diffs = {}
  for _, change in ipairs(changes_history) do
    table.insert(diffs, change)
  end

  return diffs
end

return M

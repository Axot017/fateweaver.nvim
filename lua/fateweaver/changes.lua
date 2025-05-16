local logger = require("fateweaver.logger")

local M = {}

local changes_history = {}
local buffer_cache = {}

local function calculate_change(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local filename = vim.api.nvim_buf_get_name(bufnr)

  if filename == "" or not buffer_cache[bufnr] then
    logger.debug("Skipping change in unnamed buffer or no cache exists")
    return
  end

  local current_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local current_lines_string = table.concat(current_lines, "\n")

  local previous_lines = buffer_cache[bufnr].lines
  local previous_lines_string = table.concat(previous_lines, "\n")


  local diff = vim.diff(previous_lines_string, current_lines_string, {
    result_type = 'indices'
  })

  if diff == nil or #diff == 0 then
    return
  end

  logger.debug("Calculated diff for " .. filename .. ": " .. vim.inspect(diff))

  local diffs = {}

  for _, change in diff do
    table.insert(diffs, {
      filename = filename,
      diff = change,
      timestamp = os.time(),
      bufnr = bufnr
    })
  end

  return diffs
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

  buffer_cache[bufnr] = {
    filename = filename,
    lines = lines,
    timestamp = os.time()
  }

  logger.debug("Cached buffer " .. bufnr .. " (" .. filename .. ")" .. " with " .. #lines .. " lines")
end

function M.record_change(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local new_changes = calculate_change(bufnr)

  for _, change in new_changes do
    table.insert(changes_history, change)
  end

  logger.debug("Recorded change: " .. vim.inspect(new_changes))

  local filename = vim.api.nvim_buf_get_name(bufnr)

  local current_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

  buffer_cache[bufnr] = {
    filename = filename,
    lines = current_lines,
    timestamp = os.time()
  }
end

return M

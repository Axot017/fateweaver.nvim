local logger = require("fateweaver.logger")

local function slice_table(table, start, stop)
  local sliced = {}
  for i = start, stop do
    sliced[i - start + 1] = table[i]
  end
  return sliced
end

local M = {}

local changes_history = {}
local buffer_cache = {}

function M.setup()
  vim.api.nvim_create_autocmd({ "BufReadPost", "BufNewFile" }, {
    pattern = "*",
    callback = function(args)
      M.cache_buffer(args.buf)
    end
  })

  vim.api.nvim_create_autocmd("InsertEnter", {
    pattern = "*",
    callback = function(args)
      M.cache_buffer(args.buf)
    end
  })

  vim.api.nvim_create_autocmd("TextChanged", {
    pattern = "*",
    callback = function(args)
      M.record_change_instant(args.buf)
    end
  })

  vim.api.nvim_create_autocmd("TextChangedI", {
    pattern = "*",
    callback = function(args)
      -- M.record_change(args.buf)
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

function M.record_change_instant(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local filename = vim.api.nvim_buf_get_name(bufnr)

  if filename == "" or not buffer_cache[bufnr] then
    logger.debug("Skipping change in unnamed buffer or no cache exists")
    return
  end

  local current_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local current_length = #current_lines

  local previous_lines = buffer_cache[bufnr].lines
  local previous_length = #previous_lines

  local max_length = math.max(current_length, previous_length)

  local change_begin = -1
  local changed_from = {}

  local change_end = -1
  local changed_to = {}

  for i = 1, max_length do
    if current_lines[i] ~= previous_lines[i] then
      change_begin = i
      break
    end
  end

  if change_begin == -1 then
    return
  end

  for j = change_begin, current_length do
    if previous_lines[change_begin] == current_lines[j] then
      change_end = j
      changed_from = slice_table(previous_lines, change_begin, change_begin)
      changed_to = slice_table(current_lines, change_begin, j)
      break
    end
  end

  for j = change_begin, previous_length do
    if current_lines[change_begin] == previous_lines[j] then
      change_end = j
      changed_from = slice_table(previous_lines, change_begin, j)
      changed_to = slice_table(current_lines, change_begin, change_begin)
      break
    end
  end

  for j = change_begin, max_length do
    if previous_lines[j] == current_lines[j] then
      change_end = j
      changed_from = slice_table(previous_lines, change_begin, j - 1)
      changed_to = slice_table(current_lines, change_begin, j - 1)
      break
    end
  end


  changes_history[#changes_history + 1] = {
    filename = filename,
    change_begin = change_begin,
    change_end = change_end,
    changed_from = changed_from,
    changed_to = changed_to,
    timestamp = os.time()
  }

  buffer_cache[bufnr] = {
    filename = filename,
    lines = current_lines,
    timestamp = os.time()
  }
end

return M

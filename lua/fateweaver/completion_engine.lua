---@type fateweaver.Changes
local changes = require("fateweaver.changes")
---@type fateweaver.Logger
local logger = require("fateweaver.logger")
---@type fateweaver.Debouncer
local debouncer = require("fateweaver.debouncer")
---@type fateweaver.Config
local config = require("fateweaver.config")

---@class fateweaver.Client
---@field request_completion fun(bufnr: integer, changes: Changes, callback: fun(completions: Completion[])): nil
---@field cancel_request fun(): nil

---@class fateweaver.UI
---@field show_inline_completions fun(bufnr: integer, lines: string[]): nil
---@field show_addition fun(bufnr: integer, position: integer, lines: string[]): nil
---@field show_deletion fun(bufnr: integer, from: integer, to: integer): nil
---@field show_diff fun(bufnr: integer, from: integer, to: integer, lines: string[]): nil
---@field clear fun(bufnr: integer): nil

---@class Completion
---@field search string
---@field replace string

local accepted_completions = 0

local active_bufnr = -1
---@type Completion[]
local active_completions = {}

---@class fateweaver.CompletionEngine
---@field on_insert fun(bufnr: integer): nil
---@field clear fun(): nil
---@field set_active_buffer fun(bufnr: integer): nil
---@field setup fun(ui: fateweaver.UI, client: fateweaver.Client)
---@field request_completion fun(bufnr: integer)
local M = {}

---@param ui fateweaver.UI
---@param client fateweaver.Client
---@return nil
function M.setup(ui, client)
  M.ui = ui
  M.client = client
end

function M.show_next_completion(bufnr)
  if #active_completions == 0 then
    logger.info("No more completions to show")
    return
  end

  logger.debug("Showing completion")

  local completion = active_completions[1]
  if not completion then
    logger.info("No completion found")
    return
  end

  local search_lines = vim.split(completion.search, "\n")
  local replace_lines = vim.split(completion.replace, "\n")

  local buf_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local found_line = nil

  for i = 1, #buf_lines - #search_lines + 1 do
    local match = true
    for j = 1, #search_lines do
      if buf_lines[i + j - 1] ~= search_lines[j] then
        match = false
        break
      end
    end
    if match then
      found_line = i
      break
    end
  end

  logger.debug("Found line: " .. (found_line or "nil"))

  if not found_line then
    logger.debug("Search block not found in buffer")
    return
  end

  local lines_removed_from_start = 0
  while #search_lines > 0 and #replace_lines > 0 and search_lines[1] == replace_lines[1] do
    table.remove(search_lines, 1)
    table.remove(replace_lines, 1)
    lines_removed_from_start = lines_removed_from_start + 1
  end

  local lines_removed_from_end = 0
  while #search_lines > 0 and #replace_lines > 0 and search_lines[#search_lines] == replace_lines[#replace_lines] do
    table.remove(search_lines)
    table.remove(replace_lines)
    lines_removed_from_end = lines_removed_from_end + 1
  end

  local adjusted_from = found_line + lines_removed_from_start
  local adjusted_to = found_line + #vim.split(completion.search, "\n") - 1 - lines_removed_from_end

  local search_line_count = #search_lines
  local replace_line_count = #replace_lines

  if search_line_count == 1 and replace_line_count >= 1 then
    local cursor_pos = vim.api.nvim_win_get_cursor(0)
    local cursor_line = cursor_pos[1]
    local cursor_col = cursor_pos[2]

    if cursor_line == adjusted_from then
      local current_line = vim.api.nvim_buf_get_lines(bufnr, cursor_line - 1, cursor_line, false)[1] or ""
      local chars_up_to_cursor = current_line:sub(1, cursor_col)
      local search_prefix = search_lines[1]:sub(1, cursor_col)

      if chars_up_to_cursor == search_prefix then
        M.ui.show_inline_completions(bufnr, replace_lines)
        return
      end
    end
  end

  if search_line_count == 0 then
    M.ui.show_addition(bufnr, adjusted_from, replace_lines)
    return
  end

  if replace_line_count == 0 then
    M.ui.show_deletion(bufnr, adjusted_from, adjusted_to)
    return
  end

  M.ui.show_diff(bufnr, adjusted_from, adjusted_to, replace_lines)
end

---@param bufnr integer
---@param completion Completion
---@return nil
function M.apply_completion(bufnr, completion)
  local search_lines = vim.split(completion.search, "\n")
  local replace_lines = vim.split(completion.replace, "\n")

  local buf_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local found_line = nil

  for i = 1, #buf_lines - #search_lines + 1 do
    local match = true
    for j = 1, #search_lines do
      if buf_lines[i + j - 1] ~= search_lines[j] then
        match = false
        break
      end
    end
    if match then
      found_line = i
      break
    end
  end

  if not found_line then
    logger.debug("Search block not found in buffer for application")
    return
  end

  local start_line = found_line - 1
  local end_line = found_line + #search_lines - 1

  vim.api.nvim_buf_set_lines(bufnr, start_line, end_line, false, replace_lines)

  local last_line = start_line + #replace_lines
  local last_line_content = replace_lines[#replace_lines] or ""
  local last_col = #last_line_content

  vim.api.nvim_win_set_cursor(0, { last_line, last_col })

  logger.debug("Applied completion: replaced " .. #search_lines .. " lines with " .. #replace_lines .. " lines")
end

---@return nil
function M.accept_completion()
  local completion_idx = 1
  local completion = active_completions[completion_idx]
  if not completion then
    logger.info("No completion to accept")
    return
  end

  logger.debug("Completion accepted")

  M.ui.clear(active_bufnr)

  accepted_completions = accepted_completions + 1
  table.remove(active_completions, 1)

  M.apply_completion(active_bufnr, completion)
end

---@param bufnr integer
---@return nil
function M.request_completion(bufnr)
  local diff = changes.get_diffs(bufnr)
  if diff == nil then
    logger.debug("No diff")
    return
  end

  M.client.request_completion(bufnr, diff, function(completions)
    if active_bufnr ~= bufnr then
      return
    end

    active_completions = completions
    M.show_next_completion(bufnr)
  end)
end

---@param bufnr integer
---@return nil
function M.on_insert(bufnr)
  local is_after_completion_accept = accepted_completions ~= 0

  local next_completion = active_completions[1]
  if next_completion ~= nil and bufnr == active_bufnr and is_after_completion_accept then
    accepted_completions = accepted_completions - 1
    M.show_next_completion(bufnr)
    return
  end

  if is_after_completion_accept then
    accepted_completions = accepted_completions - 1
  end

  M.clear()

  active_bufnr = bufnr
  local ms = config.get().debounce_ms

  debouncer.debounce(ms, active_bufnr, function()
    M.request_completion(bufnr)
  end)
end

---@return nil
function M.clear()
  M.client.cancel_request()
  if active_bufnr ~= nil then
    debouncer.cancel(active_bufnr)
    if #active_completions ~= 0 then
      M.ui.clear(active_bufnr)
      active_completions = {}
    end
  end
end

---@param bufnr integer
---@return nil
function M.set_active_buffer(bufnr)
  active_bufnr = bufnr
  changes.init_buffer(bufnr)
end

return M

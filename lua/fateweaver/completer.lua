local changes = require("fateweaver.changes")
local client = require("fateweaver.client")
local logger = require("fateweaver.logger")

local function get_editable_region()
  local win_top = vim.fn.line('w0')
  local win_bottom = vim.fn.line('w$')
  local editable_region = { start_line = win_top, end_line = win_bottom }
  return editable_region
end

local function get_editable_region_lines(bufnr, editable_region)
  local lines = vim.api.nvim_buf_get_lines(bufnr, editable_region.start_line - 1, editable_region.end_line, false)

  return lines
end

local request_bufnr = -1
local ns_id = vim.api.nvim_create_namespace("fateweaver_completions")

local function show_completions(bufnr, editable_region, diffs, current_lines, proposed_lines)
  vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)

  local cursor_position = vim.api.nvim_win_get_cursor(0)
  local cursor_line = cursor_position[1]
  local cursor_col = cursor_position[2]

  local cursor_line_in_region = cursor_line - editable_region.start_line + 1

  logger.debug("Cursor real line - " .. cursor_line .. " | Cursor in editable region - " .. cursor_line_in_region)
  for _, diff in ipairs(diffs) do
    local start_line = diff[1]
    if start_line == cursor_line_in_region then
      local original = current_lines[start_line]
      local proposed = proposed_lines[start_line]
      for i = 1, cursor_col do
        local o = original:sub(i, i)
        local p = proposed:sub(i, i)
        logger.debug(o .. " = " .. p .. "?")
        if o ~= p then
          logger.debug("Lines not equal escaping to git diff")
          goto diff
        end
      end
      logger.debug("Showing diff as virtual text behind cursor")
      return
    end
  end

  ::diff::

  logger.debug("Showing diff as as git diff")


  -- for _, diff in ipairs(diffs) do
  --   local start_line_abs = diff[1] + editable_region.start_line - 1
  --   local count_old = diff[2]
  --   local start_line_new = diff[3]
  --   local count_new = diff[4]
  --
  --   if start_line_abs == cursor_line and count_old == 0 and count_new > 0 then
  --     local current_line = current_lines[cursor_line_in_region] or ""
  --     local proposed_line = proposed_lines[start_line_new] or ""
  --
  --     if cursor_col <= #current_line and
  --         string.sub(current_line, 1, cursor_col) == string.sub(proposed_line, 1, cursor_col) then
  --       local ghost_text = string.sub(proposed_line, cursor_col + 1)
  --       if ghost_text ~= "" then
  --         vim.api.nvim_buf_set_extmark(bufnr, ns_id, cursor_line - 1, cursor_col, {
  --           virt_text = { { ghost_text, "Comment" } },
  --           virt_text_pos = "inline"
  --         })
  --       end
  --     else
  --       for i = 1, count_new do
  --         local line_idx = start_line_new + i - 1
  --         if proposed_lines[line_idx] then
  --           vim.api.nvim_buf_set_extmark(bufnr, ns_id, start_line_abs - 1, 0, {
  --             virt_text = { { "+ " .. proposed_lines[line_idx], "DiffAdd" } },
  --             virt_text_pos = "overlay"
  --           })
  --         end
  --       end
  --     end
  --   elseif count_old > 0 and count_new > 0 then
  --     for i = 1, count_old do
  --       local line_abs = start_line_abs + i - 1
  --       vim.api.nvim_buf_set_extmark(bufnr, ns_id, line_abs - 1, 0, {
  --         line_hl_group = "DiffDelete"
  --       })
  --     end
  --
  --     for i = 1, count_new do
  --       local line_idx = start_line_new + i - 1
  --       if proposed_lines[line_idx] then
  --         vim.api.nvim_buf_set_extmark(bufnr, ns_id, start_line_abs - 1, 0, {
  --           virt_text = { { "+ " .. proposed_lines[line_idx], "DiffAdd" } },
  --           virt_text_pos = "overlay"
  --         })
  --       end
  --     end
  --   elseif count_old > 0 and count_new == 0 then
  --     for i = 1, count_old do
  --       local line_abs = start_line_abs + i - 1
  --       vim.api.nvim_buf_set_extmark(bufnr, ns_id, line_abs - 1, 0, {
  --         line_hl_group = "DiffDelete"
  --       })
  --     end
  --   elseif count_old == 0 and count_new > 0 then
  --     for i = 1, count_new do
  --       local line_idx = start_line_new + i - 1
  --       if proposed_lines[line_idx] then
  --         vim.api.nvim_buf_set_extmark(bufnr, ns_id, start_line_abs - 1, 0, {
  --           virt_text = { { "+ " .. proposed_lines[line_idx], "DiffAdd" } },
  --           virt_text_pos = "overlay"
  --         })
  --       end
  --     end
  --   end
  -- end
end

local M = {}

function M.propose_completions(bufnr, additional_diff)
  request_bufnr = bufnr
  local diffs = changes.get_buffer_diffs(bufnr)
  if additional_diff then
    table.insert(diffs, additional_diff)
  end
  local cursor_pos = vim.api.nvim_win_get_cursor(0)
  local editable_region = get_editable_region()


  client.request_completion(bufnr, editable_region, cursor_pos, diffs, function(completions)
    if request_bufnr ~= bufnr then
      return
    end

    local editable_region_lines = get_editable_region_lines(bufnr, editable_region)
    local editable_region_lines_str = table.concat(editable_region_lines, "\n")
    logger.debug("Current editable region:\n" .. editable_region_lines_str)

    local completions_str = table.concat(completions, "\n")
    logger.debug("Proposed editable region:\n" .. completions_str)

    local diff = vim.diff(editable_region_lines_str, completions_str, {
      result_type = "indices"
    })

    if diff == nil or #diff == 0 then
      return
    end

    logger.debug("Diff:\n" .. vim.inspect(diff))

    show_completions(bufnr, editable_region, diff, editable_region_lines, completions)
  end)
end

function M.clear()
  if request_bufnr ~= -1 then
    vim.api.nvim_buf_clear_namespace(request_bufnr, ns_id, 0, -1)
  end
end

return M

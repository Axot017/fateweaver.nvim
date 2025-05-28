local config = require("fateweaver.config")
local logger = require("fateweaver.logger")
local prompt_handler = require("fateweaver.zeta.prompt_handler")
local curl_ok, curl = pcall(require, "plenary.curl")

if not curl_ok then
  vim.notify("Failed to load plenary.curl", vim.log.levels.ERROR)
  return
end

local request_job = nil
local job_id = 0

local M = {}

local current_job_id = job_id
---@param bufnr number The buffer number to get completion for
---@param editable_region EditableRegion Region that can be edited {start_line, end_line}
---@param cursor_pos table Current cursor position {line, col}
---@param changes Change[] Array of recorded changes to provide as context
---@param callback function Function to call with completion results
function M.request_completion(bufnr, editable_region, cursor_pos, changes, callback)
  local url = config.get().endpoint
  local model = config.get().model
  local body = {
    model = model,
    prompt = prompt_handler.get_prompt(bufnr, editable_region, cursor_pos, changes),
    stream = false,
  }

  logger.debug("Requesting completion")

  if request_job ~= nil then
    request_job:shutdown()
  end

  job_id = job_id + 1
  local current_job_id = job_id

  request_job = curl.post(url, {
    body = vim.json.encode(body),
    headers = {
      content_type = "application/json",
    },
    callback = function(res)
      if res.status ~= 200 then
        logger.warn("Received error: " .. vim.inspect(res))
      end

      local reponse_body = vim.json.decode(res.body)
      local response = reponse_body["response"]
      local proposed_completions = prompt_handler.get_completion_lines(response)

      if current_job_id == job_id then
        request_job = nil
      end
      vim.schedule(function()
        callback(proposed_completions)
      end)
    end,
    on_error = function(err)
      if err.exit ~= 0 then
        logger.warn("Received error: " .. vim.inspect(err))
      end
      logger.debug("Request previous cancelled")
      if current_job_id == job_id then
        request_job = nil
      end
    end
  })
end

return M

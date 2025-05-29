---@type fateweaver.Config
local config = require("fateweaver.config")
---@type fateweaver.Logger
local logger = require("fateweaver.logger")
---@type fateweaver.zeta.PromptHandler
local prompt_handler = require("fateweaver.zeta.prompt_handler")
local curl_ok, curl = pcall(require, "plenary.curl")

if not curl_ok then
  vim.notify("Failed to load plenary.curl", vim.log.levels.ERROR)
  return
end

---@type table|nil Current request job
local request_job = nil
---@type integer Unique ID for tracking request jobs
local job_id = 0

local M = {}

---Makes a request to the completion API
---@param bufnr integer The buffer number to get completion for
---@param editable_region EditableRegion Region that can be edited {start_line, end_line}
---@param cursor_pos table Current cursor position {line, col}
---@param changes Change[] Array of recorded changes to provide as context
---@param callback fun(completions: string[]) Function to call with completion results
---@return nil
function M.request_completion(bufnr, editable_region, cursor_pos, changes, callback)
  local url = config.get().endpoint
  local model = config.get().model
  local body = {
    model = model,
    prompt = prompt_handler.get_prompt(bufnr, editable_region, cursor_pos, changes),
    stream = false,
    temperature = 0,
    stop = { "<|editable_region_end|>" }
  }

  logger.debug("Requesting completion")

  if request_job ~= nil then
    request_job:shutdown()
    request_job = nil
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
      local response = reponse_body.choices[1].text
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
    end
  })
end

--- Cancels any in-flight completion request
---@return nil
function M.cancel_request()
  if request_job ~= nil then
    logger.debug("Cancelling in-flight request")
    request_job:shutdown()
    request_job = nil
  end
end

return M

local config = require("fateweaver.config")
local logger = require("fateweaver.logger")
local curl_ok, curl = pcall(require, "plenary.curl")

if not curl_ok then
  vim.notify("Failed to load plenary.curl", vim.log.levels.ERROR)
  return
end

local M = {}

function M.request_completion(prompt, callback)
  local url = config.get().endpoint
  local body = {
    model = "hf.co/bartowski/zed-industries_zeta-GGUF:Q5_K_M",
    prompt = prompt,
    stream = false,
  }

  logger.debug("Requesting completion")

  curl.post(url, {
    body = vim.json.encode(body),
    headers = {
      content_type = "application/json",
    },
    callback = function(res)
      if res.status ~= 200 then
        logger.warn("Received error: " .. vim.inspect(res))
      end

      local reponse_body = vim.json.decode(res.body)
      logger.debug(reponse_body["response"])
      callback(reponse_body)
    end
  })
end

return M

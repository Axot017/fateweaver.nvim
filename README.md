# fateweaver.nvim

A Neovim plugin that provides intelligent code completion and predicts future code changes using the local open-source Zeta LLM model from Zed Industries.

## Requirements

- **Neovim 0.8.0+**
- **Zeta LLM model**: The plugin requires a local Zeta model endpoint (default: `http://localhost:11434/v1/completions`)

## Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "Axot017/fateweaver.nvim",
  dependencies = { "nvim-lua/plenary.nvim" },
  config = function()
    require("fateweaver").setup({
      -- Configuration options (see below)
    })
  end,
}
```

### Using [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
  "Axot017/fateweaver.nvim",
  requires = { "nvim-lua/plenary.nvim" },
  config = function()
    require("fateweaver").setup()
  end
}
```

## Configuration

```lua
require("fateweaver").setup({
  -- Logging configuration
  log_level = "ERROR", -- "ERROR", "WARN", "INFO", "DEBUG"
  logger_fn = vim.notify,
  
  -- Context and tracking options
  context_opts = {
    max_tracked_buffers = 5,          -- Maximum number of buffers for which plugin will store changes history
    max_history_per_buffer = 3,       -- Maximum number of recent changes to keep in history per buffer
    context_before_cursor = 30,       -- Number of lines before cursor to include as context for the LLM
    context_after_cursor = 50,        -- Number of lines after cursor to include as context for the LLM
  },
  
  -- Zeta model configuration
  completion_endpoint = "http://localhost:11434/v1/completions",
  model_name = "hf.co/bartowski/zed-industries_zeta-GGUF:Q4_K_M",
  
  -- Performance options
  debounce_ms = 1000, -- Debounce time for completion requests
})
```

## Usage

### Basic Commands

```lua
-- Request completion for current buffer
require("fateweaver").request_completion()

-- Accept the current completion suggestion
require("fateweaver").accept_completion()

-- Dismiss the current completion
require("fateweaver").dismiss_completion()
```

### Key Mappings (Example)

```lua
-- Add these to your Neovim configuration
vim.keymap.set("n", "<leader>fc", require("fateweaver").request_completion, { desc = "Request completion" })
vim.keymap.set("i", "<C-y>", require("fateweaver").accept_completion, { desc = "Accept completion" })
vim.keymap.set("i", "<C-x>", require("fateweaver").dismiss_completion, { desc = "Dismiss completion" })
```

## Setting Up Zeta Model

The plugin requires a local server that serves the Zeta model via OpenAI-compatible API. Below is an example using Ollama, but you can use any method you prefer.

### Example: Using Ollama

1. **Install Ollama**: Follow the [Ollama installation guide](https://ollama.ai/)
2. **Download Zeta model**: 
   ```bash
   ollama pull hf.co/bartowski/zed-industries_zeta-GGUF:Q4_K_M
   ```
3. **Start Ollama server**:
   ```bash
   ollama serve
   ```

The plugin will automatically connect to the Ollama endpoint at `http://localhost:11434/v1/completions`.

### Alternative Methods

You can also use other inference engines that provide OpenAI-compatible APIs:

- **llama.cpp**
- **vLLM**
- **llamafile**
- **Any other OpenAI-compatible server**

Simply update the `completion_endpoint` in your configuration to point to your chosen inference server.

## Contributing

This project is in early development. Contributions, issues, and feature requests are welcome!

## License

MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- **Zed Industries** for the open-source Zeta LLM model
- **Cursor** for inspiration on AI-powered code editing

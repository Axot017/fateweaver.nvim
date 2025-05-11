# fateweaver.nvim

A Neovim plugin that provides intelligent code completion and predicts future code changes using the local open-source Zeta LLM model from Zed Industries.

## Description

Fateweaver is designed to enhance your coding experience in Neovim by offering:

- GitHub Copilot-like code completion suggestions
- Prediction of potential next changes you might want to make
- Fully local operation using the Zeta LLM model
- Privacy-focused approach with no data sent to external servers

## Status: Work in Progress

⚠️ **This project is currently under active development and is not yet ready for production use.**

Many features are still being implemented, and the API may change significantly before the first stable release.

## TODO List

- [ ] Set up basic plugin structure
- [ ] Store user edits for LLM context
- [ ] Implement Zeta LLM model integration
- [ ] Make requests to prediction endpoint
- [ ] Parse responses from LLM
- [ ] Calculate diffs between current code and predictions
- [ ] Allow users to apply suggested diffs
- [ ] Create completion provider interface
- [ ] Add configuration options for model parameters
- [ ] Implement context-aware suggestions
- [ ] Create UI for displaying suggestions
- [ ] Add keybindings for accepting/rejecting suggestions
- [ ] Write documentation and usage examples
- [ ] Performance optimization for large files
- [ ] Add tests

## Requirements

- Neovim 0.8.0+
- Zeta LLM model (installation instructions to be added)

## Installation

Coming soon...

## License

See the [LICENSE](LICENSE) file for details.

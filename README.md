# py-autodoc.nvim

## Overview
`py-autodoc.nvim` is a Neovim plugin designed to streamline Python development by automatically generating docstrings for your functions and methods. It supports various docstring formats, including NumPy, Google, and Sphinx, and (on Neovim ≥ 0.10) expands the generated docstring as a snippet so you can Tab through every placeholder.

## Demo

![demo gif](https://github.com/ok97465/py-autodoc.nvim/raw/main/doc/demo.gif)

## Features
- Automatic docstring generation for Python functions and methods.
- Supports NumPy, Google, and Sphinx docstring formats.
- Expands generated docstrings as Neovim snippets so you can jump across placeholders with `<Tab>` / `<S-Tab>`.
- Customizable to fit your preferred documentation style.
- Integrates seamlessly with Neovim for an enhanced development workflow.

## Installation

### Prerequisites
- Neovim 0.10 or newer to take advantage of the built-in snippet engine (`vim.snippet`).

> **Need to stay on an older Neovim?**
>
> Use the `nvim_0.10_below` tag/branch of this repository. It contains the pre-snippet version of the plugin that targets legacy releases.

### Using `lazy.nvim`

```lua
{
  'ok97465/py-autodoc.nvim',
  config = function()
    require('py-autodoc').setup({})
  end
}
```

## Usage

### Basic Usage
Place your cursor inside a Python function or method definition and run the command:

```
:PyAutoDoc
```

This will generate a docstring based on your configured `doc_style`.

### Configuration
You can configure `py-autodoc.nvim` by passing options to the `setup()` function.

| Option      | Type     | Default     | Description                                     |
|-------------|----------|-------------|-------------------------------------------------|
| `doc_style` | `string` | `'Googledoc'` | Docstring style (`'Numpydoc'`, `'Googledoc'`, `'Sphinxdoc'`). |
| `indent_chars` | `string` | `'    '` | Characters used for indentation within the docstring. |
| `include_type_hints` | `boolean` | `true` | Include type hints from the signature in the generated docstring. |
| `snippet_tab_jump` | `boolean` | `true` | Register `<Tab>` / `<S-Tab>` mappings that call `vim.snippet.jump()` while a docstring snippet is active. |

Example `setup` with custom options:

```lua
require('py-autodoc').setup({
  doc_style = 'Numpydoc',
  indent_chars = '  ',
  include_type_hints = false,
  snippet_tab_jump = false, -- keep your own Tab mapping (see below)
})
```

### Snippet navigation (Neovim ≥ 0.10)

- By default the plugin wires `<Tab>` / `<S-Tab>` in insert & select mode so you can jump across the generated docstring placeholders using the new `vim.snippet` API.
- If you already manage Tab mappings yourself, disable the built-in wiring via `snippet_tab_jump = false` and set up your preferred keys:

```lua
vim.keymap.set({ 'i', 's' }, '<C-j>', function()
  if vim.snippet.active({ direction = 1 }) then
    return '<Cmd>lua vim.snippet.jump(1)<CR>'
  end
  return '<C-j>'
end, { expr = true, silent = true })

vim.keymap.set({ 'i', 's' }, '<C-k>', function()
  if vim.snippet.active({ direction = -1 }) then
    return '<Cmd>lua vim.snippet.jump(-1)<CR>'
  end
  return '<C-k>'
end, { expr = true, silent = true })
```

When Neovim is compiled without the snippet engine (e.g. 0.9 or earlier), the plugin automatically falls back to inserting plain text docstrings so you can still use it without upgrading immediately.

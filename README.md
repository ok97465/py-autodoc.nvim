# py-autodoc.nvim

## Overview
`py-autodoc.nvim` is a Neovim plugin designed to streamline Python development by automatically generating docstrings for your functions and methods. It supports various docstring formats, including NumPy, Google, and Sphinx, helping you maintain consistent and well-documented Python code effortlessly.

## Features
- Automatic docstring generation for Python functions and methods.
- Supports NumPy, Google, and Sphinx docstring formats.
- Customizable to fit your preferred documentation style.
- Integrates seamlessly with Neovim for an enhanced development workflow.

## Installation

### Prerequisites
- Neovim (version 0.7 or higher recommended)
- Python 3
- `pynvim` Python package: `pip install pynvim`

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

Example `setup` with custom options:

```lua
require('py-autodoc').setup({
  doc_style = 'Numpydoc',
  indent_chars = '  ',
  include_type_hints = false,
})
```

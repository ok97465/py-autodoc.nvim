-- py-autodoc.nvim
--
-- Main plugin file

local parser = require("py-autodoc.parser")
local generator = require("py-autodoc.generator")

local M = {}

---@class py-autodoc.Config
local default_config = {
  -- Add default configuration options here
  doc_style = "Googledoc", -- "Numpydoc", "Googledoc", "Sphinxdoc"
  indent_chars = "    ",
  include_type_hints = true,
}

M.config = {}
local configured = false

-- The setup function is called by the user to configure the plugin
function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", {}, default_config, opts or {})
  configured = true
end

--- Returns whether the plugin has been configured by the user.
function M.is_configured()
    return configured
end

--- Generates and inserts a docstring for the function under the cursor.
function M.generate_docstring()
    if not configured then
        M.setup({})
    end
    -- 1. Get buffer and cursor info
    local buf = vim.api.nvim_get_current_buf()
    local cursor_pos = vim.api.nvim_win_get_cursor(0) -- {row, col}
    local cursor_line_num = cursor_pos[1] -- 1-based line number
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

    local function_start_line = cursor_line_num
    if not parser.is_start_of_function(lines[function_start_line] or "") then
        function_start_line = parser.find_function_start_line(lines, cursor_line_num)
    end

    if not function_start_line then
        vim.notify("Could not find Python function definition at cursor.", vim.log.levels.WARN)
        return
    end

    -- 2. Find the full function definition starting from the detected definition line
    local func_def_str, num_lines = parser.get_function_definition(lines, function_start_line)

    if not func_def_str then
        vim.notify("Could not find Python function definition at cursor.", vim.log.levels.WARN)
        return
    end

    -- 3. Parse the function definition string
    local func_info = parser.parse_function_info(func_def_str)
    if not func_info then
        vim.notify("Failed to parse function signature.", vim.log.levels.ERROR)
        return
    end

    -- 3.5 Get and parse function body
    local func_indent = parser.get_indent(lines[function_start_line])
    local body_text = parser.get_function_body(lines, function_start_line, num_lines, func_indent)
    local body_info = parser.parse_body(body_text)

    -- 4. Generate the docstring body
    local docstring_body = generator.generate(
        M.config.doc_style,
        func_info,
        body_info,
        func_indent,
        M.config.indent_chars,
        { include_type_hints = M.config.include_type_hints }
    )

    local docstring_lines = vim.split(docstring_body, "\n")

    -- 6. Insert the docstring into the buffer
    local insert_line_num = function_start_line + num_lines - 1
    vim.api.nvim_buf_set_lines(buf, insert_line_num, insert_line_num, false, docstring_lines)

    -- 7. Move cursor to the opening quotes so the user can type the summary immediately
    local cursor_target_line = insert_line_num + 1
    local cursor_target_col = #func_indent + #M.config.indent_chars + 3 -- +3 for the '"""'
    vim.api.nvim_win_set_cursor(0, {cursor_target_line, cursor_target_col})

    vim.notify("py-autodoc: Docstring generated.", vim.log.levels.INFO)
end

return M

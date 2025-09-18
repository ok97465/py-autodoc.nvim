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

--- Ensures the plugin has a usable configuration before doing any work.
local function ensure_configured()
    if not configured then
        M.setup({})
    end
end

--- Captures the information we need from the current buffer.
--- @return table snapshot
local function get_buffer_snapshot()
    local buf = vim.api.nvim_get_current_buf()
    local cursor_pos = vim.api.nvim_win_get_cursor(0)
    return {
        buf = buf,
        lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false),
        cursor_line = cursor_pos[1],
    }
end

--- Determines the line that starts the function under the cursor.
--- @param lines string[]
--- @param cursor_line integer
--- @return integer|nil
local function resolve_function_start(lines, cursor_line)
    if not cursor_line then
        return nil
    end

    local start_line = cursor_line
    if not parser.is_start_of_function(lines[start_line] or "") then
        start_line = parser.find_function_start_line(lines, cursor_line)
    end

    return start_line
end

--- Collects signature and body information for the target function.
--- @param lines string[]
--- @param function_start integer
--- @return table|nil context
--- @return table|nil failure
local function collect_function_context(lines, function_start)
    if not function_start then
        return nil, { message = "Could not find Python function definition at cursor.", level = vim.log.levels.WARN }
    end

    local func_def_str, definition_line_count = parser.get_function_definition(lines, function_start)
    if not func_def_str then
        return nil, { message = "Could not find Python function definition at cursor.", level = vim.log.levels.WARN }
    end

    local func_info = parser.parse_function_info(func_def_str)
    if not func_info then
        return nil, { message = "Failed to parse function signature.", level = vim.log.levels.ERROR }
    end

    local indent = parser.get_indent(lines[function_start] or "")
    local body_text = parser.get_function_body(lines, function_start, definition_line_count, indent)
    local body_info = parser.parse_body(body_text)

    return {
        func_info = func_info,
        body_info = body_info,
        indent = indent,
        definition_line_count = definition_line_count,
    }
end

--- Builds the docstring body for the collected function information.
--- @param context table
--- @return string
local function build_docstring(context)
    return generator.generate(
        M.config.doc_style,
        context.func_info,
        context.body_info,
        context.indent,
        M.config.indent_chars,
        { include_type_hints = M.config.include_type_hints }
    )
end

--- Inserts generated docstring lines into the current buffer.
--- @param buf integer
--- @param insert_line integer 1-based index of the line after the signature
--- @param docstring_lines string[]
local function insert_docstring(buf, insert_line, docstring_lines)
    vim.api.nvim_buf_set_lines(buf, insert_line, insert_line, false, docstring_lines)
end

--- Positions the cursor on the summary line of the generated docstring.
--- @param insert_line integer
--- @param indent string
local function position_cursor(insert_line, indent)
    local cursor_target_line = insert_line + 1
    local cursor_target_col = #indent + #M.config.indent_chars + 3
    vim.api.nvim_win_set_cursor(0, { cursor_target_line, cursor_target_col })
end

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
    ensure_configured()

    local snapshot = get_buffer_snapshot()
    local function_start = resolve_function_start(snapshot.lines, snapshot.cursor_line)
    local context, failure = collect_function_context(snapshot.lines, function_start)

    if not context then
        vim.notify(failure.message, failure.level)
        return
    end

    local docstring_body = build_docstring(context)
    local docstring_lines = vim.split(docstring_body, "\n")

    local insert_line = function_start + context.definition_line_count - 1
    insert_docstring(snapshot.buf, insert_line, docstring_lines)
    position_cursor(insert_line, context.indent)

    vim.notify("py-autodoc: Docstring generated.", vim.log.levels.INFO)
end

return M

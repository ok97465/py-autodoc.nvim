-- lua/py-autodoc/parser.lua

local M = {}

--- Checks if a line of text is the beginning of a function definition.
-- @param text The line of text to check.
-- @return boolean True if it's the start of a function, false otherwise.
function M.is_start_of_function(text)
    -- Remove leading whitespace
    local trimmed_text = text:match("^%s*(.*)")
    -- Use string.find for safety, anchored to the start
    return string.find(trimmed_text, "^def ") or string.find(trimmed_text, "^async def ")
end

--- Gets the indentation (leading whitespace) of a line of text.
-- @param text The line of text.
-- @return string The leading whitespace.
function M.get_indent(text)
    return text:match("^(%s*)") or ""
end

--- Finds the starting line of a Python function definition by scanning upward.
-- @param lines Table of buffer lines.
-- @param cursor_line The 1-based cursor line to start searching from.
-- @param max_lookback Maximum number of lines to scan upwards.
-- @return number|nil The 1-based line number where the function definition starts.
function M.find_function_start_line(lines, cursor_line, max_lookback)
    if type(cursor_line) ~= "number" then
        return nil
    end

    local total_lines = #lines
    if total_lines == 0 then
        return nil
    end

    if cursor_line < 1 then
        return nil
    end

    if cursor_line > total_lines then
        cursor_line = total_lines
    end

    max_lookback = max_lookback or 25
    local lower_bound = math.max(1, cursor_line - max_lookback)

    for i = cursor_line, lower_bound, -1 do
        local line = lines[i]
        if line then
            if M.is_start_of_function(line) then
                return i
            end

            local trimmed = line:match("^%s*(.*)") or ""
            if trimmed:sub(1, 1) == '@' then
                local max_forward = math.min(total_lines, i + max_lookback)
                for j = i + 1, max_forward do
                    local candidate = lines[j]
                    if candidate and M.is_start_of_function(candidate) then
                        return j
                    end
                end
            end
        end
    end

    return nil
end

--- Removes comments from a line of python code, ignoring '#' inside strings.
-- @param text The line of code.
-- @return string The line without comments.
function M.remove_comments(text)
    local clean_text = ""
    local in_string_char = nil
    local string_len = 0
    local i = 1
    while i <= #text do
        local char = text:sub(i, i)

        if in_string_char then
            clean_text = clean_text .. char
            if string_len == 3 then -- triple quote
                if text:sub(i, i + 2) == in_string_char then
                    in_string_char = nil
                    clean_text = clean_text .. text:sub(i + 1, i + 2)
                    i = i + 2
                end
            else -- single quote
                if char == in_string_char and text:sub(i - 1, i - 1) ~= '\\' then
                    in_string_char = nil
                end
            end
        else
            if char == "'" or char == '"' then
                clean_text = clean_text .. char
                if text:sub(i, i + 2) == char .. char .. char then
                    in_string_char = char .. char .. char
                    string_len = 3
                    clean_text = clean_text .. text:sub(i + 1, i + 2)
                    i = i + 2
                else
                    in_string_char = char
                    string_len = 1
                end
            elseif char == '#' then
                break -- comment start
            else
                clean_text = clean_text .. char
            end
        end
        i = i + 1
    end
    return clean_text
end

--- Checks if the text has unbalanced brackets, ignoring brackets inside strings.
-- @param text The text to check.
-- @return boolean True if brackets are unbalanced.
function M.is_scope_unbalanced(text)
    local in_string_char = nil
    local string_len = 0
    local level = {paren = 0, bracket = 0, brace = 0}
    local i = 1
    while i <= #text do
        local char = text:sub(i, i)

        if in_string_char then
            if string_len == 3 then -- triple quote
                if text:sub(i, i + 2) == in_string_char then
                    in_string_char = nil
                    i = i + 2
                end
            else -- single quote
                if char == in_string_char and text:sub(i - 1, i - 1) ~= '\\' then
                    in_string_char = nil
                end
            end
        else
            if char == "'" or char == '"' then
                if text:sub(i, i + 2) == char .. char .. char then
                    in_string_char = char .. char .. char
                    string_len = 3
                    i = i + 2
                else
                    in_string_char = char
                    string_len = 1
                end
            elseif char == '(' then
                level.paren = level.paren + 1
            elseif char == ')' then
                level.paren = level.paren - 1
            elseif char == '[' then
                level.bracket = level.bracket + 1
            elseif char == ']' then
                level.bracket = level.bracket - 1
            elseif char == '{' then
                level.brace = level.brace + 1
            elseif char == '}' then
                level.brace = level.brace - 1
            end
        end
        i = i + 1
    end

    return level.paren ~= 0 or level.bracket ~= 0 or level.brace ~= 0
end

--- Finds the full function definition starting from a given line number.
-- @param lines A table of strings representing the lines of the buffer.
-- @param start_line The 1-based index of the line where the function definition starts.
-- @return string|nil The full function definition as a single string, or nil if not found.
-- @return number|nil The number of lines in the function definition.
function M.get_function_definition(lines, start_line)
    local first_line = lines[start_line]
    if not first_line or not M.is_start_of_function(first_line) then
        return nil
    end

    local func_def_parts = {}
    local line_count = 0
    local func_indent = M.get_indent(first_line)

    for i = start_line, #lines do
        local current_line = lines[i]
        local line_no_comments = M.remove_comments(current_line)
        local trimmed_line = line_no_comments:match("^%s*(.*%S*)%s*$") or ""

        local previous_text = table.concat(func_def_parts, " ")

        if i > start_line then
            local current_indent = M.get_indent(current_line)
            local inside_signature = previous_text ~= "" and M.is_scope_unbalanced(previous_text)

            if #current_indent <= #func_indent and trimmed_line ~= "" and not inside_signature then
                break
            end
            if M.is_start_of_function(current_line) and not inside_signature then
                break
            end
        end

        if trimmed_line:sub(-1) == '\\' then
            trimmed_line = trimmed_line:sub(1, -2)
        end

        table.insert(func_def_parts, trimmed_line)
        line_count = line_count + 1

        local full_def_text = table.concat(func_def_parts, " ")
        if trimmed_line:sub(-1) == ':' and not M.is_scope_unbalanced(full_def_text) then
            return full_def_text, line_count
        end

        if line_count > 20 then
            break
        end
    end

    return nil
end

--- Splits an argument list string into a list of individual argument strings.
-- @param args_text The full argument string.
-- @return table A list of argument strings.
function M._split_args(args_text)
    local args_list = {}
    if not args_text or args_text == "" then
        return args_list
    end

    local last_split = 1
    local level = {paren = 0, bracket = 0, brace = 0}
    local in_string_char = nil

    local i = 1
    while i <= #args_text do
        local char = args_text:sub(i, i)

        if in_string_char then
            if char == in_string_char and args_text:sub(i - 1, i - 1) ~= '\\' then
                in_string_char = nil
            end
        else
            if char == "'" or char == '"' then
                in_string_char = char
            elseif char == '(' then
                level.paren = level.paren + 1
            elseif char == ')' then
                level.paren = level.paren - 1
            elseif char == '[' then
                level.bracket = level.bracket + 1
            elseif char == ']' then
                level.bracket = level.bracket - 1
            elseif char == '{' then
                level.brace = level.brace + 1
            elseif char == '}' then
                level.brace = level.brace - 1
            elseif char == ',' and level.paren == 0 and level.bracket == 0 and level.brace == 0 then
                table.insert(args_list, args_text:sub(last_split, i - 1))
                last_split = i + 1
            end
        end
        i = i + 1
    end

    table.insert(args_list, args_text:sub(last_split))
    return args_list
end

--- Parses a single argument string into its name, type, and default value.
-- @param arg_string The argument string (e.g., "a: int = 1").
-- @return table A table with keys {name, arg_type, default_value}.
function M._parse_arg(arg_string)
    local arg = { name = nil, arg_type = nil, default_value = nil }
    arg_string = arg_string:match("^%s*(.-)%s*$") or ""

    local eq_pos = arg_string:find("=")
    local colon_pos = arg_string:find(":")

    if colon_pos and eq_pos and colon_pos > eq_pos then
        colon_pos = nil
    end

    if colon_pos and eq_pos then
        arg.name = arg_string:sub(1, colon_pos - 1):match("^%s*(.-)%s*$")
        arg.arg_type = arg_string:sub(colon_pos + 1, eq_pos - 1):match("^%s*(.-)%s*$")
        arg.default_value = arg_string:sub(eq_pos + 1):match("^%s*(.-)%s*$")
    elseif colon_pos then
        arg.name = arg_string:sub(1, colon_pos - 1):match("^%s*(.-)%s*$")
        arg.arg_type = arg_string:sub(colon_pos + 1):match("^%s*(.-)%s*$")
    elseif eq_pos then
        arg.name = arg_string:sub(1, eq_pos - 1):match("^%s*(.-)%s*$")
        arg.default_value = arg_string:sub(eq_pos + 1):match("^%s*(.-)%s*$")
    else
        arg.name = arg_string
    end

    if arg.name:find("^%*%*") then
        arg.name = arg.name:sub(3)
    elseif arg.name:find("^%*") then
        arg.name = arg.name:sub(2)
    end

    return arg
end

--- Parses the entire function definition string into its main components.
-- @param def_string The full function definition string.
-- @return table|nil A table containing function information or nil if parsing fails.
function M.parse_function_info(def_string)
    if type(def_string) ~= "string" then
        return nil
    end

    local info = { name = nil, args = {}, return_type = nil }

    local def_keyword = "def "
    if def_string:find("async def ", 1, true) then
        def_keyword = "async def "
    end

    local name_start = def_string:find(def_keyword)
    if not name_start then return nil end
    name_start = name_start + #def_keyword

    local paren_start = def_string:find("(", name_start, true)
    if not paren_start then return nil end

    info.name = def_string:sub(name_start, paren_start - 1):match("^%s*(%w+)")
    if not info.name then
        return nil
    end

    local paren_end = -1
    local level = {paren = 0, bracket = 0, brace = 0}
    local in_string_char = nil
    local i = paren_start + 1
    while i <= #def_string do
        local char = def_string:sub(i, i)

        if in_string_char then
            if #in_string_char == 3 then
                if def_string:sub(i, i + 2) == in_string_char then
                    in_string_char = nil
                    i = i + 2
                end
            else
                if char == in_string_char and def_string:sub(i - 1, i - 1) ~= '\\' then
                    in_string_char = nil
                end
            end
        else
            if char == "'" or char == '"' then
                if def_string:sub(i, i + 2) == char .. char .. char then
                    in_string_char = char .. char .. char
                    i = i + 2
                else
                    in_string_char = char
                end
            elseif char == '(' then
                level.paren = level.paren + 1
            elseif char == ')' then
                if level.paren == 0 and level.bracket == 0 and level.brace == 0 then
                    paren_end = i
                    break
                else
                    level.paren = level.paren - 1
                end
            elseif char == '[' then
                level.bracket = level.bracket + 1
            elseif char == ']' then
                level.bracket = level.bracket - 1
            elseif char == '{' then
                level.brace = level.brace + 1
            elseif char == '}' then
                level.brace = level.brace - 1
            end
        end

        i = i + 1
    end

    if paren_end == -1 then return nil end

    local args_str = def_string:sub(paren_start + 1, paren_end - 1)
    local arg_strings = M._split_args(args_str)
    for _, arg_str in ipairs(arg_strings) do
        if arg_str:match("%S") then
            table.insert(info.args, M._parse_arg(arg_str))
        end
    end

    local remainder = def_string:sub(paren_end + 1)
    if remainder then
        local trimmed = remainder:match("^%s*(.-)%s*$") or ""
        if trimmed:sub(1, 2) == "->" then
            local ret_part = trimmed:sub(3)
            ret_part = ret_part:gsub("%s*:$", "")
            ret_part = ret_part:match("^%s*(.-)%s*$")
            if ret_part ~= "" then
                info.return_type = ret_part
            end
        end
    end

    return info
end

--- Gets the text of a function's body.
-- @param lines Table of all buffer lines.
-- @param def_start_line 1-based line number where the function definition starts.
-- @param def_num_lines The number of lines in the function definition.
-- @param func_indent The indentation string of the function.
-- @return string The text of the function body.
function M.get_function_body(lines, def_start_line, def_num_lines, func_indent)
    local body_lines = {}
    local body_start_line = def_start_line + def_num_lines
    local func_indent_level = #func_indent

    for i = body_start_line, #lines do
        local line = lines[i]
        local line_indent_level = #(M.get_indent(line))

        if line_indent_level <= func_indent_level and line:match("%S") then
            break
        end
        table.insert(body_lines, line)
    end

    return table.concat(body_lines, "\n")
end

--- Parses the function body to find raise, yield, and return statements.
-- @param body_text The string of the function body.
-- @return table A table with info about the body.
function M.parse_body(body_text)
    local body_info = {
        raises = {},
        has_yield = false,
        returns = {},
    }
    local raises_set = {}

    for line in body_text:gmatch("([^\n]+)") do
        local trimmed_line = line:match("^%s*(.*)")

        local raised_exception = trimmed_line:match("^raise%s+([%w_]+)")
        if raised_exception and not raises_set[raised_exception] then
            table.insert(body_info.raises, raised_exception)
            raises_set[raised_exception] = true
        end

        if trimmed_line:find("yield", 1, true) then
            body_info.has_yield = true
        end

        local return_val = trimmed_line:match("^return%s+(.+)")
        if return_val then
            table.insert(body_info.returns, return_val)
        end

        local yield_val = trimmed_line:match("^yield%s+(.+)")
        if yield_val then
            table.insert(body_info.returns, yield_val)
        end
    end

    return body_info
end

return M

-- lua/py-autodoc/generator.lua

local M = {}

local function get_args_for_doc(func_args)
    -- Create a copy to avoid modifying the original table
    local args_copy = {}
    for _, arg in ipairs(func_args) do
        table.insert(args_copy, arg)
    end

    if #args_copy > 0 and (args_copy[1].name == "self" or args_copy[1].name == "cls") then
        table.remove(args_copy, 1)
    end
    return args_copy
end

local function format_argument_for_numpydoc(arg, include_type_hints)
    local indent_desc = "    "
    local arg_type = arg.arg_type or "TYPE"
    local header
    if include_type_hints then
        header = ("%s : %s"):format(arg.name, arg_type)
        if arg.default_value then
            header = header .. ", optional"
        end
    else
        header = arg.name
        if arg.default_value then
            header = header .. " (optional)"
        end
    end

    local description = indent_desc .. "DESCRIPTION."
    if arg.default_value then
        description = description .. " Defaults to " .. arg.default_value .. "."
    end

    return header, description
end

function M.generate_googledoc(func_info, body_info, include_type_hints)
    local lines = {}
    local indent2 = "    " -- Relative indentation used inside the docstring body

    table.insert(lines, "")

    local doc_args = get_args_for_doc(func_info.args)

    if #doc_args > 0 then
        table.insert(lines, "Args:")
        for _, arg in ipairs(doc_args) do
            local arg_display
            local arg_type = arg.arg_type or "TYPE"

            if include_type_hints then
                arg_display = ("%s (%s)"):format(arg.name, arg_type)
            else
                arg_display = arg.name
            end

            local line = ("%s: DESCRIPTION."):format(arg_display)
            if arg.default_value then
                line = line .. " Defaults to " .. arg.default_value .. "."
            end
            table.insert(lines, indent2 .. line)
        end
    end

    if body_info and #body_info.raises > 0 then
        table.insert(lines, "")
        table.insert(lines, "Raises:")
        for _, exception in ipairs(body_info.raises) do
            table.insert(lines, indent2 .. exception .. ": DESCRIPTION.")
        end
    end

    table.insert(lines, "")
    if body_info and body_info.has_yield then
        table.insert(lines, "Yields:")
    else
        table.insert(lines, "Returns:")
    end

    if func_info.return_type and include_type_hints then
        table.insert(lines, indent2 .. func_info.return_type .. ": DESCRIPTION.")
    elseif func_info.return_type then
        table.insert(lines, indent2 .. "DESCRIPTION.")
    else
        table.insert(lines, indent2 .. "None.")
    end

    return lines
end

function M.generate_numpydoc(func_info, body_info, include_type_hints)
    local lines = {}
    local indent_desc = "    "

    table.insert(lines, "")

    local doc_args = get_args_for_doc(func_info.args)

    if #doc_args > 0 then
        table.insert(lines, "Parameters")
        table.insert(lines, "----------")
        for _, arg in ipairs(doc_args) do
            local header, description = format_argument_for_numpydoc(arg, include_type_hints)
            table.insert(lines, header)
            table.insert(lines, description)
        end
    end

    if body_info and #body_info.raises > 0 then
        table.insert(lines, "")
        table.insert(lines, "Raises")
        table.insert(lines, "------")
        for _, exception in ipairs(body_info.raises) do
            table.insert(lines, exception)
            table.insert(lines, indent_desc .. "DESCRIPTION.")
        end
    end

    table.insert(lines, "")
    local section_label = (body_info and body_info.has_yield) and "Yields" or "Returns"
    table.insert(lines, section_label)
    table.insert(lines, string.rep("-", #section_label))

    if include_type_hints then
        local return_type = func_info.return_type
        if not return_type then
            if body_info and body_info.has_yield then
                return_type = "TYPE"
            else
                return_type = "None"
            end
        end
        table.insert(lines, return_type)
        table.insert(lines, indent_desc .. "DESCRIPTION.")
    else
        table.insert(lines, indent_desc .. "DESCRIPTION.")
    end

    return lines
end

function M.generate_sphinxdoc(func_info, body_info, include_type_hints)
    local lines = {}

    table.insert(lines, "")

    local doc_args = get_args_for_doc(func_info.args)
    for _, arg in ipairs(doc_args) do
        local description = ":param " .. arg.name .. ": DESCRIPTION."
        if arg.default_value then
            description = description .. " Defaults to " .. arg.default_value .. "."
        end
        table.insert(lines, description)

        if include_type_hints then
            local arg_type = arg.arg_type or "TYPE"
            table.insert(lines, string.format(":type %s: %s", arg.name, arg_type))
        end
    end

    if #doc_args > 0 then
        table.insert(lines, "")
    end

    if body_info and #body_info.raises > 0 then
        for _, exception in ipairs(body_info.raises) do
            table.insert(lines, string.format(":raises %s: DESCRIPTION.", exception))
        end
        table.insert(lines, "")
    end

    local returns_directive
    local rtype_directive
    if body_info and body_info.has_yield then
        returns_directive = ":yields:"
        rtype_directive = ":yield type:"
    else
        returns_directive = ":returns:"
        rtype_directive = ":rtype:"
    end

    table.insert(lines, returns_directive .. " DESCRIPTION.")

    if include_type_hints then
        local return_type = func_info.return_type
        if not return_type then
            return_type = (body_info and body_info.has_yield) and "TYPE" or "None"
        end
        table.insert(lines, string.format("%s %s", rtype_directive, return_type))
    end

    return lines
end

--- Generates a docstring based on the specified style.
function M.generate(doc_style, func_info, body_info, indent, indent_chars, opts)
    opts = opts or {}
    local include_type_hints = opts.include_type_hints
    if include_type_hints == nil then
        include_type_hints = true
    end

    local generator = M["generate_" .. doc_style:lower()]
    if not generator then
        generator = M.generate_googledoc -- Default to Numpydoc
    end

    -- Get the unindented lines from the style-specific generator
    local unindented_lines = generator(func_info, body_info, include_type_hints)

    local indent1 = indent .. indent_chars
    local final_lines = {}

    -- Get the first line (placeholder for the user summary) and combine with opening quotes
    local first_unindented_line = table.remove(unindented_lines, 1) or ""
    table.insert(final_lines, indent1 .. '"""' .. first_unindented_line)

    -- Add the indented body of the docstring
    for _, line in ipairs(unindented_lines) do
        if line == "" then
            table.insert(final_lines, indent1) -- Keep blank lines, but indented
        else
            table.insert(final_lines, indent1 .. line)
        end
    end

    -- Add closing quotes
    table.insert(final_lines, indent1 .. '"""')

    return table.concat(final_lines, "\n")
end

return M

-- spec/py-autodoc/e2e_spec.lua

-- Mock the vim global for testing outside of Neovim
if not vim then
    _G.vim = {
        split = function(s, sep)
            if s == nil then return {} end
            local fields = {}
            local pattern = string.format("([^%s]+)", sep)
            for c in string.gmatch(s, pattern) do
                table.insert(fields, c)
            end
            return fields
        end,
    }
end

describe("py-autodoc end-to-end tests", function()
    local parser
    local generator

    before_each(function()
        package.loaded["py-autodoc.parser"] = nil
        package.loaded["py-autodoc.generator"] = nil
        parser = require("py-autodoc.parser")
        generator = require("py-autodoc.generator")
    end)

    -- Helper function to run a full end-to-end test
    local function run_e2e_test(input_code, doc_style, cursor_line_override, generator_opts)
        local lines = vim.split(input_code, "\n")
        local cursor_line = cursor_line_override
        local function_start, num_lines, func_def_str, func_info, body_info

        if not cursor_line then
            for i, line in ipairs(lines) do
                if parser.is_start_of_function(line) then
                    cursor_line = i
                    break
                end
            end
        end

        if not cursor_line then return nil, "Could not find start of function" end

        function_start = cursor_line
        if not parser.is_start_of_function(lines[function_start] or "") then
            function_start = parser.find_function_start_line(lines, cursor_line)
        end

        if not function_start then return nil, "Could not find function definition at cursor" end

        func_def_str, num_lines = parser.get_function_definition(lines, function_start)
        if not func_def_str then return nil, "Could not get function definition" end

        func_info = parser.parse_function_info(func_def_str)
        if not func_info then return nil, "Could not parse function info" end

        local func_indent = parser.get_indent(lines[function_start])
        local body_text = parser.get_function_body(lines, function_start, num_lines, func_indent)
        body_info = parser.parse_body(body_text)

        local docstring_body = generator.generate(doc_style, func_info, body_info, func_indent, "    ", generator_opts)

        local docstring_lines = vim.split(docstring_body, "\n")

        local insert_at = function_start + num_lines - 1
        local final_lines = {}
        for i = 1, insert_at do
            table.insert(final_lines, lines[i])
        end
        for _, d_line in ipairs(docstring_lines) do
            table.insert(final_lines, d_line)
        end
        for i = insert_at + 1, #lines do
            table.insert(final_lines, lines[i])
        end

        return table.concat(final_lines, "\n")
    end

    local googledoc_cases = {
        {
            description = "generates args and raises for simple async functions",
            input = [=[async def foo(arg1: int):
    raise ValueError("Test")
]=],
            expected_lines = {
                "async def foo(arg1: int):",
                "    \"\"\"",
                "    Args:",
                "        arg1 (int): DESCRIPTION.",
                "    ",
                "    Raises:",
                    "        ValueError: DESCRIPTION.",
                "    ",
                "    Returns:",
                "        None.",
                "    \"\"\"",
                "    raise ValueError(\"Test\")",
            },
        },
        {
            description = "handles async functions with multiple raises and yield",
            input = [=[async def foo():
    raise
    raise ValueError
    raise TypeError("test")
    yield value
]=],
            expected_lines = {
                "async def foo():",
                "    \"\"\"",
                "    ",
                "    Raises:",
                "        ValueError: DESCRIPTION.",
                "        TypeError: DESCRIPTION.",
                "    ",
                "    Yields:",
                "        None.",
                "    \"\"\"",
                "    raise",
                "    raise ValueError",
                "    raise TypeError(\"test\")",
                "    yield value",
            },
        },
        {
            description = "omits type hints when disabled",
            input = [=[def foo(arg1: int, arg2: str) -> int:
    return arg1
]=],
            generator_opts = { include_type_hints = false },
            expected_lines = {
                "def foo(arg1: int, arg2: str) -> int:",
                "    \"\"\"",
                "    Args:",
                "        arg1: DESCRIPTION.",
                "        arg2: DESCRIPTION.",
                "    ",
                "    Returns:",
                "        DESCRIPTION.",
                "    \"\"\"",
                "    return arg1",
            },
        },
        {
            description = "keeps indentation when inserting docstring",
            input = [[  def foo():
      ]],
            expected_lines = {
                "  def foo():",
                "      \"\"\"",
                "      ",
                "      Returns:",
                "          None.",
                "      \"\"\"",
                "      ",
            },
        },
        {
            description = "captures complex signatures with defaults",
            input = [=[def foo(arg, arg0, arg1: int, arg2: List[Tuple[str, float]],
    arg3='-> (float, int):', arg4=':float, int[', arg5: str='""') ->
  (List[Tuple[str, float]], str, float):
]=],
            expected_lines = {
                "def foo(arg, arg0, arg1: int, arg2: List[Tuple[str, float]],",
                "    arg3='-> (float, int):', arg4=':float, int[', arg5: str='\"\"') ->",
                "  (List[Tuple[str, float]], str, float):",
                "    \"\"\"",
                "    Args:",
                "        arg (TYPE): DESCRIPTION.",
                "        arg0 (TYPE): DESCRIPTION.",
                "        arg1 (int): DESCRIPTION.",
                "        arg2 (List[Tuple[str, float]]): DESCRIPTION.",
                "        arg3 (TYPE): DESCRIPTION. Defaults to '-> (float, int):'.",
                "        arg4 (TYPE): DESCRIPTION. Defaults to ':float, int['.",
                "        arg5 (str): DESCRIPTION. Defaults to '\"\"'.",
                "    ",
                "    Returns:",
                "        (List[Tuple[str, float]], str, float): DESCRIPTION.",
                "    \"\"\"",
            },
        },
        {
            description = "supports multi-line signatures with return annotations",
            input = [=[def foo(
        a: ndarray,
        b: ndarray
) -> ndarray:
    pass
]=],
            expected_lines = {
                "def foo(",
                "        a: ndarray,",
                "        b: ndarray",
                ") -> ndarray:",
                "    \"\"\"",
                "    Args:",
                "        a (ndarray): DESCRIPTION.",
                "        b (ndarray): DESCRIPTION.",
                "    ",
                "    Returns:",
                "        ndarray: DESCRIPTION.",
                "    \"\"\"",
                "    pass",
            },
        },
        {
            description = "supports multi-line signatures when cursor is on argument line",
            input = [=[def foo(
        a: ndarray,
        b: ndarray
) -> ndarray:
    pass
]=],
            cursor_line = 2,
            expected_lines = {
                "def foo(",
                "        a: ndarray,",
                "        b: ndarray",
                ") -> ndarray:",
                "    \"\"\"",
                "    Args:",
                "        a (ndarray): DESCRIPTION.",
                "        b (ndarray): DESCRIPTION.",
                "    ",
                "    Returns:",
                "        ndarray: DESCRIPTION.",
                "    \"\"\"",
                "    pass",
            },
        },
        {
            description = "handles decorators with cursor on decorator",
            input = [=[@decorator
def foo(arg1: int) -> int:
    return arg1
]=],
            cursor_line = 1,
            expected_lines = {
                "@decorator",
                "def foo(arg1: int) -> int:",
                "    \"\"\"",
                "    Args:",
                "        arg1 (int): DESCRIPTION.",
                "    ",
                "    Returns:",
                "        int: DESCRIPTION.",
                "    \"\"\"",
                "    return arg1",
            },
        },
        {
            description = "handles stacked decorators with cursor on top decorator",
            input = [=[@decorator_one
@decorator_two
def foo(arg1: int) -> int:
    return arg1
]=],
            cursor_line = 1,
            expected_lines = {
                "@decorator_one",
                "@decorator_two",
                "def foo(arg1: int) -> int:",
                "    \"\"\"",
                "    Args:",
                "        arg1 (int): DESCRIPTION.",
                "    ",
                "    Returns:",
                "        int: DESCRIPTION.",
                "    \"\"\"",
                "    return arg1",
            },
        },
        {
            description = "handles multi-line decorators",
            input = [=[@decorator(
    option=True,
)
def foo(arg1: int) -> int:
    return arg1
]=],
            cursor_line = 2,
            expected_lines = {
                "@decorator(",
                "    option=True,",
                ")",
                "def foo(arg1: int) -> int:",
                "    \"\"\"",
                "    Args:",
                "        arg1 (int): DESCRIPTION.",
                "    ",
                "    Returns:",
                "        int: DESCRIPTION.",
                "    \"\"\"",
                "    return arg1",
            },
        },
        {
            description = "adds docstring before complex body with raises",
            input = [=[  def foo():
      raise
      foo_raise()
      raisefoo()
      raise ValueError
      is_yield()
      raise ValueError('tt')
      yieldfoo()
      \traise TypeError('tt')
      _yield
]=],
            expected_lines = {
                "  def foo():",
                "      \"\"\"",
                "      ",
                "      Raises:",
                "          ValueError: DESCRIPTION.",
                "      ",
                "      Yields:",
                "          None.",
                "      \"\"\"",
                "      raise",
                "      foo_raise()",
                "      raisefoo()",
                "      raise ValueError",
                "      is_yield()",
                "      raise ValueError('tt')",
                "      yieldfoo()",
                "      \\traise TypeError('tt')",
                "      _yield",
            },
        },
        {
            description = "handles functions returning multiple values",
            input = [=[def foo():
    return None
    return "f, b", v1, v2, 3.0, .7, (,), {}, [ab], f(a), None, a.b, a+b, True
    return "f, b", v1, v3, 420, 5., (,), {}, [ab], f(a), None, a.b, a+b, False
]=],
            expected_lines = {
                "def foo():",
                "    \"\"\"",
                "    ",
                "    Returns:",
                "        None.",
                "    \"\"\"",
                "    return None",
                "    return \"f, b\", v1, v2, 3.0, .7, (,), {}, [ab], f(a), None, a.b, a+b, True",
                "    return \"f, b\", v1, v3, 420, 5., (,), {}, [ab], f(a), None, a.b, a+b, False",
            },
        },
        {
            description = "handles tuple returns without annotations",
            input = [=[def foo():
    return no, (ano, eo, dken)
]=],
            expected_lines = {
                "def foo():",
                "    \"\"\"",
                "    ",
                "    Returns:",
                "        None.",
                "    \"\"\"",
                "    return no, (ano, eo, dken)",
            },
        },
    }

    for _, case in ipairs(googledoc_cases) do
        it("Googledoc " .. case.description, function()
            local result, err = run_e2e_test(case.input, "Googledoc", case.cursor_line, case.generator_opts)
            assert.is_nil(err)
            local result_lines = vim.split(result, "\n")
            assert.are.same(case.expected_lines, result_lines)
        end)
    end

    local numpydoc_cases = {
        {
            description = "includes type hints by default",
            input = [=[def foo(arg1: int, arg2: str) -> int:
    return arg1
]=],
            generator_opts = { include_type_hints = true },
            expected_lines = {
                "def foo(arg1: int, arg2: str) -> int:",
                "    \"\"\"",
                "    Parameters",
                "    ----------",
                "    arg1 : int",
                "        DESCRIPTION.",
                "    arg2 : str",
                "        DESCRIPTION.",
                "    ",
                "    Returns",
                "    -------",
                "    int",
                "        DESCRIPTION.",
                "    \"\"\"",
                "    return arg1",
            },
        },
        {
            description = "omits type hints when disabled",
            input = [=[def foo(arg1: int, arg2: str) -> int:
    return arg1
]=],
            generator_opts = { include_type_hints = false },
            expected_lines = {
                "def foo(arg1: int, arg2: str) -> int:",
                "    \"\"\"",
                "    Parameters",
                "    ----------",
                "    arg1",
                "        DESCRIPTION.",
                "    arg2",
                "        DESCRIPTION.",
                "    ",
                "    Returns",
                "    -------",
                "        DESCRIPTION.",
                "    \"\"\"",
                "    return arg1",
            },
        },
    }

    for _, case in ipairs(numpydoc_cases) do
        it("Numpydoc " .. case.description, function()
            local result, err = run_e2e_test(case.input, "Numpydoc", case.cursor_line, case.generator_opts)
            assert.is_nil(err)
            local result_lines = vim.split(result, "\n")
            assert.are.same(case.expected_lines, result_lines)
        end)
    end

    local sphinxdoc_cases = {
        {
            description = "includes type hints by default",
            input = [=[def foo(arg1: int, arg2: str) -> int:
    return arg1
]=],
            generator_opts = { include_type_hints = true },
            expected_lines = {
                "def foo(arg1: int, arg2: str) -> int:",
                "    \"\"\"",
                "    :param arg1: DESCRIPTION.",
                "    :type arg1: int",
                "    :param arg2: DESCRIPTION.",
                "    :type arg2: str",
                "    ",
                "    :returns: DESCRIPTION.",
                "    :rtype: int",
                "    \"\"\"",
                "    return arg1",
            },
        },
        {
            description = "omits type hints when disabled",
            input = [=[def foo(arg1: int, arg2: str) -> int:
    return arg1
]=],
            generator_opts = { include_type_hints = false },
            expected_lines = {
                "def foo(arg1: int, arg2: str) -> int:",
                "    \"\"\"",
                "    :param arg1: DESCRIPTION.",
                "    :param arg2: DESCRIPTION.",
                "    ",
                "    :returns: DESCRIPTION.",
                "    \"\"\"",
                "    return arg1",
            },
        },
    }

    for _, case in ipairs(sphinxdoc_cases) do
        it("Sphinxdoc " .. case.description, function()
            local result, err = run_e2e_test(case.input, "Sphinxdoc", case.cursor_line, case.generator_opts)
            assert.is_nil(err)
            local result_lines = vim.split(result, "\n")
            assert.are.same(case.expected_lines, result_lines)
        end)
    end

end)

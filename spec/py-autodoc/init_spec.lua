-- spec/py-autodoc/init_spec.lua

describe("py-autodoc.init configuration", function()
    local autodoc
    local buf_lines
    local cursor_pos

    local function setup_vim_stubs()
        _G.vim = {
            api = {},
            log = { levels = { INFO = 0, WARN = 1, ERROR = 2 } },
            notify = function() end,
        }

        local function deep_extend(dst, src)
            for k, v in pairs(src) do
                if type(v) == "table" and type(dst[k]) == "table" then
                    deep_extend(dst[k], v)
                else
                    dst[k] = v
                end
            end
        end

        function vim.tbl_deep_extend(_, ...)
            local result = {}
            for _, tbl in ipairs({...}) do
                if type(tbl) == "table" then
                    deep_extend(result, tbl)
                end
            end
            return result
        end

        function vim.split(s, sep)
            if s == nil then return {} end
            local fields = {}
            local pattern = string.format("([^%s]+)", sep)
            for c in string.gmatch(s, pattern) do
                table.insert(fields, c)
            end
            return fields
        end

        vim.api.nvim_get_current_buf = function()
            return 1
        end

        vim.api.nvim_win_get_cursor = function()
            return cursor_pos
        end

        vim.api.nvim_win_set_cursor = function(_, new_pos)
            cursor_pos = new_pos
        end

        vim.api.nvim_buf_get_lines = function(_, start, finish, _)
            local s = start + 1
            local e = finish
            if e < 0 or e > #buf_lines then
                e = #buf_lines
            end
            local lines = {}
            for i = s, e do
                table.insert(lines, buf_lines[i])
            end
            return lines
        end

        vim.api.nvim_buf_set_lines = function(_, start, finish, _, replacement)
            local s = start + 1
            local e = finish
            if e < 0 then e = s end
            for _ = s, e - 1 do
                table.remove(buf_lines, s)
            end
            for i, line in ipairs(replacement) do
                table.insert(buf_lines, s + i - 1, line)
            end
        end
    end

    local function load_autodoc()
        package.loaded["py-autodoc"] = nil
        package.loaded["py-autodoc.parser"] = nil
        package.loaded["py-autodoc.generator"] = nil
        autodoc = require("py-autodoc")
    end

    local function prepare_buffer()
        buf_lines = {
            "def foo(arg1: int, arg2: str) -> int:",
            "    return arg1",
        }
        cursor_pos = {1, 0}
    end

    local function run_generate_docstring(config)
        prepare_buffer()

        autodoc.setup(config or {})
        autodoc.generate_docstring()
    end

    local function line_contains(pattern)
        for _, line in ipairs(buf_lines) do
            if line:find(pattern) then
                return true
            end
        end
        return false
    end

    setup(function()
        setup_vim_stubs()
    end)

    before_each(function()
        load_autodoc()
    end)

    it("includes type hints by default", function()
        run_generate_docstring()
        assert.is_true(not line_contains("Summary of the function"))
        assert.is_true(line_contains('"""'))
        assert.is_true(line_contains("arg1 %(int%)"))
        assert.is_true(line_contains("int: DESCRIPTION"))
    end)

    it("omits type hints when include_type_hints is false", function()
        run_generate_docstring({ include_type_hints = false })
        assert.is_true(not line_contains("Summary of the function"))
        assert.is_true(line_contains('"""'))
        assert.is_true(line_contains("arg1: DESCRIPTION"))
        assert.is_true(not line_contains("arg1 %(int%)"))
        assert.is_true(not line_contains("int: DESCRIPTION"))
        assert.is_true(line_contains("DESCRIPTION"))
    end)

    it("respects user setup after default initialization", function()
        prepare_buffer()
        autodoc.setup({}) -- Simulate plugin default setup
        autodoc.setup({ include_type_hints = false })
        autodoc.generate_docstring()
        assert.is_true(not line_contains("Summary of the function"))
        assert.is_true(line_contains('"""'))
        assert.is_true(line_contains("arg1: DESCRIPTION"))
        assert.is_true(not line_contains("arg1 %(int%)"))
    end)

    it("includes type hints for Numpydoc style", function()
        run_generate_docstring({ doc_style = "Numpydoc" })
        assert.is_true(line_contains("Parameters"))
        assert.is_true(line_contains("arg1 : int"))
        assert.is_true(line_contains("Returns"))
        assert.is_true(line_contains("int"))
    end)

    it("omits type hints for Numpydoc when disabled", function()
        run_generate_docstring({ doc_style = "Numpydoc", include_type_hints = false })
        assert.is_true(line_contains("Parameters"))
        assert.is_true(line_contains("arg1"))
        assert.is_true(not line_contains("arg1 : int"))
        assert.is_true(line_contains("Returns"))
        assert.is_true(not line_contains("    int"))
    end)

    it("includes type hints for Sphinxdoc style", function()
        run_generate_docstring({ doc_style = "Sphinxdoc" })
        assert.is_true(line_contains(":param arg1:"))
        assert.is_true(line_contains(":type arg1: int"))
        assert.is_true(line_contains(":rtype: int"))
    end)

    it("omits type hints for Sphinxdoc when disabled", function()
        run_generate_docstring({ doc_style = "Sphinxdoc", include_type_hints = false })
        assert.is_true(line_contains(":param arg1:"))
        assert.is_true(not line_contains(":type arg1:"))
        assert.is_true(line_contains(":returns:"))
        assert.is_true(not line_contains(":rtype:"))
    end)
end)

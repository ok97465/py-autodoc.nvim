-- spec/py-autodoc/parser_spec.lua

describe("py-autodoc.parser", function()
    local parser

    before_each(function()
        package.loaded["py-autodoc.parser"] = nil
        parser = require("py-autodoc.parser")
    end)

    describe("parse_function_info", function()
        it("should parse a simple function with no args", function()
            local def_string = [[def foo():]]
            local expected = {
                name = "foo",
                args = {},
                return_type = nil,
            }
            local result = parser.parse_function_info(def_string)
            assert.are.same(expected, result)
        end)

        it("should parse a complex function with args, types, defaults, and return type", function()
            local def_string = [[def foo(arg0, arg1=':', arg2: str='-> (float, str):') -> (float, int):]]
            local expected = {
                name = "foo",
                args = {
                    { name = "arg0", arg_type = nil, default_value = nil },
                    { name = "arg1", arg_type = nil, default_value = "':'" },
                    { name = "arg2", arg_type = "str", default_value = "'-> (float, str):'" },
                },
                return_type = "(float, int)",
            }
            local result = parser.parse_function_info(def_string)
            assert.are.same(expected, result)
        end)

        it("should parse an async function", function()
            local def_string = [[async def bar(p1: str) -> bool:]]
            local expected = {
                name = "bar",
                args = {
                    { name = "p1", arg_type = "str", default_value = nil },
                },
                return_type = "bool",
            }
            local result = parser.parse_function_info(def_string)
            assert.are.same(expected, result)
        end)
    end)

    describe("get_function_definition", function()
        it("should capture multi-line function signatures", function()
            local lines = {
                "def foo(",
                "        a: ndarray,",
                "        b: ndarray",
                ") -> ndarray:",
                "    pass",
            }
            local def_string, line_count = parser.get_function_definition(lines, 1)
            assert.are.equal("def foo( a: ndarray, b: ndarray ) -> ndarray:", def_string)
            assert.are.equal(4, line_count)
        end)
    end)

    describe("find_function_start_line", function()
        it("should locate the def line when cursor is on signature continuation", function()
            local lines = {
                "def foo(",
                "        a: ndarray,",
                "        b: ndarray",
                ") -> ndarray:",
                "    pass",
            }
            local start_line = parser.find_function_start_line(lines, 3)
            assert.are.equal(1, start_line)
        end)

        it("should respect the lookback limit", function()
            local lines = {
                "def foo():",
                "    return 1",
                "",
                "value = foo()",
            }
            local start_line = parser.find_function_start_line(lines, 4, 1)
            assert.is_nil(start_line)
        end)

        it("should skip decorators above the definition", function()
            local lines = {
                "@decorator",
                "def foo():",
                "    return 1",
            }
            local start_line = parser.find_function_start_line(lines, 1)
            assert.are.equal(2, start_line)
        end)

        it("should handle stacked decorators", function()
            local lines = {
                "@decorator_one",
                "@decorator_two",
                "def foo():",
                "    return 1",
            }
            local start_line = parser.find_function_start_line(lines, 2)
            assert.are.equal(3, start_line)
        end)

        it("should handle multi-line decorators", function()
            local lines = {
                "@decorator(",
                "    option=True",
                ")",
                "def foo():",
                "    return 1",
            }
            local start_line = parser.find_function_start_line(lines, 2)
            assert.are.equal(4, start_line)
        end)
    end)
end)

-- spec/py-autodoc/generator_spec.lua

describe("py-autodoc.generator snippet placeholders", function()
    local generator

    before_each(function()
        package.loaded["py-autodoc.generator"] = nil
        generator = require("py-autodoc.generator")
    end)

    it("embeds snippet placeholders in Googledoc output", function()
        local func_info = {
            args = {
                { name = "arg1", arg_type = "int" },
                { name = "arg2", arg_type = "str", default_value = "'x'" },
            },
            return_type = "bool",
        }
        local body_info = {
            raises = { "ValueError" },
            has_yield = false,
        }

        local docstring = generator.generate("Googledoc", func_info, body_info, "", "    ", { include_type_hints = true })

        assert.is_not_nil(docstring:match('^%s*"""%${%d+:Summary%.}'))
        assert.is_not_nil(docstring:match('arg1 %(int%): %${%d+:DESCRIPTION%.}'))
        assert.is_not_nil(docstring:match('arg2 %(str%): %${%d+:DESCRIPTION%.}'))
        assert.is_not_nil(docstring:match('ValueError: %${%d+:DESCRIPTION%.}'))
        assert.is_not_nil(docstring:match('bool: %${%d+:DESCRIPTION%.}'))
    end)

    it("falls back to literal None for return-less Googledoc output", function()
        local func_info = {
            args = {},
            return_type = nil,
        }
        local body_info = {
            raises = {},
            has_yield = false,
        }

        local docstring = generator.generate("Googledoc", func_info, body_info, "", "    ", { include_type_hints = true })

        assert.is_not_nil(docstring:match('^%s*"""%${%d+:Summary%.}'))
        assert.is_not_nil(docstring:match('\n    Returns:\n        None%.'))
    end)
end)

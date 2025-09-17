-- This file is loaded by Neovim on startup.
-- It's responsible for creating user commands.

local autodoc = require("py-autodoc")

if not autodoc.is_configured() then
    autodoc.setup({})
end

vim.api.nvim_create_user_command(
    "PyAutodoc",
    function()
        local success, module = pcall(require, "py-autodoc")
        if success then
            module.generate_docstring()
        else
            vim.notify("py-autodoc: Failed to load module.", vim.log.levels.ERROR)
        end
    end,
    {
        nargs = 0,
        desc = "Generate a docstring for the Python function under the cursor."
    }
)

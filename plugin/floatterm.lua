if vim.g.loaded_floatterm then
  return
end

vim.g.loaded_floatterm = true

vim.api.nvim_create_user_command("Floatterm", function(cmd)
  local ft = require("floatterm")
  local action = cmd.args ~= "" and cmd.args or "toggle"
  if not vim.tbl_contains({ "toggle", "open", "close" }, action) then
    vim.notify("Floatterm: unknown action '" .. action .. "'", vim.log.levels.ERROR)
    return
  end
  ft[action]()
end, {
  nargs = "?",
  complete = function()
    return { "toggle", "open", "close" }
  end,
  desc = "Toggle floating terminal",
})

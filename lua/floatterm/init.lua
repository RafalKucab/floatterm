local M = {}

---@class FloattermConfig
---@field width number Width as fraction of editor columns (0-1) or absolute columns (>1)
---@field height number Height as fraction of editor lines (0-1) or absolute lines (>1)
---@field border string|string[] Border style passed to nvim_open_win
---@field title string|nil Optional window title
---@field cmd string|nil Command to run in the terminal (defaults to 'shell')
---@field start_insert boolean Enter terminal mode after opening
local defaults = {
  width = 0.8,
  height = 0.8,
  border = "double",
  title = nil,
  cmd = nil,
  start_insert = false,
}

M.config = vim.deepcopy(defaults)

local state = {
  buf = -1,
  win = -1,
}

local function resolve(size, total)
  if size <= 1 then
    return math.floor(total * size)
  end
  return math.min(math.floor(size), total)
end

local function win_config()
  local width = resolve(M.config.width, vim.o.columns)
  local height = resolve(M.config.height, vim.o.lines)
  local cfg = {
    relative = "editor",
    width = width,
    height = height,
    col = math.floor((vim.o.columns - width) / 2),
    row = math.floor((vim.o.lines - height) / 2),
    style = "minimal",
    border = M.config.border,
  }
  if M.config.title then
    cfg.title = M.config.title
    cfg.title_pos = "center"
  end
  return cfg
end

---@return boolean
function M.is_open()
  return vim.api.nvim_win_is_valid(state.win)
end

function M.open()
  if M.is_open() then
    vim.api.nvim_set_current_win(state.win)
    return
  end

  if not vim.api.nvim_buf_is_valid(state.buf) then
    state.buf = vim.api.nvim_create_buf(false, true)
  end

  state.win = vim.api.nvim_open_win(state.buf, true, win_config())

  if vim.bo[state.buf].buftype ~= "terminal" then
    if M.config.cmd then
      vim.cmd.terminal(M.config.cmd)
    else
      vim.cmd.terminal()
    end
    vim.bo[state.buf].buflisted = false
  else
    vim.api.nvim_win_call(state.win, function()
      vim.cmd("normal! G")
    end)
  end

  if M.config.start_insert then
    vim.cmd.startinsert()
  end
end

function M.close()
  if M.is_open() then
    vim.api.nvim_win_hide(state.win)
  end
end

function M.toggle()
  if M.is_open() then
    M.close()
  else
    M.open()
  end
end

-- backwards compatible alias
M.toggle_terminal = M.toggle

---@param opts FloattermConfig|nil
function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", vim.deepcopy(defaults), opts or {})
end

local group = vim.api.nvim_create_augroup("floatterm", { clear = true })

-- keep the window centered when the editor is resized
vim.api.nvim_create_autocmd("VimResized", {
  group = group,
  callback = function()
    if M.is_open() then
      vim.api.nvim_win_set_config(state.win, win_config())
    end
  end,
})

-- drop the buffer when the shell exits so the next toggle starts a fresh one
vim.api.nvim_create_autocmd("TermClose", {
  group = group,
  callback = function(ev)
    if ev.buf == state.buf then
      vim.schedule(function()
        if vim.api.nvim_buf_is_valid(ev.buf) then
          vim.api.nvim_buf_delete(ev.buf, { force = true })
        end
        state.buf = -1
        state.win = -1
      end)
    end
  end,
})

return M

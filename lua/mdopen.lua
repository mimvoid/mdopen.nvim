local M = {}

---@class mdopen_nvim.Config
---@field mdopen_path? string Executable path of mdopen
---@field args? string[] Arguments to pass to mdopen commands
local cfg = {}

---@class mdopen_nvim.State
---@field initalized boolean
---@field mdopen_path? string Executable path of mdopen
---@field process vim.SystemObj?
local state = {
  initialized = false,
  process = nil,
}

--[[ Helper functions ]]

local function notify_err(msg)
  vim.notify(msg, vim.log.levels.ERROR, { title = "mdopen.nvim" })
end

---Try to asynchronously install mdopen with cargo.
---@param on_success? fun() Callback to execute on successful installation
local function install(on_success)
  vim.system("cargo install mdopen", {}, function(opts)
    if opts.code ~= 0 then
      notify_err("Failed to install mdopen.")
    elseif on_success ~= nil then
      on_success()
    end
  end)
end

local function init_mdopen_path()
  if cfg.mdopen_path then
    -- Use the path in the user's config.
    state.mdopen_path = cfg.mdopen_path
    return
  end

  local exepath = vim.fn.exepath("mdopen")
  if exepath ~= "" then
    -- Found mdopen in the path.
    state.mdopen_path = exepath
  else
    -- Try to install mdopen and get its path again.
    install(function()
      local new_path = vim.fn.exepath("mdopen")
      if new_path ~= "" then
        state.mdopen_path = new_path
      end
    end)
  end
end

---Execute mdopen for the currently opened buffer.
---@param mdopen_path string
---@param file string
local function run_mdopen(mdopen_path, file)
  if state.process then
    state.process:kill("sigint")
    state.process = nil
  end

  if vim.fn.executable(mdopen_path) == 0 then
    notify_err(("Path for mdopen at %s does not exist."):format(mdopen_path))
    return
  end

  local cmd = { mdopen_path }

  if cfg.args and #cfg.args ~= 0 then
    -- Extend cmd with args.
    for i = 1, #cfg.args do
      cmd[i + 1] = cfg.args[i]
    end
  end

  local abspath = vim.fs.abspath(vim.fs.normalize(file))

  -- mdopen doesn't work with absolute paths, so we split it into the directory and filename
  table.insert(cmd, vim.fs.basename(abspath))
  local job_opts = {
    cwd = vim.fs.dirname(abspath),
    stdout = function(err, data)
      if err then
        print("mdopen.nvim Error:", err)
      elseif data then
        print("mdopen.nvim:", data)
      end
    end,
    text = true,
  }
  job_opts.stderr = job_opts.stdout -- Use the same callback.

  state.process = vim.system(cmd, job_opts, function(_out)
    state.process = nil
  end)
end

--[[ Plugin module ]]

---@param file? string Path to the file to run mdopen on
function M.run(file)
  -- Default to full file name of current buffer
  file = file or vim.api.nvim_buf_get_name(0)

  if not state.initalized then
    init_mdopen_path()
  end

  if state.mdopen_path then
    run_mdopen(state.mdopen_path, file)
  else
    notify_err("Could not find mdopen.")
  end
end

function M.stop()
  if state.process then
    state.process:kill("sigint")
    state.process = nil
  else
    notify_err(("No mdopen process at %s."):format(file))
  end
end

---@param config mdopen_nvim.Config? custom config
---@return nil
function M.setup(config)
  cfg = config or cfg

  -- Add plugin commands
  vim.api.nvim_create_user_command("Mdopen", function(args)
    M.run(args.fargs[1])
  end, { complete = "file", nargs = "?" })

  vim.api.nvim_create_user_command("MdopenStop", function(_args)
    M.stop()
  end, {})

  local augroup = vim.api.nvim_create_augroup("mdopen", {})
  -- Kill all processes when exiting
  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = augroup,
    callback = function()
      if state.process then
        state.process:kill("sigint")
      end
    end,
  })
end

return M

local M = {}

---@class mdopen_nvim.Config
---@field mdopen_path? string Executable path of mdopen
---@field args? string[] Arguments to pass to mdopen commands
local cfg = {}

---@type vim.SystemObj?
local process = nil

--[[ Helper functions ]]

local function notify_err(msg)
  vim.notify(msg, vim.log.levels.ERROR, { title = "mdopen.nvim" })
end

---Try to asynchronously install mdopen with cargo.
---@param on_success? fun() Callback to execute on successful installation
local function install(on_success)
  if vim.fn.executable("cargo") == 0 then
    notify_err("Could not find cargo to install mdopen.")
  end

  vim.system("cargo install mdopen", {}, function(opts)
    if opts.code ~= 0 then
      notify_err("Failed to install mdopen.")
    elseif on_success ~= nil then
      on_success()
    end
  end)
end

---Execute mdopen for the currently opened buffer.
local function run_mdopen()
  if process ~= nil then
    return
  end

  if cfg.mdopen_path == nil then
    notify_err("Could not find mdopen.")
    return
  end

  if vim.fn.executable(cfg.mdopen_path) == 0 then
    notify_err(("Could not execute mdopen at %s."):format(cfg.mdopen_path))
    return
  end

  local cmd = { cfg.mdopen_path }

  if cfg.args ~= nil and #cfg.args ~= 0 then
    table.insert(cmd, table.concat(cfg.args, " "))
  end

  -- mdopen doesn't work with absolute paths, so we split split it into the
  -- directory and filename
  local filepath = vim.api.nvim_buf_get_name(0)
  table.insert(cmd, vim.fs.basename(filepath))

  local job_opts = {
    cwd = vim.fs.dirname(filepath),
    stdout = function(_err, data)
      vim.notify(data, vim.log.levels.INFO, { title = "mdopen.nvim" })
    end,
    stderr = function(_err, data)
      notify_err(data)
    end,
    text = true,
  }

  process = vim.system(cmd, job_opts, function(_out)
    process = nil
  end)
end

--[[ Plugin module ]]

function M.execute()
  if cfg.mdopen_path ~= nil and cfg.mdopen_path ~= "" then
    cfg.mdopen_path = vim.fn.exepath("mdopen")
  end

  if cfg.mdopen_path ~= "" then
    run_mdopen()
  else
    -- Couldn't find mdopen in the config or exepath, try installing
    install(function()
      M.mdopen_path = vim.fn.exepath("mdopen")
      run_mdopen()
    end)
  end
end

function M.stop()
  if process == nil then
    notify_err("Could not find the process for mdopen.")
  else
    process:kill("sigint")
  end
end

---@param config mdopen_nvim.Config? custom config
---@return nil
function M.setup(config)
  cfg = config or cfg

  -- Add plugin commands
  vim.api.nvim_create_user_command("Mdopen", function(_opts)
    M.execute()
  end, { complete = "file", nargs = "?", bang = true })

  vim.api.nvim_create_user_command("MdopenStop", function(_opts)
    M.stop()
  end, { complete = "file", nargs = "?", bang = true })
end

return M

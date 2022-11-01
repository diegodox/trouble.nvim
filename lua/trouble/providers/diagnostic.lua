local util = require("trouble.util")

---@class Lsp
local M = {}

function M.setup()
  vim.diagnostic.handlers.trouble = {
    show = M.show,
    hide = M.hide,
  }
end

---diagnostics handler's show function
---@param namespace integer
---@param bufnr integer
---@param diagnostics table
---@param opts table
---@diagnostic disable-next-line: unused-local
M.show = function(namespace, bufnr, diagnostics, opts)
  local ns = vim.diagnostic.get_namespace(namespace)
  if not ns.user_data.trouble_items then
    ns.user_data.trouble_items = {}
  end

  local items = {}
  for _, diag in ipairs(diagnostics) do
    local item = util.process_item(diag, bufnr)
    table.insert(items, item)
  end

  ns.user_data.trouble_items[bufnr] = items
  require("trouble").refresh({ auto = true, provider = "diagnostics" })
end

---diagnostics handler's hide function
---@param namespace integer
---@param bufnr integer
M.hide = function(namespace, bufnr)
  local ns = vim.diagnostic.get_namespace(namespace)
  if ns.user_data.trouble_items and ns.user_data.trouble_items[bufnr] then
    ns.user_data.trouble_items[bufnr] = {}
    require("trouble").refresh({ auto = true, provider = "diagnostics" })
  end
end

---@param options TroubleOptions
---@return Item[]
function M.diagnostics(_, buf, cb, options)
  if options.mode == "workspace_diagnostics" then
    buf = nil
  end

  local items = {}

  if vim.diagnostic then
    for _, tbl in pairs(vim.diagnostic.get_namespaces()) do
      local trouble_items = tbl.user_data.trouble_items
      if not trouble_items then
        trouble_items = {}
      end

      if not buf then
        for _, buf_items in pairs(trouble_items) do
          for _, item in pairs(buf_items) do
            table.insert(items, item)
          end
        end
      elseif trouble_items and trouble_items[buf] then
        for _, item in ipairs(trouble_items[buf]) do
          table.insert(items, item)
        end
      end
    end
  else
    ---@diagnostic disable-next-line: deprecated
    local diags = buf and { [buf] = vim.lsp.diagnostic.get(buf) } or vim.lsp.diagnostic.get_all()
    items = util.locations_to_items(diags, 1)
  end

  cb(items)
end

function M.get_signs()
  local signs = {}
  for _, v in pairs(util.severity) do
    if v ~= "Other" then
      -- pcall to catch entirely unbound or cleared out sign hl group
      local status, sign = pcall(function()
        return vim.trim(vim.fn.sign_getdefined(util.get_severity_label(v, "Sign"))[1].text)
      end)
      if not status then
        sign = v:sub(1, 1)
      end
      signs[string.lower(v)] = sign
    end
  end
  return signs
end

return M

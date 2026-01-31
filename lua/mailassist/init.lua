--------------------------------------------------------------------------------
-- Mailassist: Neovim plugin to assist with composing emails
--------------------------------------------------------------------------------


local M = {
  -- Enable or disable default keymaps.
  add_default_keymaps = true,

  -- Options concerning attachments:
  -- Enable or disable attachment warning feature.
  warn_missing_attach = true,
  -- Keywords that indicate an attachment is mentioned in the email body.
  attach_keywords = { 'attach', 'enclosed', 'pdf' },
  -- Attach warning does not apply to quotation lines. Set the start-quotation symbols here.
  quote_symbols = '>|',

  -- Options concerning completion:
  -- Manually injecting contacts
  inject_contacts = {},
  -- Files to load contacts from mutt aliases.
  mutt_alias_files = { '~/.mutt/alias', },
  -- Load contacts from various sources unconditionally.
  contacts_load_mutt_aliases = true,
  -- Load contacts from khard unconditionally
  contacts_load_khard = true,
  -- Load contacts from notmuch unconditionally
  contacts_load_notmuch = false,
}

function M.setup(opts)
  for k, v in pairs(opts) do
    M[k] = v
  end

  if M.warn_missing_attach then
    vim.api.nvim_create_autocmd({ 'BufRead', 'TextChanged', 'InsertLeave', 'InsertEnter' },
      {
        callback = M.update_attach_warning,
      })
  end

  if M.add_default_keymaps then
    M.default_keymaps()
  end
end

--------------------------------------------------------------------------------
-- In-process LSP server, e.g., for completion
--------------------------------------------------------------------------------

local contacts = nil

local function add_contacts_from_mutt_alias_file(alias_file)
  if vim.fn.filereadable(alias_file) == 0 then
    return
  end

  -- Known aliases from this file
  aliases = {}

  for line in io.lines(alias_file) do
    local alias, email = line:match('^alias%s+(%S+)%s+(.+)$')
    if alias and email then
      -- Replace known aliases in email
      for prev_alias, prev_email in pairs(aliases) do
        local pattern = prev_alias .. ','
        if email:find(pattern) then
          email = email:gsub(pattern, prev_email .. ',')
        end
      end

      aliases[alias] = email
      table.insert(contacts, { alias = alias, email = email })
    end
  end
end

function M.add_contacts_from_mutt_alias_files()
  if not M.mutt_alias_files then
    return
  end

  for _, file in ipairs(M.mutt_alias_files) do
    local alias_file = vim.fn.expand(file)
    add_contacts_from_mutt_alias_file(alias_file)
  end
end

function M.add_contacts_from_khard()
  local handle = io.popen('khard email --parsable --remove-first-line 2>/dev/null')
  if handle == nil then
    return
  end

  -- Each line is has tab-separated fields:
  -- <email> <Some name>
  for line in handle:lines() do
    local email, name = line:match('^([^\t]*)\t([^\t]*)')
    if email then
      table.insert(contacts, { name = name, email = email })
    end
  end
end

function M.add_contacts_from_notmuch()
  local handle = io.popen('notmuch address --format=json --deduplicate=address ' * ' 2>/dev/null')
  if handle == nil then
    return
  end

  local json_lines = handle:read('*a')
  local ok, decoded = pcall(vim.fn.json_decode, json_lines)
  if not ok then
    return
  end

  for _, entry in ipairs(decoded) do
    table.insert(contacts, { name = entry.name, email = entry.address })
  end
end

local function build_contacts_database()
  if contacts ~= nil then
    return
  end

  contacts = vim.deepcopy(M.inject_contacts or {})

  if M.contacts_load_mutt_aliases then
    M.add_contacts_from_mutt_alias_files()
  end
  if M.contacts_load_khard then
    M.add_contacts_from_khard()
  end
  if M.contacts_load_notmuch then
    M.add_contacts_from_notmuch()
  end

  vim.notify(tostring(#contacts) .. ' contacts loaded by mailassist', vim.log.levels.INFO)
end

local function rebuild_contacts_database()
  contacts = nil
  build_contacts_database()
end

function M.toggle_contacts_mutt_aliases()
  M.contacts_load_mutt_aliases = not M.contacts_load_mutt_aliases
  rebuild_contacts_database()
  if M.contacts_load_mutt_aliases then
    vim.notify('Mutt alias contacts loading enabled', vim.log.levels.INFO)
  else
    vim.notify('Mutt alias contacts loading disabled', vim.log.levels.INFO)
  end
end

function M.toggle_contacts_khard()
  M.contacts_load_khard = not M.contacts_load_khard
  rebuild_contacts_database()
  if M.contacts_load_khard then
    vim.notify('Khard contacts loading enabled', vim.log.levels.INFO)
  else
    vim.notify('Khard contacts loading disabled', vim.log.levels.INFO)
  end
end

function M.toggle_contacts_notmuch()
  M.contacts_load_notmuch = not M.contacts_load_notmuch
  rebuild_contacts_database()
  if M.contacts_load_notmuch then
    vim.notify('Notmuch contacts loading enabled', vim.log.levels.INFO)
  else
    vim.notify('Notmuch contacts loading disabled', vim.log.levels.INFO)
  end
end

local ms = vim.lsp.protocol.Methods
local handlers = {}

handlers[ms.initialize] = function(_, callback)
  local initializeResult = {
    capabilities = {
      -- hoverProvider = true,
      -- definitionProvider = true,
      -- referencesProvider = true,
      completionProvider = {
        triggerCharacters = { '<', '@' },
      },
    },
    serverInfo = {
      name = 'mailassist-lsp',
      version = '0.0.1',
    },
  }
  callback(nil, initializeResult)
end

local function getComplItemsNameEmail()
  build_contacts_database()

  local items = {}
  for _, contact in ipairs(contacts) do
    -- We need a mail in any case
    if contact.email then
      local item = nil

      if contact.alias then
        item = {
          label = contact.alias,
          insertText = contact.email,
          detail = contact.email,
          kind = vim.lsp.protocol.CompletionItemKind['Struct']
        }
      else
        if contact.name then
          item = {
            label = contact.name,
            insertText = contact.name .. ' <' .. contact.email .. '>',
            detail = contact.name .. ' <' .. contact.email .. '>',
            kind = vim.lsp.protocol.CompletionItemKind['Value']
          }
        else
          item = {
            label = contact.email,
            insertText = contact.email,
            detail = contact.email,
            kind = vim.lsp.protocol.CompletionItemKind['Reference']
          }
        end
      end
      if contact.organization then
        item.labelDetails = {
          detail = contact.organization,
        }
      end

      table.insert(items, item)
    end
  end

  return items
end

local function getComplItemsName()
  build_contacts_database()

  local items = {}
  for _, contact in ipairs(contacts) do
    if contact.name then
      local item = {
        label = contact.name,
        kind = vim.lsp.protocol.CompletionItemKind['Field']
      }
      if contact.organization then
        item.labelDetails = {
          detail = contact.organization,
        }
      end
      table.insert(items, item)
    end
  end
  return items
end

local function getComplItemsEmail()
  build_contacts_database()

  local items = {}
  for _, contact in ipairs(contacts) do
    if contact.email and not contact.alias then
      local item = {
        label = contact.email,
        kind = vim.lsp.protocol.CompletionItemKind['Reference']
      }
      if contact.organization then
        item.labelDetails = {
          detail = contact.organization,
        }
      end
      table.insert(items, item)
    end
  end
  return items
end

---@param params lsp.CompletionParams
---@param callback fun(err?: lsp.ResponseError, result: lsp.CompletionItem[])
handlers[ms.textDocument_completion] = function(params, callback)
  local items = {}

  -- Triggered by a triggerCharacter...
  if params.context.triggerKind == 2 and params.context.triggerCharacter == '@' then
    items = getComplItemsName()
  else
    if params.context.triggerKind == 2 and params.context.triggerCharacter == '<' then
      items = getComplItemsEmail()
    else
      items = getComplItemsNameEmail()
    end
  end

  callback(nil, {
    isIncomplete = false,
    items = items,
  })
end

local capabilities = vim.lsp.protocol.make_client_capabilities()

local function start_lsp(buf)
  ---@type vim.lsp.ClientConfig
  local client_cfg = {
    name = 'mailassist-lsp',
    cmd = function()
      return {
        request = function(method, params, callback)
          if handlers[method] then
            handlers[method](params, callback)
          end
        end,
        notify = function() end,
        is_closing = function() end,
        terminate = function() end,
      }
    end,
    capabilities = capabilities
  }
  vim.lsp.config('mailassist-lsp', client_cfg)
  return vim.lsp.start(client_cfg, { bufnr = buf, silent = false })
end

vim.api.nvim_create_autocmd('FileType', {
  pattern = 'mail',
  callback = function()
    vim.bo.omnifunc = 'v:lua.MiniCompletion.completefunc_lsp'
  end,
})

vim.api.nvim_create_autocmd('FileType', {
  pattern = { 'mail' },
  callback = function(ev)
    start_lsp(ev.buf)
  end,
})


--------------------------------------------------------------------------------
-- Add Attach: header
--------------------------------------------------------------------------------

local function add_attach_header(filename)
  if not filename or filename == '' then return end

  local win = vim.api.nvim_get_current_win()
  local cur = vim.api.nvim_win_get_cursor(win)

  local bufnr = vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local insert_line = nil

  -- Find first empty line (end of headers)
  for i, line in ipairs(lines) do
    if line == '' then
      insert_line = i - 1
      break
    end
  end
  if not insert_line then
    -- append at end if no empty line
    insert_line = #lines
  end

  -- Insert Attach: header
  vim.api.nvim_buf_set_lines(bufnr, insert_line, insert_line, false, { 'Attach: ' .. filename })

  -- Restore cursor position
  vim.api.nvim_win_set_cursor(win, cur)
end

function M.attach_file()
  -- Prompt for filename
  vim.ui.input({
      prompt = 'Attachment filename: ',
      default = vim.fn.expand('$HOME') .. '/',
      completion = 'file',
    },
    add_attach_header
  )
end

--------------------------------------------------------------------------------
-- Attachment warning code
--------------------------------------------------------------------------------

local attach_warn_message = 'Possible attachment mentioned, but no Attach: header found.'
local attachwarn_ns = vim.api.nvim_create_namespace('attachwarn')
local attachwarn_notify = false

-- Check for the presence of the Attach: header and clear or set diagnostics
function M.update_attach_warning()
  if vim.bo.filetype ~= 'mail' then
    return
  end

  vim.diagnostic.reset(attachwarn_ns, 0)
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)

  -- Check for an attach header and exit if so
  for _, line in ipairs(lines) do
    if line:match('^Attach:') then
      return
    end
  end

  local diagnostics = {}

  for linenr, line in ipairs(lines) do
    -- Skip quoted lines
    if line:match('^%s*[' .. M.quote_symbols .. ']') then
      goto continue
    end

    for _, kw in ipairs(M.attach_keywords) do
      local s, e = line:lower():find(kw)
      if s ~= nil then
        table.insert(diagnostics, {
          lnum = linenr - 1,
          col = s - 1,
          end_col = e,
          message = attach_warn_message,
          severity = vim.diagnostic.severity.WARN,
        })
      end
    end
    ::continue::
  end

  vim.diagnostic.set(attachwarn_ns, 0, diagnostics, {})

  -- Warn once but never again
  if not attachwarn_notify then
    attachwarn_notify = true
    vim.schedule(function()
      vim.notify(attach_warn_message, vim.log.levels.WARN)
    end)
  end
end

--------------------------------------------------------------------------------
-- Keymaps
--------------------------------------------------------------------------------

function M.default_keymaps()
  vim.keymap.set({ 'i', 'n' }, '<C-a>', M.attach_file, { desc = 'Add Attach: header' })
  vim.keymap.set({ 'n' }, '<localleader>ma', M.attach_file, { desc = 'Add Attach: header' })
  vim.keymap.set({ 'n' }, '<localleader>mk', M.toggle_contacts_khard, { desc = 'Toggle khard contacts' })
  vim.keymap.set({ 'n' }, '<localleader>mm', M.toggle_contacts_mutt_aliases, { desc = 'Toggle mutt alias contacts' })
  vim.keymap.set({ 'n' }, '<localleader>mn', M.toggle_contacts_notmuch, { desc = 'Toggle notmuch contacts' })
end

return M

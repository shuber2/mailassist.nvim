# mailassist.nvim

**Mailassist** is a Neovim plugin to assist with composing emails, providing
features such as attachment reminders, contact completion, and easy attachment
header insertion. Users will typically use a test-based mail client (MUA) like
mutt or neomutt and Neovim for mail composing.

## Features

- **Attachment Reminder:** Warns you if you mention an attachment in your email
  body but forget to add an `Attach:` header.
- **Attach Header Insertion:** Quickly insert an `Attach:` header with a file
  prompt.
- **Contact Completion:** Provides LSP-powered completion for email addresses
  and names from various sources:
  - Mutt alias files
  - Khard address book
  - Notmuch address database (optional)
- **Configurable Keymaps:** Default keymaps for common actions, with the
  ability to disable or customize.

It leverages modern Neovim features, like the diagnostics framework for the
attachment warning and it implements an in-process LSP server for the contact
completion.

## Installation

Use your favorite plugin manager. For example, with [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "yourusername/mailassist.nvim",
  config = function()
    require("mailassist").setup()
  end,
  ft = "mail",
}
```

## Usage

Just compose your mail. When you use a keyword for attachment then a diagnostic
warning will be placed and upon the first completion trigger the contact
database is loaded lazily. You need a completion plugin, like
[mini.complete](https://github.com/nvim-mini/mini.completion).

The default keymaps are as follows:
- `<C-a>` (insert/normal mode): Prompt to add an `Attach:` header.
- `<localleader>ma`: Add an `Attach:` header.
- `<localleader>mk`: Toggle khard contacts.
- `<localleader>mm`: Toggle mutt alias contacts.
- `<localleader>mn`: Toggle notmuch contacts.


## Configuration

Call `require("mailassist").setup({ ... })` with your options. The default options are:

```lua
require("mailassist").setup({
  -- Enable or disable default keymaps.
  add_default_keymaps = true,
  -- Enable or disable attachment warning feature.
  warn_missing_attach = true,
  -- Keywords that indicate an attachment is mentioned in the email body.
  attach_keywords = { 'attach', 'enclosed', 'pdf' },
  -- Attach warning does not apply to quotation lines. Set the start-quotation symbols here.
  quote_symbols = '>|',
  -- Files to load contacts from mutt aliases.
  mutt_alias_files = { "~/.mutt/alias", },
  -- Load contacts from various sources unconditionally.
  contacts_load_mutt_aliases = true,
  -- Load contacts from khard unconditionally
  contacts_load_khard = true,
  -- Load contacts from notmuch unconditionally
  contacts_load_notmuch = false,
})
```

In order to change the default keymaps, adapt the key bindings in the default mapping below:

```lua


function M.default_keymaps()
  vim.keymap.set({ 'i', 'n' }, '<C-a>', M.attach_file, { desc = 'Add Attach: header' })
  vim.keymap.set({ 'n' }, '<localleader>ma', M.attach_file, { desc = 'Add Attach: header' })
  vim.keymap.set({ 'n' }, '<localleader>mk', M.toggle_contacts_khard, { desc = 'Toggle khard contacts' })
  vim.keymap.set({ 'n' }, '<localleader>mm', M.toggle_contacts_mutt_aliases, { desc = 'Toggle mutt alias contacts' })
  vim.keymap.set({ 'n' }, '<localleader>mn', M.toggle_contacts_notmuch, { desc = 'Toggle notmuch contacts' })
end

```

## Requirements

- Neovim 0.10+
- Optional: [khard](https://github.com/scheibler/khard), [notmuch](https://notmuchmail.org/), mutt

## License

MIT

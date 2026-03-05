--[[
=====================================================================
==================== NEOVIM SINGLE-FILE CONFIG ======================
============= Show the structure on pressing <leader>st =============
=====================================================================
--]]

vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

-- BOOKMARK: OPTIONS

-- UI & Visuals
vim.g.have_nerd_font = true
vim.o.number = true
vim.o.showmode = false
vim.o.signcolumn = 'yes'
vim.o.cursorline = true
vim.o.title = true

-- Window & Buffer behavior
vim.o.splitright = true
vim.o.splitbelow = true
vim.wo.wrap = false
vim.o.breakindent = true
vim.o.scrolloff = 10
vim.opt.listchars = { tab = '» ', trail = '·', nbsp = '␣' }
vim.o.list = true

-- Search & Case
vim.o.ignorecase = true
vim.o.smartcase = true
vim.o.inccommand = 'split'

-- System & Performance
vim.o.mouse = 'a'
vim.o.confirm = true
vim.o.undofile = true
vim.o.updatetime = 250
vim.o.timeoutlen = 300
vim.opt.swapfile = false
-- Use schedule for clipboard to prevent startup delay
vim.schedule(function()
  vim.o.clipboard = 'unnamedplus'
end)

-- BOOKMARK: AUTOCOMMANDS

local augroup = vim.api.nvim_create_augroup
local autocmd = vim.api.nvim_create_autocmd

-- Highlight on Yank
autocmd('TextYankPost', {
  desc = 'Highlight when yanking (copying) text',
  group = vim.api.nvim_create_augroup('kickstart-highlight-yank', { clear = true }),
  callback = function()
    vim.hl.on_yank()
  end,
})

-- Restore cursor position
autocmd('BufReadPost', {
  group = augroup('restore_position', { clear = true }),
  callback = function()
    local exclude = { 'gitcommit' }
    local buf = vim.api.nvim_get_current_buf()
    if vim.tbl_contains(exclude, vim.bo[buf].filetype) then
      return
    end

    local mark = vim.api.nvim_buf_get_mark(buf, '"')
    local line_count = vim.api.nvim_buf_line_count(buf)
    if mark[1] > 0 and mark[1] <= line_count then
      pcall(vim.api.nvim_win_set_cursor, 0, mark)
      vim.api.nvim_feedkeys('zvzz', 'n', true)
    end
  end,
  desc = 'Restore cursor position after reopening file',
})

-- MiniFiles: let ESC can also close the popup
autocmd('User', {
  pattern = 'MiniFilesBufferCreate',
  callback = function(args)
    local buf_id = args.data.buf_id
    vim.keymap.set('n', '<Esc>', require('mini.files').close, { buffer = buf_id })
  end,
})

-- BOOKMARK: LAZY BOOTSTRAP

local lazypath = vim.fn.stdpath 'data' .. '/lazy/lazy.nvim'
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local lazyrepo = 'https://github.com/folke/lazy.nvim.git'
  local out = vim.fn.system { 'git', 'clone', '--filter=blob:none', '--branch=stable', lazyrepo, lazypath }
  if vim.v.shell_error ~= 0 then
    error('Error cloning lazy.nvim:\n' .. out)
  end
end
vim.opt.rtp:prepend(lazypath)

-- BOOKMARK: PLUGINS
require('lazy').setup({
  -- BOOKMARK: PLUGINS: GENERAL UI & THEMES
  {
    'folke/tokyonight.nvim',
    priority = 1000,
    config = function()
      ---@diagnostic disable-next-line: missing-fields
      require('tokyonight').setup {
        transparent = true,
        styles = {
          sidebars = 'transparent',
          floats = 'transparent',
        },
      }

      vim.cmd.colorscheme 'tokyonight-night'
    end,
  },

  -- A curated collection of ascii art and utilities for your Neovim dashboard.
  {
    'MaximilianLloyd/ascii.nvim',
    dependencies = {
      'MunifTanjim/nui.nvim',
    },
  },

  -- Blazing fast indentation style detection for Neovim written in Lua.
  {
    'NMAC427/guess-indent.nvim',
    config = function()
      require('guess-indent').setup {}
    end,
  },

  -- BOOKMARK: PLUGINS: NAVIGATION & SEARCH

  -- A highly extendable fuzzy finder over lists
  {
    'nvim-telescope/telescope.nvim',
    event = 'VimEnter',
    dependencies = {
      'nvim-lua/plenary.nvim',
      {
        'nvim-telescope/telescope-fzf-native.nvim',
        build = 'make',
        cond = function()
          return vim.fn.executable 'make' == 1
        end,
      },
      { 'nvim-telescope/telescope-ui-select.nvim' },

      { 'nvim-tree/nvim-web-devicons', enabled = vim.g.have_nerd_font },
    },
    config = function()
      require('telescope').setup {
        extensions = {
          ['ui-select'] = {
            require('telescope.themes').get_dropdown(),
          },
        },
      }

      pcall(require('telescope').load_extension, 'fzf')
      pcall(require('telescope').load_extension, 'ui-select')
    end,
  },

  -- WhichKey helps you remember your Neovim keymaps,
  -- by showing available keybindings in a popup as you type.
  {
    'folke/which-key.nvim',
    event = 'VimEnter',
    opts = {
      delay = 0,
      icons = {
        mappings = vim.g.have_nerd_font,
        keys = vim.g.have_nerd_font and {} or {
          Up = '<Up> ',
          Down = '<Down> ',
          Left = '<Left> ',
          Right = '<Right> ',
          C = '<C-…> ',
          M = '<M-…> ',
          D = '<D-…> ',
          S = '<S-…> ',
          CR = '<CR> ',
          Esc = '<Esc> ',
          ScrollWheelDown = '<ScrollWheelDown> ',
          ScrollWheelUp = '<ScrollWheelUp> ',
          NL = '<NL> ',
          BS = '<BS> ',
          Space = '<Space> ',
          Tab = '<Tab> ',
          F1 = '<F1>',
          F2 = '<F2>',
          F3 = '<F3>',
          F4 = '<F4>',
          F5 = '<F5>',
          F6 = '<F6>',
          F7 = '<F7>',
          F8 = '<F8>',
          F9 = '<F9>',
          F10 = '<F10>',
          F11 = '<F11>',
          F12 = '<F12>',
        },
      },

      spec = {
        { '<leader>s', group = '[S]earch' },
        { '<leader>t', group = '[T]oggle' },
        { '<leader>h', group = 'Git [H]unk', mode = { 'n', 'v' } },
      },
    },
  },

  -- BOOKMARK: PLUGINS: LSP, COMPLETION & LINTING

  -- A collection of LSP server configurations for the Nvim LSP client.
  --  NOTE: (opinionated) We make cmake-tools to generate build files
  --        in $HOME/.cache/cmake_builds
  {
    'neovim/nvim-lspconfig',
    dependencies = {
      { 'mason-org/mason.nvim', opts = {} },
      'mason-org/mason-lspconfig.nvim',
      'WhoIsSethDaniel/mason-tool-installer.nvim',
      { 'j-hui/fidget.nvim', opts = {} },
      'saghen/blink.cmp',
      'Civitasv/cmake-tools.nvim',
    },
    config = function()
      vim.api.nvim_create_autocmd('LspAttach', {
        group = vim.api.nvim_create_augroup('kickstart-lsp-attach', { clear = true }),
        callback = function(event)
          local map = function(keys, func, desc, mode)
            mode = mode or 'n'
            vim.keymap.set(mode, keys, func, { buffer = event.buf, desc = 'LSP: ' .. desc })
          end

          map('grn', vim.lsp.buf.rename, '[R]e[n]ame')
          map('gra', vim.lsp.buf.code_action, '[G]oto Code [A]ction', { 'n', 'x' })
          map('grr', require('telescope.builtin').lsp_references, '[G]oto [R]eferences')
          map('gri', require('telescope.builtin').lsp_implementations, '[G]oto [I]mplementation')
          map('grd', require('telescope.builtin').lsp_definitions, '[G]oto [D]efinition')
          map('grD', vim.lsp.buf.declaration, '[G]oto [D]eclaration')
          map('gO', require('telescope.builtin').lsp_document_symbols, 'Open Document Symbols')
          map('gW', require('telescope.builtin').lsp_dynamic_workspace_symbols, 'Open Workspace Symbols')
          map('grt', require('telescope.builtin').lsp_type_definitions, '[G]oto [T]ype Definition')

          local function client_supports_method(client, method, bufnr)
            if vim.fn.has 'nvim-0.11' == 1 then
              return client:supports_method(method, bufnr)
            else
              return client.supports_method(method, { bufnr = bufnr })
            end
          end

          local client = vim.lsp.get_client_by_id(event.data.client_id)
          if client and client_supports_method(client, vim.lsp.protocol.Methods.textDocument_documentHighlight, event.buf) then
            local highlight_augroup = vim.api.nvim_create_augroup('kickstart-lsp-highlight', { clear = false })
            vim.api.nvim_create_autocmd({ 'CursorHold', 'CursorHoldI' }, {
              buffer = event.buf,
              group = highlight_augroup,
              callback = vim.lsp.buf.document_highlight,
            })

            vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI' }, {
              buffer = event.buf,
              group = highlight_augroup,
              callback = vim.lsp.buf.clear_references,
            })

            vim.api.nvim_create_autocmd('LspDetach', {
              group = vim.api.nvim_create_augroup('kickstart-lsp-detach', { clear = true }),
              callback = function(event2)
                vim.lsp.buf.clear_references()
                vim.api.nvim_clear_autocmds { group = 'kickstart-lsp-highlight', buffer = event2.buf }
              end,
            })
          end

          if client and client_supports_method(client, vim.lsp.protocol.Methods.textDocument_inlayHint, event.buf) then
            map('<leader>th', function()
              vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled { bufnr = event.buf })
            end, '[T]oggle Inlay [H]ints')
          end
        end,
      })

      vim.diagnostic.config {
        severity_sort = true,
        float = { border = 'rounded', source = 'if_many' },
        underline = { severity = vim.diagnostic.severity.ERROR },
        signs = vim.g.have_nerd_font and {
          text = {
            [vim.diagnostic.severity.ERROR] = '󰅚 ',
            [vim.diagnostic.severity.WARN] = '󰀪 ',
            [vim.diagnostic.severity.INFO] = '󰋽 ',
            [vim.diagnostic.severity.HINT] = '󰌶 ',
          },
        } or {},
        virtual_text = {
          source = 'if_many',
          spacing = 2,
          format = function(diagnostic)
            local diagnostic_message = {
              [vim.diagnostic.severity.ERROR] = diagnostic.message,
              [vim.diagnostic.severity.WARN] = diagnostic.message,
              [vim.diagnostic.severity.INFO] = diagnostic.message,
              [vim.diagnostic.severity.HINT] = diagnostic.message,
            }
            return diagnostic_message[diagnostic.severity]
          end,
        },
      }

      local capabilities = require('blink.cmp').get_lsp_capabilities()

      local os_sep = package.config:sub(1, 1)
      local cwd = vim.fn.getcwd()
      local project_name = vim.fn.fnamemodify(cwd, ':t')
      local build_dir = os.getenv 'HOME' .. os_sep .. '.cache' .. os_sep .. 'cmake_builds' .. os_sep .. project_name

      local servers = {
        lua_ls = {
          settings = {
            Lua = {
              completion = {
                callSnippet = 'Replace',
              },
            },
          },
        },
      }

      local ensure_installed = vim.tbl_keys(servers or {})
      vim.list_extend(ensure_installed, {
        'stylua',
      })
      require('mason-tool-installer').setup { ensure_installed = ensure_installed }

      require('mason-lspconfig').setup {
        ensure_installed = {},
        automatic_installation = false,
        handlers = {
          function(server_name)
            local server = servers[server_name] or {}
            server.capabilities = vim.tbl_deep_extend('force', {}, capabilities, server.capabilities or {})
            require('lspconfig')[server_name].setup(server)
          end,
        },
      }

      vim.lsp.config['clangd'] = {
        cmd = {
          'clangd',
          '--compile-commands-dir=' .. build_dir,
          '--query-driver=/nix/store/*-gcc-wrapper-*/bin/g++,/nix/store/*-gcc-wrapper-*/bin/gcc',
          '--background-index',
        },
        filetypes = { 'c', 'cpp', 'objc', 'objcpp', 'cuda' },
        -- root_markers is the Nvim 0.11 replacement for root_dir
        root_markers = { 'compile_commands.json', '.git' },
        capabilities = capabilities,
      }

      vim.lsp.enable 'clangd'
    end,
  },

  -- Lightweight yet powerful formatter plugin for Neovim
  {
    'stevearc/conform.nvim',
    event = { 'BufWritePre' },
    cmd = { 'ConformInfo' },
    keys = {
      {
        '<leader>f',
        function()
          require('conform').format { async = true, lsp_format = 'fallback' }
        end,
        mode = '',
        desc = '[F]ormat buffer',
      },
    },
    opts = {
      notify_on_error = false,
      format_on_save = false,
    },
  },

  -- Performant, batteries-included completion plugin for Neovim
  {
    'saghen/blink.cmp',
    event = 'VimEnter',
    version = '*',
    dependencies = {
      {
        'L3MON4D3/LuaSnip',
        version = '2.*',
        build = (function()
          if vim.fn.has 'win32' == 1 or vim.fn.executable 'make' == 0 then
            return
          end
          return 'make install_jsregexp'
        end)(),
        dependencies = {
          'rafamadriz/friendly-snippets',
        },
        opts = {},
        config = function()
          require('luasnip.loaders.from_vscode').lazy_load()
        end,
      },
      'folke/lazydev.nvim',
    },
    opts = {
      keymap = {
        preset = 'super-tab',
      },

      appearance = {
        nerd_font_variant = 'mono',
      },

      completion = {
        documentation = { auto_show = false, auto_show_delay_ms = 500 },
      },

      sources = {
        default = { 'lsp', 'path', 'snippets', 'buffer', 'lazydev' },
        providers = {
          lazydev = { module = 'lazydev.integrations.blink', score_offset = 100 },
          buffer = {
            opts = {
              get_bufnrs = function()
                return vim.api.nvim_list_bufs()
              end,
            },
          },
        },
      },

      snippets = { preset = 'luasnip' },
      fuzzy = { implementation = 'lua' },
      signature = { enabled = true },
    },
  },

  -- Highlight your todo comments in different styles
  {
    'folke/todo-comments.nvim',
    event = 'VimEnter',
    dependencies = { 'nvim-lua/plenary.nvim' },
    opts = {
      signs = false,
      keywords = {
        BOOKMARK = {
          icon = ' ',
          color = 'info',
        },
      },
    },
  },

  -- BOOKMARK: PLUGINS: TREESITTER & SYNTAX

  -- The goal of nvim-treesitter is both to provide a simple and
  -- easy way to use the interface for tree-sitter in Neovim and
  -- to provide some basic functionality such as highlighting
  -- based on it.
  {
    'nvim-treesitter/nvim-treesitter',
    build = ':TSUpdate',
    opts = {
      ensure_installed = {
        'bash',
        'c',
        'diff',
        'html',
        'lua',
        'luadoc',
        'markdown',
        'markdown_inline',
        'query',
        'vim',
        'vimdoc',
      },
      auto_install = true,
      highlight = {
        enable = true,
        additional_vim_regex_highlighting = { 'ruby' },
      },
      indent = { enable = true, disable = { 'ruby' } },
    },
  },

  -- Show code context like context.vim
  {
    'nvim-treesitter/nvim-treesitter-context',
    opts = function()
      require('treesitter-context').setup {
        enable = true,
        multiwindow = false,
        max_lines = 0,
        min_window_height = 0,
        line_numbers = true,
        multiline_threshold = 20,
        trim_scope = 'outer',
        mode = 'cursor',
        separator = nil,
        zindex = 20,
        on_attach = nil,
      }
    end,
  },

  -- A code outline window for skimming and quick navigation.
  {
    'stevearc/aerial.nvim',
    opts = {},
    dependencies = {
      'nvim-treesitter/nvim-treesitter',
      'nvim-tree/nvim-web-devicons',
    },
    config = function()
      require('aerial').setup {
        layout = {
          default_direction = 'prefer_left',
          placement = 'edge',
          max_width = { 40, 0.2 },
          min_width = 20,
        },
        on_attach = function(bufnr)
          vim.keymap.set('n', '{', '<cmd>AerialPrev<CR>', { buffer = bufnr })
          vim.keymap.set('n', '}', '<cmd>AerialNext<CR>', { buffer = bufnr })
        end,
        close_automatic_events = { 'unsupported' },
        open_automatic = function(bufnr)
          local auto_filetypes = { 'python', 'c', 'cpp', 'javascript' }
          local ft = vim.api.nvim_get_option_value('filetype', { buf = bufnr })

          for _, type in ipairs(auto_filetypes) do
            if ft == type then
              return true
            end
          end

          return false
        end,
      }
    end,
  },

  -- BOOKMARK: PLUGINS: TOOLS & EXTRAS

  -- Library of 40+ independent Lua modules improving overall Neovim experience with minimal effort.
  {
    'echasnovski/mini.nvim',
    config = function()
      -- Navigate and manipulate file system
      require('mini.files').setup()

      -- Jump within visible lines via iterative label filtering
      require('mini.jump2d').setup()

      -- Visualize and operate on indent scope
      require('mini.indentscope').setup()

      -- Fast and flexible start screen
      local art_lines = require('ascii').get_random_global()
      require('mini.starter').setup {
        header = art_lines and table.concat(art_lines, '\n') or '',
      }

      -- Minimal and fast statusline module with opinionated default look
      require('mini.statusline').setup()

      -- Automatic highlighting of word under cursor
      require('mini.cursorword').setup()

      local statusline = require 'mini.statusline'
      statusline.setup { use_icons = vim.g.have_nerd_font }

      ---@diagnostic disable-next-line: duplicate-set-field
      statusline.section_location = function()
        return '%2l:%-2v'
      end
    end,
  },

  -- A neovim plugin to persist and toggle multiple terminals during an editing session
  {
    'akinsho/toggleterm.nvim',
    version = '*',
    config = function()
      require('toggleterm').setup {
        open_mapping = [[<c-\>]],
      }
    end,
  },

  -- BOOKMARK: PLUGINS: GIT

  -- Plugin for calling lazygit from within neovim.
  {
    'kdheepak/lazygit.nvim',
    lazy = true,
    cmd = {
      'LazyGit',
      'LazyGitConfig',
      'LazyGitCurrentFile',
      'LazyGitFilter',
      'LazyGitFilterCurrentFile',
    },
    dependencies = {
      'nvim-lua/plenary.nvim',
    },
    keys = {
      { '<leader>lg', '<cmd>LazyGit<cr>', desc = 'open [L]azy[G]it' },
    },
  },

  -- Deep buffer integration for Git.
  {
    'lewis6991/gitsigns.nvim',
    opts = {
      signs = {
        add = { text = '+' },
        change = { text = '~' },
        delete = { text = '_' },
        topdelete = { text = '‾' },
        changedelete = { text = '~' },
      },
    },
  },

  -- BOOKMARK: PLUGINS: LANGUAGE SPECIFIC DEV TOOLS

  -- lazydev.nvim is a plugin that properly configures LuaLS for
  -- editing your Neovim config by lazily updating your workspace libraries.
  {
    'folke/lazydev.nvim',
    ft = 'lua',
    opts = {
      library = {
        { path = '${3rd}/luv/library', words = { 'vim%.uv' } },
      },
    },
  },

  -- Plugin to improve viewing Markdown files in Neovim.
  {
    'MeanderingProgrammer/render-markdown.nvim',
    dependencies = { 'nvim-treesitter/nvim-treesitter', 'nvim-mini/mini.nvim' },
    opts = {},
  },

  -- Preview Markdown in your modern browser with synchronised scrolling and flexible configuration.
  {
    'iamcco/markdown-preview.nvim',
    cmd = { 'MarkdownPreviewToggle', 'MarkdownPreview', 'MarkdownPreviewStop' },
    build = 'cd app && yarn install',
    init = function()
      vim.g.mkdp_filetypes = { 'markdown' }
    end,
    ft = { 'markdown' },
  },
  {
    'windwp/nvim-autopairs',
    event = 'InsertEnter',
    opts = {},
  },

  -- CMake integration in Neovim.
  {
    'Civitasv/cmake-tools.nvim',
    opts = {
      cmake_use_preset = false,
      cmake_build_directory = function()
        local os_sep = package.config:sub(1, 1)
        local cwd = vim.fn.getcwd()
        local project_name = vim.fn.fnamemodify(cwd, ':t')
        local directory = os.getenv 'HOME' .. os_sep .. '.cache' .. os_sep .. 'cmake_builds' .. os_sep .. project_name

        return directory
      end,
      cmake_generate_options = { '-DCMAKE_EXPORT_COMPILE_COMMANDS=1' },
      cmake_compile_commands_options = {
        action = 'lsp', -- This stops the symlink and notifies LSP instead
      },
    },
  },
}, {
  -- BOOKMARK: Lazy Config
  ui = {
    icons = vim.g.have_nerd_font and {} or {
      cmd = '⌘',
      config = '🛠',
      event = '📅',
      ft = '📂',
      init = '⚙',
      keys = '🗝',
      plugin = '🔌',
      runtime = '💻',
      require = '🌙',
      source = '📄',
      start = '🚀',
      task = '📌',
      lazy = '💤 ',
    },
  },
  lockfile = vim.fn.stdpath 'data' .. '/lazy-lock.json',
})

-- BOOKMARK: KEY MAPPINGS

-- BOOKMARK: KEYMAPPING: Basic File Operations
vim.keymap.set('n', '<leader>w', '<cmd>w<CR>', { desc = '[W]rite to current file' })
vim.keymap.set('n', '<leader>q', '<cmd>quit<CR>', { desc = '[Q]uit' })
vim.keymap.set('n', '<leader>Q', '<cmd>quitall<CR>', { desc = '[Q]uit all' })

-- BOOKMARK: KEYMAPPING: UI Toggles
vim.keymap.set('n', '<leader>e', function()
  if not require('mini.files').close() then
    require('mini.files').open()
  end
end, { desc = 'Toggle Mini.fil[e]s' })
vim.keymap.set('n', '<leader>tw', function()
  vim.wo.wrap = not vim.wo.wrap
end, { desc = '[T]oggle [w]rap/unwrap' })

vim.keymap.set('n', '<leader>tp', '<cmd>MarkdownPreviewToggle<CR>', { desc = '[T]oggle Markdown[P]review' })
vim.keymap.set('n', '<leader>ta', '<cmd>AerialToggle!<CR>', { desc = '[T]oggle [A]erial outline' })
vim.keymap.set('n', '<leader>tv', function()
  if vim.wo.colorcolumn == '' then
    vim.wo.colorcolumn = '80,120'
  else
    vim.wo.colorcolumn = ''
  end
end, { desc = '[T]oggle [v]ertical line at 80 and 120' })

-- BOOKMARK: KEYMAPPING: Navigation
vim.keymap.set('n', '<Esc>', '<cmd>nohlsearch<CR>')
vim.keymap.set('n', '<leader>d', vim.diagnostic.setloclist, { desc = 'Open [d]iagnostic quickfix list' })

local builtin = require 'telescope.builtin'
vim.keymap.set('n', '<leader>sh', builtin.help_tags, { desc = '[S]earch [H]elp' })
vim.keymap.set('n', '<leader>sk', builtin.keymaps, { desc = '[S]earch [K]eymaps' })
vim.keymap.set('n', '<leader>sf', builtin.find_files, { desc = '[S]earch [F]iles' })
vim.keymap.set('n', '<leader>ss', builtin.builtin, { desc = '[S]earch [S]elect Telescope' })
vim.keymap.set('n', '<leader>sw', builtin.grep_string, { desc = '[S]earch current [W]ord' })
vim.keymap.set('n', '<leader>sg', builtin.live_grep, { desc = '[S]earch by [G]rep' })
vim.keymap.set('n', '<leader>sd', builtin.diagnostics, { desc = '[S]earch [D]iagnostics' })
vim.keymap.set('n', '<leader>sr', builtin.resume, { desc = '[S]earch [R]esume' })
vim.keymap.set('n', '<leader>s.', builtin.oldfiles, { desc = '[S]earch Recent Files ("." for repeat)' })
vim.keymap.set('n', '<leader><leader>', builtin.buffers, { desc = '[ ] Find existing buffers' })
vim.keymap.set('n', '<leader>st', '<cmd>Telescope todo-comments<cr>', { desc = '[S]earch [T]odos/Bookmarks' })

vim.keymap.set('n', '<leader>/', function()
  builtin.current_buffer_fuzzy_find(require('telescope.themes').get_dropdown {
    winblend = 10,
    previewer = false,
  })
end, { desc = '[/] Fuzzily search in current buffer' })

vim.keymap.set('n', '<leader>s/', function()
  builtin.live_grep {
    grep_open_files = true,
    prompt_title = 'Live Grep in Open Files',
  }
end, { desc = '[S]earch [/] in Open Files' })

vim.keymap.set('n', '<leader>sn', function()
  builtin.find_files { cwd = vim.fn.stdpath 'config' }
end, { desc = '[S]earch [N]eovim files' })

-- BOOKMARK: KEYMAPPING: Window Navigation (Ctrl+hjkl)
vim.keymap.set('n', '<C-h>', '<C-w><C-h>', { desc = 'Move focus to the left window' })
vim.keymap.set('n', '<C-l>', '<C-w><C-l>', { desc = 'Move focus to the right window' })
vim.keymap.set('n', '<C-j>', '<C-w><C-j>', { desc = 'Move focus to the lower window' })
vim.keymap.set('n', '<C-k>', '<C-w><C-k>', { desc = 'Move focus to the upper window' })

-- Terminal Exit
vim.keymap.set('t', '<Esc><Esc>', '<C-\\><C-n>', { desc = 'Exit terminal mode' })

-- vim: ts=2 sts=2 sw=2 et

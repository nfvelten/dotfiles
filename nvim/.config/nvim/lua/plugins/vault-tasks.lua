-- Vault workflow — tasks, captura, navegação
-- <leader>va — tasks de trabalho
-- <leader>vp — tasks pessoais
-- <leader>vd — tasks da daily note de hoje
-- <leader>vf — busca fulltext no vault
-- <leader>vn — nova nota
-- <leader>vb — backlinks da nota atual
-- <leader>vm — navegar vault (MOC)
-- <leader>vi — captura rápida → Inbox
-- <leader>vg — lazygit no vault
-- [[ em insert mode — inserir wikilink

-- ── Task picker ──────────────────────────────────────────────────────────────

local function pick_tasks(opts)
  local cmd = { "rg", "--vimgrep", "--no-heading", "-e", "[*-] \\[ \\] #task" }
  for _, arg in ipairs(opts.args or {}) do
    table.insert(cmd, arg)
  end
  table.insert(cmd, opts.cwd)

  local output = vim.fn.systemlist(cmd)
  local items = {}
  for _, line in ipairs(output) do
    local file, lnum, text = line:match("^(.+):(%d+):%d+:(.+)$")
    if file and text then
      local skip = false
      for _, tag in ipairs(opts.exclude_tags or {}) do
        if text:find("#" .. tag, 1, true) then skip = true; break end
      end
      if opts.require_tag and not text:find("#" .. opts.require_tag, 1, true) then
        skip = true
      end
      if skip then goto continue end

      local clean = text:gsub("^%s*[%*%-]%s*%[%s*%]%s*", ""):gsub("#task%s*", "")
      local tags = {}
      for tag in text:gmatch("#(%S+)") do
        if tag ~= "task" then table.insert(tags, "#" .. tag) end
      end
      local label = clean:match("^%s*(.-)%s*$")
      if #tags > 0 then
        label = label .. "  " .. table.concat(tags, " ")
      end
      table.insert(items, {
        text = label,
        file = file,
        pos = { tonumber(lnum), 0 },
      })
      ::continue::
    end
  end

  table.sort(items, function(a, b)
    local sa = vim.loop.fs_stat(a.file)
    local sb = vim.loop.fs_stat(b.file)
    return (sa and sa.mtime.sec or 0) > (sb and sb.mtime.sec or 0)
  end)

  if #items == 0 then
    vim.notify("Nenhuma task encontrada", vim.log.levels.INFO)
    return
  end

  Snacks.picker.pick({
    title = opts.title,
    items = items,
    format = "text",
    win = {
      input = {
        keys = {
          ["<C-x>"] = { "mark_done", mode = { "n", "i" } },
        },
      },
    },
    actions = {
      mark_done = function(picker)
        local item = picker:current()
        if not item or not item.file then return end
        local lines = vim.fn.readfile(item.file)
        local lnum = item.pos[1]
        if lines[lnum] then
          lines[lnum] = lines[lnum]:gsub("%[%s%]", "[x]", 1)
          lines[lnum] = vim.trim(lines[lnum]) .. " ✅ " .. os.date("%d-%m-%Y")
          vim.fn.writefile(lines, item.file)
          vim.notify("Task concluída ✓", vim.log.levels.INFO)
          picker:close()
        end
      end,
    },
  })
end

-- ── Captura rápida ───────────────────────────────────────────────────────────

local function captura_rapida()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].filetype = "markdown"

  local width = 64
  local height = 8
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = math.floor((vim.o.lines - height) / 2),
    col = math.floor((vim.o.columns - width) / 2),
    style = "minimal",
    border = "rounded",
    title = "  Captura Rápida  [Ctrl+S salva · Esc cancela] ",
    title_pos = "center",
  })

  vim.cmd("startinsert")

  local function save_and_close()
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    local content = vim.tbl_filter(function(l) return l ~= "" end, lines)
    vim.api.nvim_win_close(win, true)
    if #content == 0 then return end

    local inbox = vim.fn.expand("~/amphora/Fleeting/Inbox.md")
    local existing = vim.fn.readfile(inbox)
    table.insert(existing, "")
    table.insert(existing, "## " .. os.date("%d-%m-%Y %H:%M"))
    for _, l in ipairs(content) do
      table.insert(existing, l)
    end
    vim.fn.writefile(existing, inbox)
    vim.notify("Salvo no Inbox ✓", vim.log.levels.INFO)
  end

  vim.keymap.set({ "n", "i" }, "<C-s>", save_and_close, { buffer = buf, nowait = true })
  vim.keymap.set("n", "<Esc>", function() vim.api.nvim_win_close(win, true) end, { buffer = buf })
end

-- ── Nova nota ────────────────────────────────────────────────────────────────

local function daily_path()
  local months = {
    "Janeiro", "Fevereiro", "Março", "Abril", "Maio", "Junho",
    "Julho", "Agosto", "Setembro", "Outubro", "Novembro", "Dezembro",
  }
  return vim.fn.expand("~/amphora/Daily Notes/")
    .. os.date("%Y") .. "/" .. months[tonumber(os.date("%m"))]
end

local function new_note()
  vim.ui.input({ prompt = "Nome da nota: " }, function(name)
    if not name or name == "" then return end
    local date = os.date("%d-%m-%Y")
    local path = vim.fn.expand("~/amphora/Pessoal") .. "/" .. name .. ".md"
    if vim.fn.filereadable(path) == 1 then
      vim.cmd("edit " .. vim.fn.fnameescape(path))
      return
    end
    vim.fn.writefile({
      "---", "tags: [tema]", "criado: " .. date, "---",
      "# " .. name, "", "",
    }, path)
    vim.cmd("edit " .. vim.fn.fnameescape(path))
    local daily = daily_path() .. "/" .. date .. ".md"
    if vim.fn.filereadable(daily) == 1 then
      local content = vim.fn.readfile(daily)
      for i, line in ipairs(content) do
        if line:match("Log de Notas") then
          table.insert(content, i + 1, "* [[" .. name .. "]]")
          vim.fn.writefile(content, daily)
          break
        end
      end
    end
  end)
end

-- ── Autocmd: [[ wikilink em insert mode ──────────────────────────────────────

vim.api.nvim_create_autocmd("FileType", {
  pattern = "markdown",
  group = vim.api.nvim_create_augroup("VaultWikilink", { clear = true }),
  callback = function()
    vim.keymap.set("i", "[[", function()
      vim.api.nvim_put({ "[[" }, "c", true, true)
      Snacks.picker.files({
        cwd = vim.fn.expand("~/amphora"),
        title = "Inserir Wikilink",
        args = {
          "--glob", "*.md",
          "--glob", "!Templates/**",
          "--glob", "!README.md",
          "--glob", "!CLAUDE.md",
        },
        confirm = function(picker, item)
          picker:close()
          if item then
            local note = vim.fn.fnamemodify(item.file, ":t:r")
            vim.api.nvim_put({ note .. "]]" }, "c", true, true)
          end
        end,
      })
    end, { buffer = true, nowait = true })
  end,
})

-- ── Keybindings ──────────────────────────────────────────────────────────────

local vault_args = {
  "--glob", "*.md",
  "--glob", "!Templates/**",
  "--glob", "!**/Finalizadas/**",
  "--glob", "!**/Lugares/**",
  "--glob", "!**/Reviews/**",
  "--glob", "!*Lista de compras*",
  "--glob", "!README.md",
  "--glob", "!CLAUDE.md",
}

return {
  "folke/snacks.nvim",
  keys = {
    {
      "<leader>va",
      function()
        pick_tasks({
          cwd = vim.fn.expand("~/amphora"),
          title = "Tasks — Trabalho",
          args = vault_args,
          exclude_tags = { "pessoal" },
        })
      end,
      desc = "Tasks de trabalho (vault)",
    },
    {
      "<leader>vp",
      function()
        pick_tasks({
          cwd = vim.fn.expand("~/amphora"),
          title = "Tasks — Pessoal",
          args = vault_args,
          require_tag = "pessoal",
        })
      end,
      desc = "Tasks pessoais (vault)",
    },
    {
      "<leader>vd",
      function()
        pick_tasks({
          cwd = daily_path(),
          title = "Tasks de Hoje",
          args = { "--glob", "*.md" },
        })
      end,
      desc = "Tasks de hoje (daily note)",
    },
    {
      "<leader>vf",
      function()
        Snacks.picker.grep({
          cwd = vim.fn.expand("~/amphora"),
          title = "Busca — Vault",
          args = {
            "--glob", "*.md",
            "--glob", "!Templates/**",
            "--glob", "!README.md",
            "--glob", "!CLAUDE.md",
          },
        })
      end,
      desc = "Busca fulltext no vault",
    },
    {
      "<leader>vn",
      new_note,
      desc = "Nova nota no vault",
    },
    {
      "<leader>vb",
      function()
        local name = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ":t:r")
        if name == "" then
          vim.notify("Nenhum arquivo aberto", vim.log.levels.WARN)
          return
        end
        Snacks.picker.grep({
          cwd = vim.fn.expand("~/amphora"),
          search = "\\[\\[" .. name,
          regex = true,
          live = false,
          title = "Backlinks — " .. name,
          args = { "--glob", "*.md" },
        })
      end,
      desc = "Backlinks da nota atual",
    },
    {
      "<leader>vm",
      function()
        Snacks.picker.files({
          cwd = vim.fn.expand("~/amphora"),
          title = "Vault — Notas",
          args = {
            "--glob", "*.md",
            "--glob", "!Templates/**",
            "--glob", "!README.md",
            "--glob", "!CLAUDE.md",
          },
        })
      end,
      desc = "MOC — navegar vault",
    },
    {
      "<leader>vi",
      captura_rapida,
      desc = "Captura rápida → Inbox",
    },
    {
      "<leader>vg",
      function()
        Snacks.lazygit({ cwd = vim.fn.expand("~/amphora") })
      end,
      desc = "Lazygit — vault",
    },
    {
      "<leader>vP",
      function()
        Snacks.terminal.open("bash ~/code/site/sync.sh", {
          cwd = vim.fn.expand("~/code/site"),
          win = { style = "terminal" },
        })
      end,
      desc = "Publicar vault → site",
    },
    {
      "<leader>fz",
      function()
        local output = vim.fn.systemlist("zoxide query --list")
        local items = {}
        for _, path in ipairs(output) do
          if path ~= "" then
            table.insert(items, { text = path, file = path })
          end
        end
        Snacks.picker.pick({
          title = "Zoxide — Diretórios",
          items = items,
          format = "text",
          confirm = function(picker, item)
            picker:close()
            if item then vim.cmd("cd " .. vim.fn.fnameescape(item.file)) end
          end,
        })
      end,
      desc = "Zoxide — diretórios frequentes",
    },
  },
}

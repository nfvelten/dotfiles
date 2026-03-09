-- terere.lua — Tema Neovim claro baseado no tema Omarchy Tereré
-- Filosofia: Carbon-Boo-Selenized · Mate-Industrial · Manteiga de Papel

vim.cmd("highlight clear")
if vim.fn.exists("syntax_on") == 1 then
  vim.cmd("syntax reset")
end

vim.o.background = "light"
vim.g.colors_name = "terere"

local c = {
  bg      = "#fbf1c7",
  bg1     = "#ebdfb0",
  bg2     = "#ddd2a0",
  bg3     = "#928374",
  bg4     = "#7c6f64",
  fg      = "#3c3836",
  fg1     = "#1c1816",
  fg2     = "#504945",
  fg3     = "#665c54",
  red     = "#9d0006",
  red_b   = "#af1010",
  green   = "#79740e",
  green_b = "#8c8c08",
  yellow  = "#b57614",
  yellow_b= "#c88010",
  blue    = "#076678",
  blue_b  = "#0c7a8c",
  purple  = "#8f3f71",
  purple_b= "#9d4f7d",
  cyan    = "#427b58",
  cyan_b  = "#4f8f68",
  orange  = "#c88010",
  none    = "NONE",
}

local function hl(group, opts)
  vim.api.nvim_set_hl(0, group, opts)
end

-- ── Editor ────────────────────────────────────────────────────────────────────
hl("Normal",          { fg = c.fg,  bg = c.bg })
hl("NormalFloat",     { fg = c.fg,  bg = c.bg1 })
hl("NormalNC",        { fg = c.fg3, bg = c.bg })
hl("ColorColumn",     { bg = c.bg1 })
hl("Cursor",          { fg = c.bg,  bg = c.yellow })
hl("CursorIM",        { fg = c.bg,  bg = c.yellow })
hl("CursorLine",      { bg = c.bg1 })
hl("CursorColumn",    { bg = c.bg1 })
hl("CursorLineNr",    { fg = c.yellow, bold = true })
hl("LineNr",          { fg = c.bg3 })
hl("LineNrAbove",     { fg = c.bg3 })
hl("LineNrBelow",     { fg = c.bg3 })
hl("SignColumn",      { fg = c.fg3, bg = c.bg })
hl("FoldColumn",      { fg = c.fg3, bg = c.bg })
hl("Folded",          { fg = c.fg3, bg = c.bg2, italic = true })
hl("VertSplit",       { fg = c.bg3 })
hl("WinSeparator",    { fg = c.bg3 })

hl("Visual",          { bg = c.bg2 })
hl("VisualNOS",       { bg = c.bg1 })
hl("Search",          { fg = c.bg,  bg = c.yellow, bold = true })
hl("CurSearch",       { fg = c.bg,  bg = c.orange, bold = true })
hl("IncSearch",       { fg = c.bg,  bg = c.orange, bold = true })
hl("Substitute",      { fg = c.bg,  bg = c.red })
hl("MatchParen",      { fg = c.orange, bold = true, underline = true })

hl("StatusLine",      { fg = c.fg2, bg = c.bg2 })
hl("StatusLineNC",    { fg = c.fg3, bg = c.bg1 })
hl("TabLine",         { fg = c.fg3, bg = c.bg1 })
hl("TabLineFill",     { bg = c.bg })
hl("TabLineSel",      { fg = c.fg,  bg = c.bg2, bold = true })
hl("WinBar",          { fg = c.fg2, bg = c.bg })
hl("WinBarNC",        { fg = c.fg3, bg = c.bg })

hl("Pmenu",           { fg = c.fg,  bg = c.bg1 })
hl("PmenuSel",        { fg = c.fg1, bg = c.bg3, bold = true })
hl("PmenuSbar",       { bg = c.bg2 })
hl("PmenuThumb",      { bg = c.bg4 })
hl("PmenuKind",       { fg = c.cyan,   bg = c.bg1 })
hl("PmenuKindSel",    { fg = c.cyan_b, bg = c.bg3 })
hl("PmenuExtra",      { fg = c.fg3,    bg = c.bg1 })
hl("PmenuExtraSel",   { fg = c.fg2,    bg = c.bg3 })

hl("NonText",         { fg = c.bg3 })
hl("SpecialKey",      { fg = c.bg3 })
hl("Whitespace",      { fg = c.bg2 })
hl("EndOfBuffer",     { fg = c.bg2 })
hl("Conceal",         { fg = c.fg3 })

hl("DiffAdd",         { fg = c.green,  bg = c.bg1 })
hl("DiffChange",      { fg = c.yellow, bg = c.bg1 })
hl("DiffDelete",      { fg = c.red,    bg = c.bg1 })
hl("DiffText",        { fg = c.blue,   bg = c.bg2, bold = true })
hl("Added",           { fg = c.green })
hl("Changed",         { fg = c.yellow })
hl("Removed",         { fg = c.red })

hl("ErrorMsg",        { fg = c.red,    bold = true })
hl("WarningMsg",      { fg = c.yellow, bold = true })
hl("InfoMsg",         { fg = c.blue })
hl("ModeMsg",         { fg = c.fg,     bold = true })
hl("MoreMsg",         { fg = c.green,  bold = true })
hl("Question",        { fg = c.green,  bold = true })
hl("Title",           { fg = c.yellow, bold = true })
hl("Directory",       { fg = c.blue })

hl("QuickFixLine",    { bg = c.bg2 })
hl("Underlined",      { underline = true })
hl("Bold",            { bold = true })
hl("Italic",          { italic = true })

-- ── Diagnósticos ─────────────────────────────────────────────────────────────
hl("DiagnosticError",              { fg = c.red })
hl("DiagnosticWarn",               { fg = c.yellow })
hl("DiagnosticInfo",               { fg = c.blue })
hl("DiagnosticHint",               { fg = c.cyan })
hl("DiagnosticOk",                 { fg = c.green })
hl("DiagnosticUnderlineError",     { sp = c.red,    underline = true })
hl("DiagnosticUnderlineWarn",      { sp = c.yellow, underline = true })
hl("DiagnosticUnderlineInfo",      { sp = c.blue,   underline = true })
hl("DiagnosticUnderlineHint",      { sp = c.cyan,   underline = true })
hl("DiagnosticVirtualTextError",   { fg = c.red,    bg = c.bg1, italic = true })
hl("DiagnosticVirtualTextWarn",    { fg = c.yellow, bg = c.bg1, italic = true })
hl("DiagnosticVirtualTextInfo",    { fg = c.blue,   bg = c.bg1, italic = true })
hl("DiagnosticVirtualTextHint",    { fg = c.cyan,   bg = c.bg1, italic = true })
hl("DiagnosticSignError",          { fg = c.red })
hl("DiagnosticSignWarn",           { fg = c.yellow })
hl("DiagnosticSignInfo",           { fg = c.blue })
hl("DiagnosticSignHint",           { fg = c.cyan })

-- ── Sintaxe clássica ──────────────────────────────────────────────────────────
hl("Comment",    { fg = c.fg3, italic = true })
hl("String",     { fg = c.green })
hl("Number",     { fg = c.purple })
hl("Float",      { fg = c.purple })
hl("Boolean",    { fg = c.yellow, bold = true })
hl("Character",  { fg = c.green_b })
hl("Constant",   { fg = c.purple_b })

hl("Identifier", { fg = c.fg })
hl("Function",   { fg = c.blue })

hl("Statement",  { fg = c.red })
hl("Keyword",    { fg = c.red,  bold = true })
hl("Conditional",{ fg = c.red,  bold = true })
hl("Repeat",     { fg = c.red,  bold = true })
hl("Label",      { fg = c.red })
hl("Operator",   { fg = c.orange })
hl("Exception",  { fg = c.red,  bold = true })

hl("PreProc",    { fg = c.cyan })
hl("Include",    { fg = c.cyan })
hl("Define",     { fg = c.cyan })
hl("Macro",      { fg = c.cyan })
hl("PreCondit",  { fg = c.cyan })

hl("Type",         { fg = c.yellow })
hl("StorageClass", { fg = c.yellow, bold = true })
hl("Structure",    { fg = c.yellow })
hl("Typedef",      { fg = c.yellow })

hl("Special",        { fg = c.orange })
hl("SpecialChar",    { fg = c.orange })
hl("Tag",            { fg = c.cyan })
hl("Delimiter",      { fg = c.fg2 })
hl("SpecialComment", { fg = c.fg3, italic = true })
hl("Debug",          { fg = c.red_b })

hl("Error",   { fg = c.red,    bold = true })
hl("Warning", { fg = c.yellow })
hl("Todo",    { fg = c.bg,  bg = c.yellow, bold = true })
hl("Note",    { fg = c.bg,  bg = c.blue,   bold = true })

-- ── Treesitter ────────────────────────────────────────────────────────────────
-- Literals
hl("@string",                 { link = "String" })
hl("@string.escape",          { fg = c.green_b })
hl("@string.special",         { fg = c.green_b })
hl("@string.special.url",     { fg = c.blue, underline = true })
hl("@character",              { link = "Character" })
hl("@number",                 { link = "Number" })
hl("@number.float",           { link = "Float" })
hl("@boolean",                { link = "Boolean" })

-- Variáveis
hl("@variable",               { fg = c.fg })
hl("@variable.builtin",       { fg = c.red_b, italic = true })
hl("@variable.parameter",     { fg = c.fg2 })
hl("@variable.member",        { fg = c.fg2 })

-- Funções
hl("@function",               { link = "Function" })
hl("@function.builtin",       { fg = c.blue_b })
hl("@function.call",          { fg = c.blue })
hl("@function.macro",         { fg = c.cyan })
hl("@function.method",        { link = "Function" })
hl("@function.method.call",   { fg = c.blue })
hl("@constructor",            { fg = c.yellow })

-- Keywords
hl("@keyword",                { link = "Keyword" })
hl("@keyword.function",       { fg = c.red, bold = true })
hl("@keyword.return",         { fg = c.red, bold = true })
hl("@keyword.operator",       { fg = c.orange })
hl("@keyword.import",         { fg = c.cyan })
hl("@keyword.modifier",       { fg = c.yellow, bold = true })
hl("@keyword.type",           { fg = c.yellow })
hl("@keyword.coroutine",      { fg = c.purple_b, bold = true })
hl("@keyword.exception",      { fg = c.red, bold = true })
hl("@keyword.conditional",    { fg = c.red, bold = true })
hl("@keyword.repeat",         { fg = c.red, bold = true })

-- Tipos
hl("@type",                   { link = "Type" })
hl("@type.builtin",           { fg = c.yellow, italic = true })
hl("@type.qualifier",         { fg = c.yellow, bold = true })
hl("@type.definition",        { fg = c.yellow })

-- Módulos e namespaces
hl("@module",                 { fg = c.cyan })
hl("@namespace",              { fg = c.cyan })
hl("@label",                  { fg = c.red })

-- Propriedades e atributos
hl("@property",               { fg = c.fg2 })
hl("@field",                  { fg = c.fg2 })
hl("@attribute",              { fg = c.purple })
hl("@attribute.builtin",      { fg = c.purple_b })

-- Operadores e pontuação
hl("@operator",               { link = "Operator" })
hl("@punctuation.bracket",    { fg = c.fg3 })
hl("@punctuation.delimiter",  { fg = c.fg3 })
hl("@punctuation.special",    { fg = c.orange })

-- Comentários
hl("@comment",                { link = "Comment" })
hl("@comment.todo",           { fg = c.bg, bg = c.yellow, bold = true })
hl("@comment.note",           { fg = c.bg, bg = c.blue,   bold = true })
hl("@comment.warning",        { fg = c.bg, bg = c.orange, bold = true })
hl("@comment.error",          { fg = c.bg, bg = c.red,    bold = true })

-- Markup (markdown, etc.)
hl("@markup.heading",         { fg = c.yellow, bold = true })
hl("@markup.heading.1",       { fg = c.red,    bold = true })
hl("@markup.heading.2",       { fg = c.yellow, bold = true })
hl("@markup.heading.3",       { fg = c.green,  bold = true })
hl("@markup.heading.4",       { fg = c.blue,   bold = true })
hl("@markup.heading.5",       { fg = c.cyan,   bold = true })
hl("@markup.heading.6",       { fg = c.purple, bold = true })
hl("@markup.bold",            { bold = true })
hl("@markup.italic",          { italic = true })
hl("@markup.strikethrough",   { strikethrough = true })
hl("@markup.underline",       { underline = true })
hl("@markup.quote",           { fg = c.fg3, italic = true })
hl("@markup.link",            { fg = c.blue, underline = true })
hl("@markup.link.url",        { fg = c.blue_b, underline = true })
hl("@markup.link.label",      { fg = c.cyan })
hl("@markup.raw",             { fg = c.green, bg = c.bg1 })
hl("@markup.raw.block",       { fg = c.green, bg = c.bg1 })
hl("@markup.list",            { fg = c.orange })
hl("@markup.list.checked",    { fg = c.green })
hl("@markup.list.unchecked",  { fg = c.fg3 })

-- HTML/JSX/TSX tags
hl("@tag",                    { fg = c.red })
hl("@tag.attribute",          { fg = c.yellow })
hl("@tag.delimiter",          { fg = c.fg3 })

-- ── LSP ───────────────────────────────────────────────────────────────────────
hl("LspReferenceText",              { bg = c.bg2 })
hl("LspReferenceRead",              { bg = c.bg2 })
hl("LspReferenceWrite",             { bg = c.bg2, bold = true })
hl("LspSignatureActiveParameter",   { fg = c.orange, bold = true })
hl("LspCodeLens",                   { fg = c.fg3, italic = true })
hl("LspCodeLensSeparator",          { fg = c.bg3 })
hl("LspInlayHint",                  { fg = c.fg3, bg = c.bg1, italic = true })

-- ── Git Signs ─────────────────────────────────────────────────────────────────
hl("GitSignsAdd",           { fg = c.green })
hl("GitSignsChange",        { fg = c.yellow })
hl("GitSignsDelete",        { fg = c.red })
hl("GitSignsAddNr",         { fg = c.green })
hl("GitSignsChangeNr",      { fg = c.yellow })
hl("GitSignsDeleteNr",      { fg = c.red })
hl("GitSignsAddLn",         { bg = c.bg1 })
hl("GitSignsChangeLn",      { bg = c.bg1 })
hl("GitSignsDeleteLn",      { bg = c.bg1 })
hl("GitSignsCurrentLineBlame", { fg = c.bg3, italic = true })

-- ── Telescope ─────────────────────────────────────────────────────────────────
hl("TelescopeNormal",        { fg = c.fg,  bg = c.bg1 })
hl("TelescopeBorder",        { fg = c.bg3, bg = c.bg1 })
hl("TelescopePromptNormal",  { fg = c.fg,  bg = c.bg2 })
hl("TelescopePromptBorder",  { fg = c.bg3, bg = c.bg2 })
hl("TelescopePromptPrefix",  { fg = c.yellow })
hl("TelescopePromptTitle",   { fg = c.bg,  bg = c.yellow, bold = true })
hl("TelescopePreviewTitle",  { fg = c.bg,  bg = c.cyan })
hl("TelescopeResultsTitle",  { fg = c.bg,  bg = c.bg3 })
hl("TelescopeSelection",     { bg = c.bg2 })
hl("TelescopeSelectionCaret",{ fg = c.yellow })
hl("TelescopeMatching",      { fg = c.red, bold = true })
hl("TelescopeMultiSelection",{ fg = c.cyan })

-- ── Snacks / Noice / Mini ─────────────────────────────────────────────────────
hl("SnacksPickerBorder",        { fg = c.bg3, bg = c.bg1 })
hl("SnacksPickerBoxBorder",     { fg = c.bg3 })
hl("SnacksPickerTitle",         { fg = c.bg, bg = c.yellow, bold = true })
hl("SnacksPickerMatch",         { fg = c.red, bold = true })
hl("SnacksPickerListCursorLine",{ bg = c.bg2 })

hl("MiniIndentscopeSymbol",  { fg = c.bg3 })
hl("MiniIndentscopePrefix",  { link = "MiniIndentscopeSymbol" })

hl("IblIndent",              { fg = c.bg2 })
hl("IblScope",               { fg = c.bg3 })

-- ── nvim-cmp ──────────────────────────────────────────────────────────────────
hl("CmpItemAbbrDeprecated",  { fg = c.fg3, strikethrough = true })
hl("CmpItemAbbrMatch",       { fg = c.red, bold = true })
hl("CmpItemAbbrMatchFuzzy",  { fg = c.red })
hl("CmpItemKindVariable",    { fg = c.blue })
hl("CmpItemKindInterface",   { fg = c.cyan })
hl("CmpItemKindText",        { fg = c.fg3 })
hl("CmpItemKindFunction",    { fg = c.blue_b })
hl("CmpItemKindMethod",      { fg = c.blue_b })
hl("CmpItemKindKeyword",     { fg = c.red })
hl("CmpItemKindProperty",    { fg = c.yellow })
hl("CmpItemKindUnit",        { fg = c.purple })

-- ── Which-key ─────────────────────────────────────────────────────────────────
hl("WhichKey",               { fg = c.orange })
hl("WhichKeyGroup",          { fg = c.blue })
hl("WhichKeyDesc",           { fg = c.fg })
hl("WhichKeySeparator",      { fg = c.fg3 })
hl("WhichKeyFloat",          { bg = c.bg1 })
hl("WhichKeyBorder",         { fg = c.bg3, bg = c.bg1 })

-- ── Lazy.nvim ─────────────────────────────────────────────────────────────────
hl("LazyH1",                 { fg = c.bg, bg = c.yellow, bold = true })
hl("LazyButton",             { fg = c.fg3, bg = c.bg2 })
hl("LazyButtonActive",       { fg = c.bg, bg = c.yellow, bold = true })
hl("LazySpecial",            { fg = c.cyan })

-- ── Alpha / Dashboard ─────────────────────────────────────────────────────────
hl("AlphaHeader",            { fg = c.yellow })
hl("AlphaButtons",           { fg = c.blue })
hl("AlphaShortcut",          { fg = c.orange })
hl("AlphaFooter",            { fg = c.fg3, italic = true })

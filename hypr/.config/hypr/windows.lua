-- Regras dos scratchpads (terminal flutuante num workspace especial).
-- A sintaxe antiga `hyprctl dispatch exec "[regras] cmd"` foi removida no
-- Hyprland novo (Lua config) — agora a regra tem que ser persistente aqui,
-- casando pelo --title que cada script scratch* passa pro ghostty.

local function scratch_rule(title, workspace, size)
  o.window({ title = "^(" .. title .. ")$" }, {
    float = true,
    size = size,
    workspace = "special:" .. workspace .. " silent",
    center = true,
  })
end

scratch_rule("__scratchterm", "scratchterm", "1000 580")
scratch_rule("__scratchnvim", "nvim", "1100 650")
scratch_rule("__scratchherdr", "herdr", "1100 650")
scratch_rule("__scratchwork", "work-nvim", "1100 650")
scratch_rule("__scratchikhal", "ikhal", "1100 650")
scratch_rule("__scratchspotify", "spotify", "1100 650")
scratch_rule("__scratchkeys", "keys", "1100 650")

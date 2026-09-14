return {
  "mikavilpas/yazi.nvim",
  event = "VeryLazy",
  dependencies = { "folke/snacks.nvim" },
  keys = {
    {
      "<leader>e",
      function() require("yazi").yazi() end,
      desc = "Abrir yazi (diretório atual)",
    },
  },
  opts = {
    open_for_directories = true,
    floating_window_scaling_factor = 0.9,
  },
}

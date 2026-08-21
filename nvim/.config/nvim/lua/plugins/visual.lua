return {
  {
    "sudormrfbin/cheatsheet.nvim",
    dependencies = { "nvim-telescope/telescope.nvim", "nvim-lua/plenary.nvim" },
    cmd = "Cheatsheet",
  },
  {
    "kylechui/nvim-surround",
    event = "VeryLazy",
    opts = {},
  },
  {
    "lukas-reineke/indent-blankline.nvim",
    main = "ibl",
    event = "BufReadPost",
    opts = {},
  },
  {
    "RRethy/vim-illuminate",
    event = "BufReadPost",
    opts = { delay = 100 },
    config = function(_, opts)
      require("illuminate").configure(opts)
    end,
  },
  {
    "norcalli/nvim-colorizer.lua",
    event = "BufReadPost",
    config = function()
      require("colorizer").setup()
    end,
  },
}

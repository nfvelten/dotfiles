return {
  "stevearc/conform.nvim",
  opts = {
    formatters_by_ft = {
      markdown = { "markdownlint-cli2" },
    },
    format_on_save = {
      timeout_ms = 3000,
      lsp_format = "fallback",
    },
  },
}

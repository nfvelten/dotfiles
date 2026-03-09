-- markdownlint-cli2 e markdown-toc já estão instalados globalmente via npm/mise
-- remove da fila do mason para evitar erro de instalação duplicada
return {
  {
    "mason-org/mason.nvim",
    opts = function(_, opts)
      opts.ensure_installed = vim.tbl_filter(function(tool)
        return tool ~= "markdownlint-cli2" and tool ~= "markdown-toc"
      end, opts.ensure_installed or {})
    end,
  },
  {
    "mfussenegger/nvim-lint",
    opts = function(_, opts)
      opts.linters = opts.linters or {}
      opts.linters["markdownlint-cli2"] = {
        args = { "--config", vim.fn.expand("~/amphora/.markdownlint.jsonc"), "$FILENAME" },
      }
    end,
  },
}

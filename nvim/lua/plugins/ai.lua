return {
  { import = "lazyvim.plugins.extras.ai.sidekick" },
  {
    "folke/sidekick.nvim",
    opts = {
      nes = { enabled = false },
      cli = {
        mux = {
          enabled = true,
          backend = "tmux",
        },
      },
    },
  },
}

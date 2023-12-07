return {
  {
    "kylechui/nvim-surround",
    opts = {
      keymaps = {
        normal = "<leader>sa",
        normal_cur = false,
        normal_line = false,
        normal_cur_line = false,
        visual = "<leader>s",
        visual_line = "<leader>S",
        delete = "<leader>sd",
        change = "<leader>sr",
      },
      aliases = {
        ["i"] = "]", -- Index
        ["r"] = ")", -- Round
        ["b"] = "}", -- Brackets
      },
      move_cursor = false,
    },
  },

  -- Configure LazyVim to load gruvbox
  -- {
  --   "LazyVim/LazyVim",
  --   opts = {
  --     colorscheme = "onedark",
  --   },
  -- },
}

# Roadmap

## Feature backlog and future actions

Features:

- **F1.** Some helpers for some header handling, like toggling recipients
  between `To`: and `Cc:` or adding and deleting them, or changing subject
  without moving cursor there.

Engineering:

- **E1.** Evaluating treesitter for mail, which together with
  [nvim-treesitter-textobjects](https://github.com/nvim-treesitter/nvim-treesitter-textobjects)
  makes the implementation of F1 simpler.

## Version 1.0 (in plan)

Open TODO:
- Improve code quality
- Memoize completion items instead of contacts

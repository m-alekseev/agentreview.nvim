# agentreview.nvim

Review a coding agent's git changes in nvim, comment on blocks of the diff, and send all comments back to the agent session that made them.

![demo](demo/demo.gif)

Requires nvim >= 0.10 (`vim.system`, `getregion()`).

## Install

### lazy.nvim / LazyVim

Add a plugin spec, in LazyVim as `lua/plugins/agentreview.lua` with a leading `return`:

```lua
{
  "m-alekseev/agentreview.nvim",
  cmd = { "AgentReview", "AgentReviewCommit", "AgentReviewComment", "AgentReviewSend", "AgentReviewTarget" },
  opts = {},
}
```

`cmd` loads the plugin the first time you run one of its commands. Optional keys:

```lua
keys = {
  { "<leader>rr", "<cmd>AgentReview<cr>", desc = "Agent review" },
  { "<leader>rh", "<cmd>AgentReviewCommit<cr>", desc = "Agent review commit" },
  { "<leader>rt", "<cmd>AgentReviewTarget<cr>", desc = "Agent review target" },
  { "<leader>rs", "<cmd>AgentReviewSend<cr>", desc = "Agent review send" },
},
```

### vim.pack (nvim 0.12+)

```lua
vim.pack.add({ "https://github.com/m-alekseev/agentreview.nvim" })
require("agentreview").setup({})
```

## How I use it

I have a function in my `.zshrc`:

```sh
nr() { nvim -c "AgentReview $1"; }
```

After the agent finishes, I `cd` into the repo, type `nr`, comment on the diff and send the comments back to it. `nr` shows what isn't committed yet. `nr <rev>` shows everything after `<rev>`, e.g. `nr HEAD~3` for the last 3 commits or `nr origin/master` for unpushed ones. Use `:AgentReviewCommit <rev>` to review a single commit instead.

## Config

```lua
require("agentreview").setup({
  transport = "herdr",
  send_mode = "submit",
  prompt_template = "Review comments are in {path}",
  clear_on_send = true,
})
```

- `transport`: `"herdr"`, `"clipboard"`, or a transport table (see below).
- `send_mode` (herdr only): `"submit"` uses `herdr agent prompt`; `"paste"` uses `herdr pane send-text` (no Enter).
- `prompt_template`: one-line prompt sent to the agent; `{path}` is the review file.
- `clear_on_send`: drop comments after a successful send.

## Commands

| Command | Action |
| --- | --- |
| `:AgentReview [base]` | Open the diff: without `base`, everything not committed yet (working tree vs `HEAD`, plus untracked files); with `base`, everything after `base` (commits made since, staged and unstaged edits; untracked files are not included) |
| `:AgentReviewCommit [rev]` | Open only the changes of one commit (like `git show`); without `rev`, pick from the last 50 commits. Merge commits diff against the first parent |
| `:'<,'>AgentReviewComment` | Comment on the selected lines |
| `:AgentReviewSend` | Write `<git-dir>/agent-review.md` and send the prompt via the transport |
| `:AgentReviewTarget` | Re-open the target picker |

## Keymaps (review buffer)

| Key | Action |
| --- | --- |
| `]h` / `[h` | next / previous hunk |
| `]f` / `[f` | next / previous file |
| `c` (visual) | comment on the selection (`V` linewise, `v` characterwise) |
| `c` (on a comment) | edit comment |
| `dc` | delete comment |
| `]r` / `[r` | next / previous comment |
| `gl` | list comments in quickfix |

In the comment input: `<CR>` saves, `<Esc>` cancels, `<S-CR>` inserts a newline.

A selection must stay inside one file.

Comment line numbers are side-aware: new-file numbers for added and context lines, old-file numbers for removed lines.

## Targets

The target is chosen per nvim session and repo. A transport can mark candidates as `preferred`; the first preferred candidate (or the only candidate) is used without asking. Otherwise `vim.ui.select` opens. `:AgentReviewTarget` always opens the picker, and the choice is kept in memory. If the saved target is gone, the default is chosen again.

The herdr transport lists all agents, those whose `cwd` or `foreground_cwd` is inside the repo root first. Labels read `<cwd> · <name or session title> [status] <pane id>`.

## Highlight groups

All link to built-in groups by default and can be overridden.

| Group | Default link | Used for |
| --- | --- | --- |
| `AgentReviewAdd` | `Added` | gutter bar on added lines |
| `AgentReviewDel` | `Removed` | gutter bar on removed lines |
| `AgentReviewAddWord` | `DiffAdd` | changed words on the added line of a changed pair |
| `AgentReviewDelWord` | `DiffDelete` | changed words on the removed line of a changed pair |
| `AgentReviewComment` | `DiagnosticInfo` | comment text above a block |
| `AgentReviewRange` | `Visual` | commented range |

## Transport interface

```lua
{
  name = "mine",
  list_targets = function(ctx) end, -- ctx = { repo_root }; returns { { id, label, status } }, status: idle|working|blocked|unknown
  resolve = function(id) end,       -- target table, or nil if gone
  send = function(target, text) end, -- returns ok, err; err.code == "blocked" keeps comments
}
```

## Verified facts (nvim 0.12.6, herdr 0.9.5)

- herdr prints a JSON envelope: `{"id", "result"}` on success, `{"error": {"code", "message"}, "id"}` with exit 1 on failure.
- `agent list` → `result.agents`, `agent get` → `result.agent`; fields used: `pane_id`, `terminal_id`, `agent`, `display_agent`, `name`, `terminal_title_stripped`, `agent_status` (`idle|working|blocked|done|unknown`), `cwd`, `foreground_cwd`.
- `herdr agent prompt --help` documents `agent_blocked` for a blocked agent. The error JSON for it and a successful `agent prompt` were not exercised (unverified).
- Whether `terminal_id` survives moving a pane across workspaces is unverified; the herdr transport re-resolves by `terminal_id` when the pane id is stale.

## Tests

```sh
nvim --headless -u tests/minimal_init.lua -c "PlenaryBustedDirectory tests/ {minimal_init='tests/minimal_init.lua'}"
```

Requires plenary.nvim at `~/.local/share/nvim/lazy/plenary.nvim`.

## Regenerate the demo

```sh
vhs demo/demo.tape
```

Requires [vhs](https://github.com/charmbracelet/vhs). `demo/setup.sh` builds a scratch repo in `/tmp/agentreview-demo`, and `demo/init.lua` is a minimal config using the clipboard transport. Set `DEMO_EXTRA=/path/to/file.lua` to load a colorscheme setup file into the demo.

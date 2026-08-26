# hf-codex

extension for `hf` to launch [Codex CLI](https://github.com/openai/codex) with [Hugging Face Inference Providers](https://huggingface.co/docs/inference-providers/en/index)

It lets you pick:
- model (from `https://router.huggingface.co/v1/models`)
- provider (`auto` or a concrete provider for the selected model)

Then it runs `codex` with a wrapper-managed config pointing at the HF router.

## Requirements

- Codex CLI installed (`codex`)
- `curl`, `jq`, `bash`
- [`fzf`](https://github.com/junegunn/fzf#installation) *(optional)* — enables fuzzy model/provider search; without it the launcher falls back to an arrow-key menu (↑/↓ to move, Enter to select)
- A Hugging Face token, via either:

```bash
curl -LsSf https://hf.co/cli/install.sh | bash
hf auth login
# or
export HF_TOKEN='hf_...'
```

## Install

```bash
hf extensions install tengomucho/hf-codex
# add --force to reinstall the extension
```

## Run

```bash
hf codex
# or
hf extensions exec codex
```

Forward extra args to Codex:

```bash
hf codex --help
hf codex exec "fix the failing test"
```

## Billing to an organization

To bill inference usage to a Hugging Face organization instead of your personal
account, pass `--bill-to` (you must have Write privileges in the org):

```bash
hf codex --bill-to your-org-name
```

This sets the router's `X-HF-Bill-To` header on every request. You can also set
it via the `HF_BILL_TO` environment variable:

```bash
export HF_BILL_TO=your-org-name
hf codex
```

## How it works

The wrapper writes a Codex `config.toml` into an isolated `CODEX_HOME`
(`$HF_HOME/hf-codex`, default `~/.cache/huggingface/hf-codex`) defining a
`model_providers.hf` provider with `base_url = https://router.huggingface.co/v1`,
`wire_api = "responses"`, and `env_key = "HF_TOKEN"`. Your own
`~/.codex/config.toml` is never modified. The last selected model is cached in
`last-model.json` and offered for reuse on the next launch.

## Caveats

- The HF router's [Responses API](https://huggingface.co/docs/inference-providers/en/guides/responses-api)
  is in beta. Codex only speaks `wire_api = "responses"`, so models/providers
  whose upstream doesn't accept Codex's Responses payload will fail — e.g.
  `moonshotai/Kimi-K2-Instruct-0905:novita` currently returns
  `400 status code (no body)` from the upstream provider. If a model errors,
  pick a different provider (or `auto`) for it.
- The isolated `CODEX_HOME` means your personal Codex MCP servers, agents, and
  plugins are intentionally not loaded: the router rejects requests carrying
  `namespace`/`mcp` tool types, `web_search`, and zstd-compressed bodies, so
  the wrapper disables them.
- `HF_CODEX_DRY_RUN=1` prints the would-be `codex` command instead of exec'ing
  (used by the tests).

## Development

```bash
bash tests/run.sh   # zero-dependency test suite
```

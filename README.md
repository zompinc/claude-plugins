# Zomp Claude Code plugins

A [Claude Code](https://claude.com/claude-code) plugin marketplace for general-purpose plugins. Plugins tied to a product live with that product; for example, the Zomp.SyncMethodGenerator skill ships from [zompinc/sync-method-generator](https://github.com/zompinc/sync-method-generator).

## Install

```sh
claude plugin marketplace add zompinc/claude-plugins
claude plugin install <plugin>@zomp-tools
```

## Plugins

| Plugin                                 | What it does                                                                                                   |
| -------------------------------------- | -------------------------------------------------------------------------------------------------------------- |
| [wt-tab-status](plugins/wt-tab-status) | Progress ring on a Windows Terminal tab while Claude works, bell icon when it finishes while you are elsewhere |

## Development

```sh
pnpm install
```

`pnpm install` sets up the pre-commit hook, which checks formatting with Prettier and that every file ends with a newline.

To try a plugin without installing it, load it for one session:

```sh
claude --plugin-dir plugins/<plugin>
```

`claude plugin validate .` checks the marketplace manifest, and `claude plugin validate plugins/<plugin>/plugin.json` a plugin's.

To publish a change, bump `version` in both the plugin's `plugin.json` and its entry in `.claude-plugin/marketplace.json`; installed copies update when the version changes.

# z2h (Zero to Hero)

Custom agent skills, rule files, and instruction files, packaged so the repo can be used directly with `npx skills add ...`.

## Repo Layout

```text
z2h/
├── skills/                       # installable skills
├── rules/                        # optional shared rule files
├── instructions/                 # optional .instructions.md files
├── plugins/
│   └── z2h-custom/  # plugin metadata for marketplace-style installs
├── .agents/plugins/marketplace.json
├── scripts/
│   ├── build-catalog.py
│   ├── export-plugin.py
│   ├── generate-vscode-settings.sh
│   └── install-skill.sh
└── catalog.json
```

## Install

Install all bundled skills from GitHub:

```bash
npx skills add yiliu30/z2h
```

List what the repo exposes:

```bash
npx skills add yiliu30/z2h --list
```

Install from a local checkout:

```bash
npx skills add .
```

## Bundled Skills

| Skill | What It Does |
|------|------|
| `example-skill` | Template skill you can copy when creating a new skill. |
| `find-sth` | Investigates technical questions across code, docs, papers, and other sources, then writes a sourced findings document. |
| `observe` | Records structured observations from another Claude Code session and bails early when there is nothing meaningful to record. |
| `profile-cute-xpu` | Profiles CuTe/SYCL*TLA kernels on Intel XPU with unitrace/VTune workflows and maps bottlenecks to Xe tuning knobs. |
| `real-review` | Fact-checks written content against primary evidence before publishing. |
| `reduce-model` | Creates a reduced HuggingFace model for faster testing and debugging workflows. |
| `intel-xpu-cute-accuracy-debug` | Debugs numerical mismatches in Intel XPU CuTe/CUTLASS kernels, including Xe DPAS/BDPAS layouts and fused accumulators. |

## Local Commands

```bash
make help
make list
make catalog
make plugin
make refresh
```

| Command | Description |
|---------|-------------|
| `make list` | List bundled skills |
| `make install SKILL=<name> TARGET=<dir>` | Copy one skill into a target directory |
| `make catalog` | Rebuild `catalog.json` from `skills/` |
| `make plugin` | Rebuild plugin marketplace metadata |
| `make refresh` | Rebuild both catalog and plugin metadata |
| `make settings` | Generate VS Code settings snippets |

## VS Code

Generate a settings snippet:

```bash
make settings
```

Expected paths:

```jsonc
"chat.agentSkillsLocations": {
  "~/workspace/z2h/skills": true
},
"chat.instructionsFilesLocations": {
  "~/workspace/z2h/instructions": true
}
```

## Adding A Skill

1. Copy the template:

```bash
cp -r skills/example-skill skills/my-new-skill
```

2. Edit `skills/my-new-skill/SKILL.md`.
3. Run `make refresh`.

## Catalog

`catalog.json` is generated from `skills/` and records:

- skill name
- description
- repo-relative path
- whether the skill includes extra assets

## License

The repo is licensed under [MIT](LICENSE).

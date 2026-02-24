# 🧠 Agent Skills Hub

A curated collection of agent skills from popular open-source repositories plus custom skills — all in one place.

## What are Agent Skills?

Skills are folders of instructions, scripts, and resources that AI coding agents load dynamically to improve performance on specialized tasks. Each skill contains a `SKILL.md` file following the [Agent Skills specification](http://agentskills.io).

## Repository Structure

```
agent-skills-hub/
├── Makefile                      # common commands (make help)
├── third-party/                  # git submodules (upstream repos)
│   ├── anthropic-skills/         # github.com/anthropics/skills
│   └── awesome-copilot/          # github.com/github/awesome-copilot
├── custom/                       # your own skills
│   └── example-skill/
├── scripts/
│   ├── build-catalog.py          # generates catalog.json
│   ├── install-skill.sh          # installs a skill locally
│   └── generate-vscode-settings.sh  # generates VS Code settings snippet
├── catalog.json                  # auto-generated unified skill index
└── .github/workflows/            # CI to rebuild catalog
```

## Third-Party Skill Sources

| Source | Skills | Focus |
|--------|--------|-------|
| [anthropics/skills](https://github.com/anthropics/skills) | 16 | Creative, docs, design, enterprise |
| [github/awesome-copilot](https://github.com/github/awesome-copilot) | 52+ | Dev tools, Azure, Microsoft, CI/CD |

## Quick Start

### Clone with submodules

```bash
git clone --recurse-submodules https://github.com/<your-user>/agent-skills-hub.git
cd agent-skills-hub
```

If you already cloned without `--recurse-submodules`:

```bash
git submodule update --init --recursive
```

### Available commands

All common operations are available via `make`:

```bash
make help       # show all commands
```

| Command | Description |
|---------|-------------|
| `make update` | Pull latest from third-party submodules |
| `make settings` | Generate VS Code `chat.agentSkillsLocations` snippet |
| `make catalog` | Rebuild `catalog.json` from all skill sources |
| `make refresh` | Update submodules + rebuild catalog in one step |
| `make list` | List all available skills |
| `make install SKILL=<name> TARGET=<dir>` | Install a skill to a target directory |

### Configure VS Code

Generate the `chat.agentSkillsLocations` setting so VS Code discovers all skills automatically:

```bash
make settings
```

Then copy the output into your VS Code `settings.json` (user or workspace):

```jsonc
"chat.agentSkillsLocations": [
    "~/workspace/agent-skills-hub/custom",
    "~/workspace/agent-skills-hub/third-party/anthropic-skills/skills",
    "~/workspace/agent-skills-hub/third-party/awesome-copilot/skills"
]
```

### Update third-party skills

```bash
make update    # pull latest from upstream
make catalog   # rebuild the catalog
# or both at once:
make refresh
```

### Browse & install skills

```bash
# List all available skills
make list

# Install a specific skill to a target directory
make install SKILL=git-commit TARGET=~/.config/skills/
```

## Adding Custom Skills

1. Create a new folder under `custom/`:
   ```bash
   cp -r custom/example-skill custom/my-new-skill
   ```
2. Edit `custom/my-new-skill/SKILL.md` with your skill content
3. Rebuild the catalog:
   ```bash
   make catalog
   ```
4. Commit and push

See the [skill template](custom/example-skill/SKILL.md) for the expected format.

## Adding More Third-Party Sources

```bash
git submodule add https://github.com/<owner>/<repo>.git third-party/<name>
make catalog
git add . && git commit -m "feat: add <name> as third-party skill source"
```

## Catalog Schema

`catalog.json` is auto-generated and contains:

```json
{
  "version": "1.0",
  "generated_at": "2026-02-24T00:00:00Z",
  "total_skills": 74,
  "sources": { "custom": 1, "third-party": 73 },
  "skills": [
    {
      "name": "git-commit",
      "description": "Execute git commit with conventional commits...",
      "source": "awesome-copilot",
      "source_type": "third-party",
      "path": "third-party/awesome-copilot/skills/git-commit",
      "has_assets": false
    }
  ]
}
```

## License

Custom skills in this repo are licensed under [MIT](LICENSE). Third-party skills retain their original licenses — see each submodule for details.

# 🧠 Agent Skills Hub

A curated collection of agent skills from popular open-source repositories plus custom skills — all in one place.

## What are Agent Skills?

Skills are folders of instructions, scripts, and resources that AI coding agents load dynamically to improve performance on specialized tasks. Each skill contains a `SKILL.md` file following the [Agent Skills specification](http://agentskills.io).

## Repository Structure

```
agent-skills-hub/
├── third-party/                  # git submodules (upstream repos)
│   ├── anthropic-skills/         # github.com/anthropics/skills
│   └── awesome-copilot/          # github.com/github/awesome-copilot
├── custom/                       # your own skills
│   └── example-skill/
├── scripts/
│   ├── build-catalog.py          # generates catalog.json
│   └── install-skill.sh          # installs a skill locally
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

### Update third-party skills to latest

```bash
git submodule update --remote --merge
```

### Browse all skills

```bash
python scripts/build-catalog.py
cat catalog.json | python -m json.tool
```

### Install a skill

```bash
# List all available skills
./scripts/install-skill.sh --list

# Install a specific skill to a target directory
./scripts/install-skill.sh git-commit ~/.config/skills/
```

## Adding Custom Skills

1. Create a new folder under `custom/`:
   ```bash
   cp -r custom/example-skill custom/my-new-skill
   ```
2. Edit `custom/my-new-skill/SKILL.md` with your skill content
3. Run `python scripts/build-catalog.py` to update the catalog
4. Commit and push

See the [skill template](custom/example-skill/SKILL.md) for the expected format.

## Adding More Third-Party Sources

```bash
git submodule add https://github.com/<owner>/<repo>.git third-party/<name>
python scripts/build-catalog.py
git add . && git commit -m "feat: add <name> as third-party skill source"
```

## Catalog Schema

`catalog.json` is auto-generated and contains:

```json
{
  "version": "1.0",
  "generated_at": "2026-02-24T00:00:00Z",
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

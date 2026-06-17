# Skills

AI skills for development.

## Installing

> **Note:** The installers below are for Claude Code only. If you use a different agentic tool (e.g. GitHub Copilot), you will need to write an equivalent installer for that tool.

To install all skills in one go, run from the repo root:

```bash
./skills/claude-install.sh
```

This runs each skill's own installer in turn, copying the skill files into `~/.claude/skills/` where Claude Code picks them up automatically.

To install a specific skill only, run its installer directly from the repo root:

```bash
./skills/<skill-name>/claude-install.sh
```

## Available skills

| Skill | Description |
|-------|-------------|
| [Dependency management](./dependency-management/README.md) | AI skill and manual script for sweeping dependencies on a single Node.js repo |
| [Multi-repo dependency management](./multi-repo-dependency-management/README.md) | Orchestrates dependency sweeps across multiple Node.js repos in one session |

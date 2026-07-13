# Defra Forms Development Tools

Shared development tools and infrastructure for the Defra Forms application suite.

## What's in this repo

| Tool | Description |
|------|-------------|
| [Test harness](./test-harness/README.md) | Spins up the full stack — all forms microservices plus their runtime dependencies — via a single script. Use this if you want everything running without starting services individually. |
| [Runtime dependencies](./local-development-dependencies/README.md) | Spins up only the backing infrastructure (MongoDB, Redis, S3, CDP uploader) via Docker Compose. Use this if you're running the microservices yourself and only need the dependencies they rely on. |
| [Skills](./skills/README.md) | AI skills for development |
| [Microsite](./docusaurus.config.cjs) | "Forms development" documentation site (Docusaurus + LikeC4 architecture diagrams), deployed to GitHub Pages on push to `main`. Run locally with `npm install && npm run docs:dev`. |

## Microsite deployment

The microsite deploys automatically to GitHub Pages on push to `main`
(`.github/workflows/deploy-docs.yml`), served at
`https://defra.github.io/forms-development-tools/`.

**One-time setup:** in the repository settings, set **Pages → Build and deployment → Source** to **GitHub Actions**.

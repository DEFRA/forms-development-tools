# Defra Forms Development Tools

Shared development tools and infrastructure for the Defra Forms application suite.

## What's in this repo

| Tool | Description |
|------|-------------|
| [Test harness](./test-harness/README.md) | Spins up the full stack — all forms microservices plus their runtime dependencies — via a single script. Use this if you want everything running without starting services individually. |
| [Runtime dependencies](./local-development-dependencies/README.md) | Spins up only the backing infrastructure (MongoDB, Redis, S3, CDP uploader) via Docker Compose. Use this if you're running the microservices yourself and only need the dependencies they rely on. |
| [Skills](./skills/README.md) | AI skills for development |

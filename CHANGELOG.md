# Changelog

All notable changes to auto-logger will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2025-01-23

### Added
- Initial release of auto-logger
- Support for 100+ CLI tools including npm, docker, terraform, kubectl, vite, wrangler, prisma, and more
- Manual logging mode (all commands to single log file)
- Auto-detection mode (smart per-command log files)
- Smart output formatting with 5 modes:
  - `default` - Raw output
  - `compact` - One-line summaries (perfect for wrangler tail)
  - `json` - Pretty-print JSON with colors
  - `silent` - No terminal output, only save to file
  - `timestamps` - Add timestamps to each line
- `log-copy` command to copy log paths to clipboard (macOS, Linux, Windows)
- `log-help` command with comprehensive help and examples
- Smart directory detection (./logs or ~/logs)
- Cross-platform support (macOS, Linux, Windows WSL/Git Bash)
- Hybrid logging (formatted terminal output + raw log files)
- Commands: log-enable, log-disable, log-status, log-fmt, log-list, log-view, log-clear, log-copy, log-help

### Supported Tool Categories
- Package Managers: npm, pnpm, yarn, bun, npx, pip, poetry, pipenv, composer, mvn, gradle, gem, mix, dotnet
- Build Tools: vite, webpack, esbuild, rollup, parcel, turbo, swc, tsc, tsup
- Testing Frameworks: jest, vitest, playwright, cypress, pytest, mocha, phpunit, rspec
- Cloud & Serverless: wrangler, vercel, netlify, railway, fly, render, aws, gcloud, az, pulumi, serverless, sst, amplify
- Containers: docker, docker-compose, podman, kubectl, helm, minikube, k9s, skaffold
- Databases & ORMs: psql, mysql, mongosh, redis-cli, sqlite3, prisma, supabase, drizzle-kit, sequelize, typeorm
- Linters & Formatters: eslint, prettier, biome, black, ruff, rustfmt, gofmt, rubocop
- Framework CLIs: next, nuxt, astro, remix, expo, ng, vue, rails, symfony, nx
- Infrastructure: terraform, ansible-playbook, vagrant
- Programming Languages: python, node, deno, go, cargo, flutter, ruby, php
- Other Dev Tools: make, cmake, gh, nodemon, ts-node, storybook, tailwindcss, sass, protoc, curl, wget

[1.0.0]: https://github.com/naor64/Auto-Logger/releases/tag/v1.0.0

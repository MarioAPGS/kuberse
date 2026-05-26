# Kuberse Documentation

Welcome to the Kuberse platform documentation. This is the central reference for deploying, operating, and extending the platform.

## Getting Started

- [Quick Start](getting-started/quickstart.md) — Fork to running platform in 15 minutes
- [Architecture](architecture.md) — How the platform is designed

## Core Concepts

- [GitOps Flow](concepts/gitops-flow.md) — How `bootstrap.yaml` drives the entire platform
- [Placeholder System](concepts/placeholders.md) — Template variables and customization

## Platform Components

- [Components Overview](platform/overview.md) — Every component with sync waves and responsibilities

## Plugin System

- [Plugin Overview](plugins/overview.md) — Install, manage, and author plugins

> Plugin-specific documentation is bundled with each plugin and installed to `plugins/<name>/docs/` when you run `kuberse plugin install`.

## CLI

- [CLI Reference](cli/reference.md) — All commands and flags
- [Troubleshooting](cli/troubleshooting.md) — Common issues and solutions

## For Contributors

- [Plugin Authoring](../plugins/docs/plugins.md) — Comprehensive guide to creating plugins
- [Kubrain Apps](../plugins/docs/apps.md) — Building remote UI components

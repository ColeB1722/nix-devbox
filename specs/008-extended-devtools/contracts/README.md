# Contracts: Extended Development Tools

**Feature**: 008-extended-devtools

## Overview

This directory would normally contain API contracts (OpenAPI specs, GraphQL schemas, etc.) for the feature.

## Status: Not Applicable

Feature 008 is a **Nix configuration feature** that adds development tools via:

- Home Manager module extensions (packages only)
- NixOS module definitions (services with options)

There are no external APIs, REST endpoints, or GraphQL schemas to document.

## Module Interfaces

Module option interfaces are documented in [data-model.md](../data-model.md), which serves as the "contract" for this configuration-only feature.

## What Would Go Here

For features with APIs, this directory would contain:

- `openapi.yaml` - REST API specification
- `schema.graphql` - GraphQL schema
- `grpc/*.proto` - Protocol buffer definitions
- `events.json` - Event schema definitions
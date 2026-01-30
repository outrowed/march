# AGENTS.md

## Libraries
- Use `tomli` for reading TOML files.
- Use `tomli-w` for writing TOML files.
- Use `pydantic` for complex data modeling and serialization.

## Type checking and linting
- `basedpyright` is used for type checking.
    - Run via `uvx basedpyright <path>` if not available in the environment.
- Use `typing.Any` and `typing.cast` where necessary to satisfy strict type checking (e.g., in recursive serialization helpers).

## Tooling
- `uv` is preferred for dependency management and running tools (`uv run`, `uvx`).

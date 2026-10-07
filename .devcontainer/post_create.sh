#!/bin/bash

# Development container setup script for isa_container project
set -e

echo "🚀 Setting up isa_container development environment..."


# Resolve workspace root relative to this script
WORKSPACE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$WORKSPACE_DIR"


# Ensure uv is in PATH
export PATH="$HOME/.cargo/bin:$PATH"

# Install project dependencies
echo "📦 Installing Python dependencies..."
cd "$WORKSPACE_DIR"

# Check if uv is available, if not install it
if ! command -v uv &> /dev/null; then
    echo "🐍 Installing uv (Python package manager)..."
    curl -LsSf https://astral.sh/uv/install.sh | sh
    export PATH="$HOME/.cargo/bin:$PATH"
fi

export UV_LINK_MODE=copy
# Sync dependencies
uv sync

# Create necessary directories
echo "📁 Creating necessary directories..."
mkdir -p .vscode

# Set proper permissions
echo "🔒 Setting permissions..."
chmod +x "$WORKSPACE_DIR/.devcontainer/post_create.sh"

for script_path in \
    "$WORKSPACE_DIR/bin/env" \
    "$WORKSPACE_DIR/bin/help" \
    "$WORKSPACE_DIR/bin/test" \
    "$WORKSPACE_DIR/bin/lint/all" \
    "$WORKSPACE_DIR/bin/lint/py" \
    "$WORKSPACE_DIR/bin/lint/md"
do
    if [ -f "$script_path" ]; then
        chmod +x "$script_path"
    else
        echo "⚠️ Skipping missing script: $script_path"
    fi
done

# Create a sample .env file if it doesn't exist
if [ ! -f "$WORKSPACE_DIR/.env" ]; then
    echo "🔐 Creating .env file from template..."
    cp "$WORKSPACE_DIR/.env.template" "$WORKSPACE_DIR/.env"
fi

echo "✅ Developer environment setup complete!"
echo ""
echo "🎯 Next steps:"
echo "1. Configure your .env file with actual credentials"
echo "2. Run 'uv run python -m src.main --help' to see available commands"
echo "3. Start coding! 🚀"
echo ""

echo "📝 Available commands:"
echo "  - bin/help                    # Shows help options"
echo "  - bin/env                     # Exports variables from an environment file"

echo "  - bin/lint/all                # Run all linting"
echo "  - bin/lint/md                 # Lint all Markdown files"
echo "  - bin/lint/py                 # Format, line and type check all Python files"
echo "  - bin/test                    # Run all unit tests"

echo "  - uv sync                     # Install/update dependencies"
echo "  - uv run ruff check           # Lint code"
echo "  - uv run ruff format          # Format code"
echo "  - uv run pyright              # Type checking"
echo "  - uv run python -m src.main   # Run main application"
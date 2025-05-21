#!/usr/bin/env bash
set -e

# Determine where this script is located
SUBREPO_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SUBREPO_NAME="$(basename "$SUBREPO_PATH")"
echo "Subrepo path: $SUBREPO_PATH"

# Traverse up to find the parent Git repo
SEARCH_PATH="$SUBREPO_PATH"
PARENT_PATH=""
while [ "$SEARCH_PATH" != "/" ]; do
    if [ -d "$SEARCH_PATH/.git" ]; then
        PARENT_PATH="$SEARCH_PATH"
        break
    fi
    SEARCH_PATH="$(dirname "$SEARCH_PATH")"
done

if [ -z "$PARENT_PATH" ] || [ "$PARENT_PATH" == "$SUBREPO_PATH" ]; then
    echo "❌ No parent Git repo found above subrepo."
    exit 1
fi

echo "Parent repo: $PARENT_PATH"

# Copy pre-commit config if it exists
if [ -f "$SUBREPO_PATH/.pre-commit-config.yaml" ]; then
    cp "$SUBREPO_PATH/.pre-commit-config.yaml" "$PARENT_PATH/.pre-commit-config.yaml"
    echo "✅ Copied .pre-commit-config.yaml"
fi

# Create .githooks and pre-commit hook
HOOKS_DIR="$PARENT_PATH/.githooks"
mkdir -p "$HOOKS_DIR"
HOOK_FILE="$HOOKS_DIR/pre-commit"

echo '#!/usr/bin/env bash' > "$HOOK_FILE"
echo 'exec pre-commit run --all-files' >> "$HOOK_FILE"
chmod +x "$HOOK_FILE"
echo "✅ Created pre-commit hook in .githooks"

# Configure Git to use .githooks if not already set
CURRENT_HOOKS_PATH=$(git -C "$PARENT_PATH" config core.hooksPath || echo "")
if [ "$CURRENT_HOOKS_PATH" != ".githooks" ]; then
    git -C "$PARENT_PATH" config core.hooksPath .githooks
    echo "🔧 Set Git hooks path to .githooks"
fi

# Add .githooks to .gitignore (optional, for dynamic generation)
if ! grep -q "^.githooks/$" "$PARENT_PATH/.gitignore" 2>/dev/null; then
    echo ".githooks/" >> "$PARENT_PATH/.gitignore"
    echo "🧼 Added .githooks/ to .gitignore"
fi

# Ensure run.sh is executable
RUN_SCRIPT="$SUBREPO_PATH/run.sh"
if [ ! -f "$RUN_SCRIPT" ]; then
    echo "❌ $RUN_SCRIPT not found"
    exit 1
fi
chmod +x "$RUN_SCRIPT"

# Symlink run.sh in parent
SYMLINK="$PARENT_PATH/run.sh"
if [ -L "$SYMLINK" ] || [ -e "$SYMLINK" ]; then
    rm -f "$SYMLINK"
fi
ln -s "$RUN_SCRIPT" "$SYMLINK"
echo "✅ Symlinked $RUN_SCRIPT to $SYMLINK"

# Build Docker image
DOCKERFILE="$SUBREPO_PATH/Dockerfile"
if [ ! -f "$DOCKERFILE" ]; then
    echo "❌ No Dockerfile in $SUBREPO_PATH"
    exit 1
fi

echo "🔧 Building Docker image: $SUBREPO_NAME"
docker build -t "$SUBREPO_NAME" -f "$DOCKERFILE" "$SUBREPO_PATH"

echo "✅ Done: Environment ready for $SUBREPO_NAME"
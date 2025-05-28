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
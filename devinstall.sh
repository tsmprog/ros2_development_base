#!/usr/bin/env bash
set -e  # Abort on error

DOCKER_CLEAN=true
if [ $# -gt 0 ]; then
    DOCKER_ARGS="$1" && shift 1
    [[ "$1" == "--keep" ]] && DOCKER_CLEAN=false && shift 1
fi

if [ -n "$DOCKER_ARGS" ]; then
    DOCKER_ARGS=(--build-arg "$DOCKER_ARGS")
else
    DOCKER_ARGS=()
fi

SUBREPO_PATH="$(git rev-parse --show-toplevel)"
SUBREPO_NAME="$(basename "$SUBREPO_PATH")"
echo "Setting up development environment for subrepo: $SUBREPO_NAME"

PARENT_PATH="$(dirname "$SUBREPO_PATH")"

if [ -d "$PARENT_PATH/.git" ]; then
    echo "Detected parent git repo at: $PARENT_PATH"

    # Copy pre-commit config if exists
    if [ -f "$SUBREPO_PATH/.pre-commit-config.yaml" ]; then
        echo "Copying .pre-commit-config.yaml to parent repo..."
        cp "$SUBREPO_PATH/.pre-commit-config.yaml" "$PARENT_PATH/.pre-commit-config.yaml"
    else
        echo "Warning: .pre-commit-config.yaml not found in subrepo."
    fi

    # Create pre-commit hook in parent repo
    GITHOOKS_DIR="$PARENT_PATH/.githooks"
    mkdir -p "$GITHOOKS_DIR"
    PRE_COMMIT_HOOK="$GITHOOKS_DIR/pre-commit"
    echo '#!/usr/bin/env bash' > "$PRE_COMMIT_HOOK"
    echo 'exec pre-commit run --all-files' >> "$PRE_COMMIT_HOOK"
    chmod +x "$PRE_COMMIT_HOOK"
    echo "Created pre-commit hook script in parent repo."

    (
      cd "$PARENT_PATH"
      if command -v pre-commit &> /dev/null; then
          echo "Installing pre-commit hook in parent repo..."
          pre-commit install --hook-type pre-commit
      else
          echo "Warning: pre-commit command not found. Please install pre-commit in your environment."
      fi
    )

    # Symlink run.sh in parent only if parent repo exists
    RUN_SCRIPT="$SUBREPO_PATH/run.sh"
    if [ ! -f "$RUN_SCRIPT" ]; then
        echo "Run script $RUN_SCRIPT not found!"
        exit 1
    fi
    chmod +x "$RUN_SCRIPT"
    echo "Made $RUN_SCRIPT executable."

    SYMLINK_PATH="$PARENT_PATH/run.sh"

    if [ -L "$SYMLINK_PATH" ]; then
        echo "Symlink $SYMLINK_PATH already exists, updating it."
        rm "$SYMLINK_PATH"
    elif [ -e "$SYMLINK_PATH" ]; then
        echo "Error: $SYMLINK_PATH exists and is not a symlink. Please remove or rename it."
        exit 1
    fi

    ln -s "$RUN_SCRIPT" "$SYMLINK_PATH"
    echo "Created symlink to run script at $SYMLINK_PATH"

else
    echo "No parent git repo detected. Skipping parent repo pre-commit setup and symlink creation."

    # Still make run.sh executable in the current repo
    RUN_SCRIPT="$SUBREPO_PATH/run.sh"
    if [ ! -f "$RUN_SCRIPT" ]; then
        echo "Run script $RUN_SCRIPT not found!"
        exit 1
    fi
    chmod +x "$RUN_SCRIPT"
    echo "Made $RUN_SCRIPT executable."
fi

# Build Docker image from subrepo Dockerfile
DOCKERFILE_PATH="$SUBREPO_PATH/Dockerfile"
if [ ! -f "$DOCKERFILE_PATH" ]; then
    echo "Dockerfile not found in $DOCKERFILE_PATH!"
    exit 1
fi

echo "Building (or rebuilding) Docker image '$SUBREPO_NAME' with cache..."
docker build -t "$SUBREPO_NAME" "${DOCKER_ARGS[@]}" -f "$DOCKERFILE_PATH" "$SUBREPO_PATH"
echo "Docker image '$SUBREPO_NAME' build completed."

if $DOCKER_CLEAN; then
    echo "Cleaning up temporary files..."
    # Optional: docker system prune -f
fi

echo "Development environment setup complete."

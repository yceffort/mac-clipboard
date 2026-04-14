.RECIPEPREFIX := >
SHELL := /bin/zsh

.PHONY: tools format format-check lint build test quality package

tools:
>brew bundle --file Brewfile --no-lock

format:
>./scripts/format.sh write

format-check:
>./scripts/format.sh check

lint:
>./scripts/lint.sh

build:
>./scripts/build.sh debug

test:
>./scripts/test.sh

quality:
>./scripts/format.sh check
>./scripts/lint.sh
>./scripts/build.sh debug
>./scripts/test.sh

package:
>./scripts/package_app.sh

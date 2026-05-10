UV ?= uv

.PHONY: info test lint typecheck lock-check parser-map

info:
	$(UV) run imos-toolbox info

test:
	$(UV) run pytest -v

lint:
	$(UV) run ruff check src tests

typecheck:
	$(UV) run mypy src

lock-check:
	$(UV) lock --check

parser-map:
	$(UV) run imos-toolbox parser-map --make "SEABIRD" --model "SBE19plus V2" --repo-root ..

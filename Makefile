.PHONY: help install start stop restart logs clean index ingest search search-examples test version

# 默认目标
help:
	@echo "Quickwit Demo - Makefile"
	@echo ""
	@echo "Usage: make <target>"
	@echo ""
	@echo "Docker targets:"
	@echo "  start          Start Quickwit with Docker Compose"
	@echo "  stop           Stop all services"
	@echo "  restart        Restart services"
	@echo "  logs           View Quickwit logs"
	@echo "  clean          Remove data and containers"
	@echo ""
	@echo "Index targets:"
	@echo "  index          Create stackoverflow index"
	@echo "  ingest         Download and ingest sample data"
	@echo ""
	@echo "Search targets:"
	@echo "  search         Run basic search example"
	@echo "  search-examples Run all search examples"
	@echo ""
	@echo "Utility targets:"
	@echo "  test           Test API endpoint"
	@echo "  version        Check Quickwit version"
	@echo ""
	@echo "Demo targets:"
	@echo "  install        Install Quickwit locally (native)"
	@echo "  demo           Full demo: install + start + index + ingest + search"
	@echo ""
	@echo "Options:"
	@echo "  QW_VERSION=n   Set Quickwit version (default: nightly)"

QW_VERSION ?= v0.8.2
COMPOSE := $(shell docker compose version > /dev/null 2>&1 && echo "docker compose" || echo "docker-compose")

# Docker targets
start:
	@mkdir -p qwdata
	@$(COMPOSE) up -d quickwit
	@echo "Waiting for Quickwit to be ready..."
	@for i in $$(seq 1 30); do \
		curl -sf http://localhost:7280/api/v1/version > /dev/null 2>&1 && break || sleep 1; \
	done
	@echo "Quickwit is ready at http://localhost:7280"

stop:
	$(COMPOSE) down

restart: stop start

logs:
	$(COMPOSE) logs -f quickwit

clean:
	$(COMPOSE) down -v
	rm -rf qwdata

# Index targets
index:
	@if ! curl -sf http://localhost:7280/api/v1/version > /dev/null; then \
		echo "Error: Quickwit is not running. Run 'make start' first."; \
		exit 1; \
	fi
	@curl -sO https://raw.githubusercontent.com/quickwit-oss/quickwit/main/config/tutorials/stackoverflow/index-config.yaml 2>/dev/null || true
	@curl -s -XPOST http://localhost:7280/api/v1/indexes \
		-H "Content-Type: application/yaml" \
		--data-binary @stackoverflow-index-config.yaml
	@echo ""

ingest:
	@if [ ! -f stackoverflow.posts.transformed-10000.json ]; then \
		curl -sO https://quickwit-datasets-public.s3.amazonaws.com/stackoverflow.posts.transformed-10000.json; \
	fi
	@curl -s -XPOST "http://localhost:7280/api/v1/stackoverflow/ingest?commit=force" \
		--data-binary @stackoverflow.posts.transformed-10000.json
	@echo ""

# Search targets
SEARCH_QUERY ?= "search AND engine"
search:
	@curl -s "http://localhost:7280/api/v1/stackoverflow/search?query=$$(echo '$(SEARCH_QUERY)' | tr ' ' '+')"

search-examples:
	@echo "=== Search Example 1: Basic ===" && \
	curl -s "http://localhost:7280/api/v1/stackoverflow/search?query=search+AND+engine" | python3 -c "import json,sys; d=json.load(sys.stdin); print(f'Found {d[\"num_hits\"]} hits')" && echo ""
	@echo "=== Search Example 2: Field ===" && \
	curl -s "http://localhost:7280/api/v1/stackoverflow/search?query=title:rust" | python3 -c "import json,sys; d=json.load(sys.stdin); print(f'Found {d[\"num_hits\"]} hits')" && echo ""
	@echo "=== Search Example 3: Aggregation ===" && \
	curl -s -XPOST "http://localhost:7280/api/v1/stackoverflow/search" \
		-H "Content-Type: application/json" \
		-d '{"query":"*","max_hits":0,"aggs":{"top_tags":{"terms":{"field":"tags","size":5}}}}' \
		| python3 -c "import json,sys; d=json.load(sys.stdin); [print(f'  {b[\"key\"]}: {b[\"doc_count\"]}') for b in d.get('aggregations',{}).get('top_tags',{}).get('buckets',[])]"

# Utility targets
test:
	@curl -sf http://localhost:7280/api/v1/version | python3 -m json.tool

version:
	@docker run --rm quickwit/quickwit:$(QW_VERSION) --version

# Native install (no Docker)
install:
	@echo "Installing Quickwit $(QW_VERSION)..."
	@curl -L https://install.quickwit.io | sh

# Full demo
demo: start index ingest search
	@echo ""
	@echo "Demo complete! Open http://localhost:7280 to explore."

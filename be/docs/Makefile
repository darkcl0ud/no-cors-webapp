.PHONY: all clean help
all:
	@npm i
	@npx redocly bundle main.yml --output openapi.yml

clean:
	@rm -rf openapi.yml node_modules

help:
	@echo "Available targets:"
	@echo "  all          - Bundle openapi.yml"
	@echo "  clean        - Remove openapi.yml"
	@echo "  help         - Show this help message"
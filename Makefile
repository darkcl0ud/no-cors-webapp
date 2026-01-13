.PHONY: all clean help

all:
	$(MAKE) -C be
	tofu init

clean:
	tofu init
	$(MAKE) clean -C be

help:
	@echo "Available targets:"
	@echo "  all          - Builds the fullstack"
	@echo "  clean        - Destroys the fullstack"
	@echo "  help         - Show this help message"
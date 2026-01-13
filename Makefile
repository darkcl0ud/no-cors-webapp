.PHONY: all clean help

all:
	$(MAKE) -C be
	tofu init
	tofu apply

clean:
	tofu init
	tofu destroy
	$(MAKE) clean -C be

help:
	@echo "Available targets:"
	@echo "  all          - Builds the fullstack"
	@echo "  clean        - Destroys the fullstack"
	@echo "  help         - Show this help message"
all:
	$(MAKE) -C docs
	@go tool oapi-codegen --config=codegen.yml docs/openapi.yml
	@docker build -t no-cors-webapp/be .
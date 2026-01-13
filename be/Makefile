.PHONY: all clean help

ECR_REPO_URI := $(shell aws ecr describe-repositories --repository-names no-cors-webapp/be --query 'repositories[0].repositoryUri' --output text || aws ecr create-repository --repository-name no-cors-webapp/be --query 'repository.repositoryUri' --output text)

all:
	$(MAKE) -C docs
	@go tool oapi-codegen --config=codegen.yml docs/openapi.yml
	@docker build -t no-cors-webapp/be . --platform linux/arm64
	@aws ecr get-login-password | docker login --username AWS --password-stdin $(ECR_REPO_URI)
	@docker tag no-cors-webapp/be:latest $(ECR_REPO_URI):latest
	@docker push $(ECR_REPO_URI):latest

clean:
	$(MAKE) clean -C docs
	@rm internal/api/openapi.gen.go
	@docker rmi $(ECR_REPO_URI):latest
	@aws ecr delete-repository --repository-name no-cors-webapp/be --force

help:
	@echo "Available targets:"
	@echo "  all          - Bundle openapi.yml"
	@echo "  clean        - Remove openapi.yml"
	@echo "  help         - Show this help message"
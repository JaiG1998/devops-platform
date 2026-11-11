.PHONY: fmt validate tflint checkov clean

fmt:
	terraform fmt -check -recursive

validate:
	@find terraform -name "*.tf" -exec dirname {} \; | sort -u | while read dir; do \
		echo "Validating $$dir..."; \
		cd $$dir && terraform init -backend=false -input=false && terraform validate && cd - > /dev/null; \
	done

tflint:
	tflint --recursive

checkov:
	checkov -d terraform/

ci-local: fmt validate tflint checkov
	@echo "All local CI checks passed successfully!"
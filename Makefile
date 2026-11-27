.PHONY: fmt validate tflint checkov clean k8s-check helm-lint render schema-check policy-check namespaces

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

# --- Kubernetes Checks ---

helm-lint:
	helm lint k8s/charts/online-boutique -f k8s/charts/online-boutique/values.yaml
	helm lint k8s/charts/online-boutique -f k8s/charts/online-boutique/values-dev.yaml
	helm lint k8s/charts/online-boutique -f k8s/charts/online-boutique/values-prod.yaml

render:
	@helm template online-boutique k8s/charts/online-boutique -f k8s/charts/online-boutique/values-dev.yaml | kubeconform --strict
	@helm template online-boutique k8s/charts/online-boutique -f k8s/charts/online-boutique/values-prod.yaml | kubeconform --strict

schema-check:
	@ajv validate -s k8s/charts/online-boutique/values.schema.json -d k8s/charts/online-boutique/values.yaml
	@ajv validate -s k8s/charts/online-boutique/values.schema.json -d k8s/charts/online-boutique/values-dev.yaml
	@ajv validate -s k8s/charts/online-boutique/values.schema.json -d k8s/charts/online-boutique/values-prod.yaml

policy-check:
	@helm template online-boutique k8s/charts/online-boutique -f k8s/charts/online-boutique/values-prod.yaml | kube-linter lint --config k8s/charts/online-boutique/kube-linter.yml -

k8s-check: helm-lint render schema-check policy-check
	@echo "All k8s checks passed successfully!"

ci-local: fmt validate tflint checkov k8s-check
	@echo "All local CI checks passed successfully!"

.PHONY: namespaces
namespaces:
	bash scripts/apply-namespaces.sh k8s/namespaces
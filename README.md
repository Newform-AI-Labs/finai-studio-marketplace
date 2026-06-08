# FinAI Studio — GCP Marketplace artifact

Customer-side deployment artifact for **FinAI Studio** (Newform Technologies),
published as a Kubernetes application (Helm, deployed via Terraform) on the
Google Cloud Marketplace. This repo is **separate** from the publisher-side
Terraform (`newform-infra`) that builds and ships the product.

> Scaffold status: placeholder chart. Items marked `TODO` / `PLACEHOLDER` must
> be completed before the first Marketplace deployer build.

## Layout

```
chart/finai-studio/
├── Chart.yaml                 # chart + app version, Marketplace product-id annotation
├── values.yaml                # full env-var surface (mirrors backend app/core/config.py)
├── schema.yaml                # Marketplace install form (customer-facing subset)
├── .helmignore
├── files/
│   └── validate.py            # pre-install validation script (source of truth)
└── templates/
    ├── _helpers.tpl
    ├── application.yaml        # K8s Application CRD (Marketplace requirement)
    ├── namespaces.yaml         # control / agents / workflow / datasource
    ├── serviceaccounts.yaml    # Workload Identity KSAs (5)
    ├── configmap-runtime.yaml  # finai-runtime-config (consumed by backend + every built pod)
    ├── rbac-backend.yaml       # studio-controller build (Jobs) + deploy (Deploy/Svc/HPA) RBAC
    ├── networkpolicy.yaml      # default-deny egress baseline (RCE incident remediation)
    ├── NOTES.txt
    ├── control-plane/          # backend + frontend Deployments/Services (PLACEHOLDER)
    ├── agents/                 # pre-built agents (runtime-populated for custom agents)
    ├── workflow/               # runtime-populated (Deployment+Svc+HPA, NOT Jobs)
    ├── datasource/             # runtime-populated MCP servers
    ├── preinstall/             # validation Job + ConfigMap + RBAC (pre-install hook)
    └── tests/                  # post-install tester Pod (helm test hook)

validator/
├── Dockerfile                 # builds the pre-install validator image
└── requirements.txt
```

## Namespace topology (consolidated)

Confirmed against backend code (`app/core/config.py`, `app/service/*/build_deploy`):

| Tier | Namespace (default) | Populated by | Workload shape |
|---|---|---|---|
| Control plane | `agentic-ai-internal` | Helm | Frontend + Backend Deployments; transient Kaniko **Jobs** |
| Agents | `agentic-ai-agents` | Helm (pre-built) + backend (custom) | Deployment + Service + HPA |
| Workflow | `agentic-ai-workflow` | Backend at runtime | **Deployment + Service + HPA** (not Jobs) |
| Datasource (MCP) | `agentic-ai-connectors` | Backend at runtime | Deployment + Service + HPA |

The legacy `tools` + `connectors` split is consolidated into one **datasource**
tier. There is no `evaluation` namespace in code yet (deferred per leadership).

## Local validation

```bash
helm lint chart/finai-studio
helm template demo chart/finai-studio \
  --set customer.projectId=my-proj \
  --set customer.artifactRegistry=us-central1-docker.pkg.dev/my-proj/finai \
  --set customer.buildContextBucket=my-proj-build-ctx
```

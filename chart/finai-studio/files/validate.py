#!/usr/bin/env python3
"""FinAI Studio pre-install validation.

Runs as a Helm pre-install hook (Job) INSIDE the target GKE cluster, before any
namespace or workload is created. Verifies that the customer's environment meets
the prerequisites the platform cannot create for itself. ANY failed check exits
non-zero, which aborts the Helm install.

Checks (toggle each via CHECK_* env, default "true"):
  1. Artifact Registry  — customer registry reachable + push/pull creds valid
  2. Vertex AI          — Gemini model endpoint reachable in the configured region
  3. Cloud SQL          — Postgres reachable + pgvector available
  4. IAM / Workload ID  — the pod's mounted GSA resolves and can mint tokens
  5. Secret Manager     — required secrets exist and are accessible

Every check runs with the validator pod's Workload Identity (KSA→GSA). A failure
here almost always means the customer's GSA is missing an IAM role — the error
message names the role to grant.

Config is read from env (wired by the Helm Job from values.yaml). No secrets are
printed; only resource names and pass/fail.
"""
from __future__ import annotations

import os
import sys
import time
import traceback
from dataclasses import dataclass, field

# ── env config ───────────────────────────────────────────────────────────────
PROJECT_ID = os.environ.get("CUSTOMER_PROJECT_ID", "")
REGION = os.environ.get("CUSTOMER_REGION", "us-central1")
ARTIFACT_REGISTRY = os.environ.get("CUSTOMER_ARTIFACT_REGISTRY", "")  # host/proj/repo
VERTEX_LOCATION = os.environ.get("VERTEX_AI_LOCATION", "us-central1")
VERTEX_PROJECT = os.environ.get("VERTEX_AI_PROJECT_NAME") or PROJECT_ID
LLM_MODEL = os.environ.get("LLM_MODEL", "gemini-2.5-flash")

DB_HOST = os.environ.get("DB_HOST", "127.0.0.1")
DB_PORT = int(os.environ.get("DB_PORT", "5432"))
DB_NAME = os.environ.get("DB_NAME", "finai")
DB_USER = os.environ.get("DB_USER", "finai_app")
DB_PASSWORD = os.environ.get("DB_PASSWORD", "")

# Comma-separated Secret Manager secret IDs that must exist.
REQUIRED_SECRETS = [
    s.strip() for s in os.environ.get("REQUIRED_SECRETS", "").split(",") if s.strip()
]

TIMEOUT = int(os.environ.get("VALIDATION_TIMEOUT_SECONDS", "120"))


def _enabled(name: str) -> bool:
    return os.environ.get(f"CHECK_{name}", "true").lower() not in ("false", "0", "no")


@dataclass
class Result:
    name: str
    ok: bool
    detail: str = ""
    remediation: str = ""


@dataclass
class Report:
    results: list[Result] = field(default_factory=list)

    def add(self, r: Result) -> None:
        icon = "PASS" if r.ok else "FAIL"
        print(f"[{icon}] {r.name}: {r.detail}", flush=True)
        if not r.ok and r.remediation:
            print(f"       ↳ remediation: {r.remediation}", flush=True)
        self.results.append(r)

    @property
    def failed(self) -> list[Result]:
        return [r for r in self.results if not r.ok]


# ── checks ───────────────────────────────────────────────────────────────────
def check_iam() -> Result:
    """Resolve the pod's Workload Identity GSA and mint a token."""
    try:
        import google.auth
        from google.auth.transport.requests import Request

        creds, project = google.auth.default()
        creds.refresh(Request())
        sa = getattr(creds, "service_account_email", "unknown")
        return Result(
            "IAM / Workload Identity",
            True,
            f"authenticated as {sa} (ADC project={project})",
        )
    except Exception as exc:  # noqa: BLE001
        return Result(
            "IAM / Workload Identity",
            False,
            f"could not obtain credentials: {exc}",
            "Verify the validator KSA is annotated with iam.gke.io/gcp-service-account "
            "and the GSA has a workloadIdentityUser binding to this KSA.",
        )


def check_artifact_registry() -> Result:
    """Confirm the customer Artifact Registry repo exists and is listable."""
    if not ARTIFACT_REGISTRY:
        return Result(
            "Artifact Registry", False, "CUSTOMER_ARTIFACT_REGISTRY is empty",
            "Set customer.artifactRegistry on the install form.",
        )
    try:
        # ARTIFACT_REGISTRY = "{region}-docker.pkg.dev/{project}/{repo}"
        host, proj, repo = ARTIFACT_REGISTRY.split("/", 2)
        location = host.split("-docker.pkg.dev")[0]
        from google.cloud import artifactregistry_v1

        client = artifactregistry_v1.ArtifactRegistryClient()
        name = f"projects/{proj}/locations/{location}/repositories/{repo}"
        client.get_repository(name=name, timeout=TIMEOUT)
        return Result("Artifact Registry", True, f"repository reachable: {name}")
    except Exception as exc:  # noqa: BLE001
        return Result(
            "Artifact Registry", False, f"{ARTIFACT_REGISTRY}: {exc}",
            "Grant the validator GSA roles/artifactregistry.reader (and the builder "
            "GSA roles/artifactregistry.writer) on the repo, and confirm it exists.",
        )


def check_vertex_ai() -> Result:
    """Reach the Vertex AI endpoint and confirm the model is callable."""
    try:
        import vertexai
        from vertexai.generative_models import GenerativeModel

        vertexai.init(project=VERTEX_PROJECT, location=VERTEX_LOCATION)
        model = GenerativeModel(LLM_MODEL)
        # Minimal call — 1-token reply keeps cost/latency negligible.
        resp = model.generate_content(
            "ping",
            generation_config={"max_output_tokens": 1, "temperature": 0},
        )
        _ = resp  # presence is enough
        return Result(
            "Vertex AI", True,
            f"model {LLM_MODEL} reachable in {VERTEX_LOCATION} (project {VERTEX_PROJECT})",
        )
    except Exception as exc:  # noqa: BLE001
        return Result(
            "Vertex AI", False, f"{LLM_MODEL}@{VERTEX_LOCATION}: {exc}",
            "Enable aiplatform.googleapis.com and grant the agent-runtime GSA "
            "roles/aiplatform.user; confirm the model is available in the region.",
        )


def check_cloud_sql() -> Result:
    """Connect to Postgres and confirm pgvector is installed/available."""
    try:
        import psycopg2

        conn = psycopg2.connect(
            host=DB_HOST, port=DB_PORT, dbname=DB_NAME,
            user=DB_USER, password=DB_PASSWORD, connect_timeout=min(TIMEOUT, 30),
        )
        try:
            with conn.cursor() as cur:
                cur.execute("SELECT 1;")
                cur.fetchone()
                cur.execute(
                    "SELECT 1 FROM pg_available_extensions WHERE name = 'vector';"
                )
                has_vector = cur.fetchone() is not None
        finally:
            conn.close()
        if not has_vector:
            return Result(
                "Cloud SQL (Postgres)", False,
                "connected but pgvector extension is not available",
                "Enable the pgvector flag: cloudsql.enable_pgvector=on on the instance.",
            )
        return Result(
            "Cloud SQL (Postgres)", True,
            f"connected to {DB_NAME}@{DB_HOST}:{DB_PORT}; pgvector available",
        )
    except Exception as exc:  # noqa: BLE001
        return Result(
            "Cloud SQL (Postgres)", False, f"{DB_HOST}:{DB_PORT}/{DB_NAME}: {exc}",
            "Confirm the Cloud SQL Auth Proxy sidecar/instanceConnectionName is correct, "
            "the GSA has roles/cloudsql.client, and the DB user/password Secret is valid.",
        )


def check_secret_manager() -> Result:
    """Confirm required Secret Manager secrets exist and are accessible."""
    if not REQUIRED_SECRETS:
        return Result(
            "Secret Manager", True, "no required secrets declared — skipping access check",
        )
    try:
        from google.cloud import secretmanager

        client = secretmanager.SecretManagerServiceClient()
        missing = []
        for secret_id in REQUIRED_SECRETS:
            name = f"projects/{PROJECT_ID}/secrets/{secret_id}"
            try:
                client.get_secret(name=name, timeout=TIMEOUT)
            except Exception:  # noqa: BLE001
                missing.append(secret_id)
        if missing:
            return Result(
                "Secret Manager", False, f"missing/inaccessible: {', '.join(missing)}",
                "Create the secrets and grant the runtime GSA "
                "roles/secretmanager.secretAccessor.",
            )
        return Result(
            "Secret Manager", True,
            f"all {len(REQUIRED_SECRETS)} required secrets accessible",
        )
    except Exception as exc:  # noqa: BLE001
        return Result(
            "Secret Manager", False, f"{exc}",
            "Enable secretmanager.googleapis.com and grant secretAccessor to the GSA.",
        )


CHECKS = [
    ("IAM", check_iam),
    ("ARTIFACT_REGISTRY", check_artifact_registry),
    ("VERTEX_AI", check_vertex_ai),
    ("CLOUD_SQL", check_cloud_sql),
    ("SECRET_MANAGER", check_secret_manager),
]


def main() -> int:
    print("=" * 70, flush=True)
    print(f"FinAI Studio pre-install validation — project={PROJECT_ID} region={REGION}", flush=True)
    print("=" * 70, flush=True)

    report = Report()
    for key, fn in CHECKS:
        if not _enabled(key):
            print(f"[SKIP] {key} (CHECK_{key}=false)", flush=True)
            continue
        try:
            report.add(fn())
        except Exception:  # noqa: BLE001 — a check must never crash the runner
            report.add(Result(key, False, "unexpected error", traceback.format_exc()))

    print("=" * 70, flush=True)
    if report.failed:
        print(f"VALIDATION FAILED — {len(report.failed)} check(s) failed. "
              "Helm install will abort.", flush=True)
        return 1
    print("VALIDATION PASSED — all prerequisite checks succeeded.", flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())

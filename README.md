**A real CVE, actually root-caused, not just patched over:** Trivy flagged
`jackson-databind` as vulnerable across three separate Spring Boot version
bumps. The real cause was a hardcoded `<version>2.15.0</version>` on the
dependency, silently overriding Spring Boot's own dependency management on
every attempt to fix it. Removing the pin and letting Spring Boot's BOM (plus
a few targeted property overrides — `tomcat.version`, `spring-framework.version`,
etc. — for patches Spring Boot's own release hadn't caught up to yet)
resolved it. See `pom.xml` and the commit history.


## Quickstart

Prerequisites: Docker, kind, Terraform, Helm, kubectl (or run
`./scripts/install-tools.sh`, which detects your OS and installs anything
missing).

```bash
./scripts/setup.sh
```

This builds the image, provisions the kind cluster via Terraform, loads the
image into the cluster, installs the app via Helm, and installs
Prometheus + Grafana. Takes several minutes on first run.

```bash
kubectl port-forward svc/crewmeister-app 8080:8080
curl -s -X POST localhost:8080/user -H 'Content-Type: application/json' -d '{"name":"Ada"}'
curl -s "localhost:8080/user?id=1"

kubectl port-forward svc/kube-prometheus-stack-grafana 3000:80 -n monitoring
# open http://localhost:3000, login admin/admin
```

Prefer plain Docker for a quick app+DB loop without Kubernetes at all:
`docker compose up --build`.

Tear down: `cd terraform && terraform destroy`.

## Design decisions & trade-offs

- **kind over a managed cloud cluster** — free, zero setup, matches the
  challenge's "runs locally" requirement. The Helm chart itself has no
  kind-specific dependency; pointed at a real cluster with an image in a
  reachable registry, it deploys unmodified.
- **Terraform owns the cluster, not the app release** — `helm_release` via
  Terraform creates a chicken-and-egg problem locally: the image can't be
  loaded into `kind` until the cluster exists, but Terraform's `helm_release`
  tries to install (and wait on) the app in the same `apply`. Splitting
  cluster-provisioning (Terraform) from app-install (plain Helm, in
  `scripts/setup.sh`, after the image load) avoids the race entirely. This
  only matters for the registry-free local path — once pushed to GHCR, this
  constraint goes away.
- **Trivy runs on every build but doesn't fail the pipeline** (`exit-code: 0`).
  Chosen deliberately: several flagged CVEs require a Spring Boot 4.0
  migration (Spring Boot 3.5 itself reached open-source EOL 2026-06-30; the
  full fix is an 80+ breaking-change upgrade, out of proportion for this
  project). Findings are visible in every CI run rather than silently
  ignored or blocking unrelated work.
- **NetworkPolicies are defined but not enforced locally** — kind's default
  CNI (kindnet) accepts `NetworkPolicy` objects but doesn't act on them. The
  policies are written and applied regardless, since they're portable,
  standard Kubernetes objects that work unmodified on any NetworkPolicy-
  enforcing CNI (Calico, Cilium, most managed cloud clusters).
- **Monitoring resource requests are tuned down from kube-prometheus-stack's
  defaults** — the chart assumes real cluster headroom; on a laptop running
  the whole stack simultaneously, default CPU limits on Grafana specifically
  caused severe throttling (plugin loading took 2+ minutes instead of
  seconds), triggering probe failures and restart loops. Fixed by dropping
  the CPU limit and raising probe `initialDelaySeconds`. See
  `monitoring/values-local.yaml`.

## What I'd add next

- ArgoCD for GitOps-driven deploys instead of imperative `helm upgrade`
- External Secrets Operator + a real secret backend (AWS Secrets Manager),
  replacing the plain Kubernetes `Secret` used for local dev
- A live AWS demo (k3s-on-EC2 or EKS) — the Terraform/Helm split here is
  structured so this is a values/variables change, not a rewrite
- OIDC-based GitHub Actions → AWS auth instead of static credentials, for
  whenever the AWS leg is added
- A committed Grafana dashboard JSON instead of the stack's defaults

## Repository layout

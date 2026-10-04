# langfuse-kind

A one-command, local, self-hosted [Langfuse](https://langfuse.com) (open source) on a [kind](https://kind.sigs.k8s.io) cluster, using the official [Helm chart](https://langfuse.com/self-hosting/deployment/kubernetes-helm), plus a tiny Python app that sends real OpenAI traces to it.

Use it as a disposable sandbox for experimenting with Langfuse on Kubernetes: chart values, tracing, prompts, evals, upgrades. Tear it down and rebuild in minutes.

> **Local dev only.** Passwords, salts and API keys in `values.yaml` are throwaway, publicly known values. Don't expose this cluster, and don't use these values for anything real.

## Quickstart

```bash
git clone https://github.com/glukicov/langfuse-kind.git && cd langfuse-kind

just up        # kind cluster + cert-manager + ClickHouse operator + Langfuse (~5 min)
just env       # creates .env from .env.example -> add your OPENAI_API_KEY to it
just demo      # calls OpenAI; traces land in your local Langfuse
```

Open <http://localhost:3000> and sign in with **`admin@local.dev` / `localpassword`**. Project **`demo`** is pre-created, with API keys `pk-lf-local` / `sk-lf-local`. Your traces are at <http://localhost:3000/project/demo/traces>.

When you're done: `just down` deletes the cluster.

## Prerequisites

| Tool | Notes |
| --- | --- |
| Docker | Give it ~6 GB RAM / 4 CPUs; ClickHouse is the hungry part |
| [kind](https://kind.sigs.k8s.io/docs/user/quick-start/#installation) | tested with 0.33 |
| kubectl, [Helm](https://helm.sh/docs/intro/install/) | Helm >= 3.17 required by the chart |
| [just](https://github.com/casey/just) | task runner |
| [uv](https://docs.astral.sh/uv/) | runs the demo app; installs Python deps on demand |
| OpenAI API key | only for the demo app |

Port **3000** on your machine must be free.

## What gets installed

| Component | How | Notes |
| --- | --- | --- |
| kind cluster `langfuse` | `kind-config.yaml` | single node; maps NodePort 30000 to `localhost:3000` (no port-forward needed) |
| cert-manager, ClickHouse operator | Helm, `just operators` | prerequisites of the current Langfuse chart, installed once per cluster |
| Langfuse (web, worker, Postgres, ClickHouse, Redis, SeaweedFS/S3) | Helm chart `2.0.0`, `values.yaml` | org, project, admin user and API keys are created on first boot via `LANGFUSE_INIT_*` |

## Recipes

Run `just` to list them.

| Recipe | What it does |
| --- | --- |
| `up` | `cluster` -> `operators` -> `install` -> `wait` |
| `env` | create `.env` from `.env.example` (never overwrites an existing one) |
| `demo [questions...]` | run `demo.py`; pass your own questions as arguments |
| `status` | `kubectl get pods -A` for the kind cluster |
| `logs [deploy]` | tail logs (default `langfuse-web`, e.g. `just logs langfuse-worker`) |
| `install` | re-apply `values.yaml` after you edit it (`helm upgrade --install`) |
| `down` | delete the cluster and everything in it |

## The demo app

`demo.py` is ~40 lines: an `@observe`-decorated function calls OpenAI through Langfuse's drop-in `langfuse.openai` client. Each call produces a trace with a nested generation including model, token usage and latency. Copy the pattern into your own app and point it at the same env vars:

```bash
LANGFUSE_BASE_URL=http://localhost:3000
LANGFUSE_PUBLIC_KEY=pk-lf-local
LANGFUSE_SECRET_KEY=sk-lf-local
```

`OPENAI_MODEL` defaults to `gpt-5-mini`. Langfuse can only compute cost for models in its pricing table; for others, add a model definition under *Settings -> Models*.

## Safe alongside other clusters

Every recipe passes `--context kind-langfuse` / `--kube-context kind-langfuse` explicitly, so it never touches whatever your current kubectl context is (a work cluster, for instance). `just up` also restores your previous context after kind creates the cluster.

## Customising

- **Chart values:** edit `values.yaml`, then `just install`. See the [chart README](https://github.com/langfuse/langfuse-k8s) for all options.
- **Versions:** chart, cert-manager and operator versions are pinned in the `justfile`.
- **Lighter footprint:** ClickHouse Keeper is already reduced to one replica in `values.yaml`.

## Troubleshooting

- **`langfuse-web` restarts a few times on first start**: normal while Postgres/ClickHouse initialise; `just wait` blocks until it's ready.
- **Pods stuck `Pending` / `OOMKilled`**: increase Docker's memory.
- **Port 3000 in use**: change `hostPort` in `kind-config.yaml` and `nextauth.url` in `values.yaml`, then recreate the cluster.
- **Reading traces via the API**: this Langfuse version (v4) disables `/api/public/traces`; use `GET /api/public/v2/observations?fromStartTime=...&fields=core,basic,model,usage`.
- **Docker Desktop's built-in Kubernetes** is separate from this cluster and not needed; you can leave it disabled.

## Layout

```
justfile          task recipes
kind-config.yaml  kind cluster + port mapping
values.yaml       Langfuse Helm values (local-only secrets, headless init)
demo.py           OpenAI demo app emitting Langfuse traces
.env.example      env template for the demo app
```

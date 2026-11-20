# DevOps Engineer Homework

A small Flask API, packaged as a Docker image and deployed to a local kind
cluster by a GitLab CI/CD pipeline that uses Terraform and Helm.

The code review part of the assignment is in [REVIEW.md](REVIEW.md).

## Repository layout

```
app/             Flask application, requirements.txt, Dockerfile
helm/            Helm chart (Deployment, Service, Ingress)
terraform/       Namespace and Helm release
.gitlab-ci.yml   Pipeline: validate -> build -> deploy
REVIEW.md        Code review of the starter project
```

## What gets deployed

There is one Kubernetes deployment, managed through the GitLab pipeline:

| Item | Value |
|---|---|
| Cluster | kind, called `homework` |
| Namespace | `production` |
| Helm release | `myapp` |
| Ingress host | `myapp.local` |

Terraform creates the namespace and installs the Helm chart.

## User guide

### 1. Run the app locally

```bash
python3 -m venv .venv && . .venv/bin/activate
pip install -r app/requirements.txt
ENVIRONMENT=dev python app/app.py          # listens on :8080
```

In another terminal:

```bash
# Health check
curl http://localhost:8080/health

# Application version
curl http://localhost:8080/version

# Environment variable
curl http://localhost:8080/env

# Create a config value
curl -H "Content-Type: application/json" \
  -d '{"name":"color","value":"blue"}' \
  http://localhost:8080/config

# Read the config value
curl http://localhost:8080/config/color

# Delete the config value
curl -X DELETE http://localhost:8080/config/color
```

Expected results:

| Operation | Response |
|---|---|
| Health | `{"status":"ok"}` |
| Version | `{"version":"1.0.0"}` |
| Environment | `{"environment":"dev"}` |
| POST config | `{"name":"color","value":"blue"}` |
| GET config | `{"name":"color","value":"blue"}` |
| DELETE config | `{"deleted":true}` |

### 2. Run it in Docker

```bash
docker build -t myapp:test app/
docker run --rm -d -p 8080:8080 -e ENVIRONMENT=dev --name myapp-test myapp:test
curl -i http://localhost:8080/health
docker stop myapp-test
```

### 3. Deploy with GitLab CI/CD

The source code is available on GitHub, while GitLab is used to run the CI/CD pipeline:

| Stage | Job | What it does |
|---|---|---|
| validate | `helm-lint` | `helm lint helm/` |
| validate | `terraform-validate` | `terraform fmt -check`, `init -backend=false`, `validate` |
| build | `build-image` | `docker build`, tagged with the short commit SHA (`$CI_COMMIT_SHORT_SHA`), then `kind load docker-image` |
| deploy | `deploy` | `terraform apply` with `image_tag` set to the short commit SHA. Runs on the default branch only |

The runner is a shell executor on the same machine as the kind cluster. For the
`gitlab-runner` user that machine needs `docker`, `kind`, `kubectl`, `helm` and
`terraform` on the PATH, membership of the `docker` group, a kubeconfig in
`~/.kube/config` with the context `kind-homework`, and a writable directory
`/var/lib/gitlab-runner-tfstate` for the Terraform state.

### 4. Check the deployment

```bash
kubectl get deploy,pods,svc,ingress -n production
kubectl get endpoints myapp -n production
kubectl get deployment myapp -n production -o wide
```

Through the Ingress (kind publishes port 80 of the node on 8088, and the Host
header is needed because `myapp.local` is not a real DNS name):

```bash
curl -i -H 'Host: myapp.local' http://localhost:8088/health
curl -i -H 'Host: myapp.local' http://localhost:8088/env      # {"environment":"prod"}
```

Or straight to the Service:

```bash
kubectl port-forward -n production svc/myapp 8080:8080
curl -i http://localhost:8080/health       # in another terminal
```

## What You Changed

**Application (new).** A Flask app with the six endpoints from the assignment,
in one file. Config values are kept in a dictionary in memory. I added `400` for
a bad `POST /config` and `404` for unknown names, because an API should say when
something is wrong. `/env` returns `null` when `ENVIRONMENT` is not set.

**Dockerfile (new).** `python:3.12-slim`. The dependencies are installed before
the code is copied, so a code change does not reinstall them, and
`--no-cache-dir` keeps the image small.

**Helm chart.**

- The Service selector said `myapps` and the Ingress backend said `homeworks`,
  so no traffic could reach the pod. Names now come from `{{ .Release.Name }}`.
- The container port was 5000 and the Service went 80 -> 8080. Now one port,
  `service.port` from `values.yaml` (8080), is used everywhere.
- `replicaCount` was in `values.yaml` but ignored. It is used now.
- The image tag `latest` is now `1.0.0` (the pipeline overrides it with the
  commit SHA), with `pullPolicy: IfNotPresent`, which is needed for images
  loaded into kind.
- Added `ingressClassName: nginx`, readiness and liveness probes on `/health`,
  and resource requests and limits.

**Terraform.**

- Fixed the syntax errors (empty `image.tag`, unquoted `prod`) and the chart
  path, and used the variables that were declared but never used, including the
  namespace that was hard-coded.
- Pinned the `kubernetes` and `helm` providers to `~> 2.0`, so a new major
  version cannot break the 2.x `set {}` syntax used here.
- Set `config_context = "kind-homework"`, so an `apply` cannot silently go to
  another cluster.
- Gave the variables a description and a default. The defaults for `namespace`
  (`production`) and `environment` (`prod`) are the values the starter had
  hard-coded.
- Removed `outputs.tf`. It was empty in the starter and nothing uses Terraform
  outputs.
- Added a `.gitignore` so the state and `.terraform/` are never committed.

**GitLab CI.** The two `echo` jobs became a real pipeline (see above). The
Terraform state is kept in a directory on the runner host, outside the build
directory, so each run sees what the previous one created.

**How I tested it.** The app locally and in Docker with `curl`. The chart with
`helm lint`, `helm template` and an install in kind. Terraform with `validate`,
`plan`, `apply` and `destroy` in a throwaway namespace. Then the pipeline itself:
all three stages passed and the pod ran the image tagged with the commit SHA.
I did not write unit tests for the app.

## Assumptions

- The cluster is a local kind cluster called `homework`, with ingress-nginx
  installed. I set up the kind cluster and ingress-nginx manually before running
  the pipeline. The pipeline deploys the application and its namespace; it does
  not create the cluster or install ingress-nginx. Kind publishes the node's
  port 80 on `127.0.0.1:8088` (port 80 on my machine is used by another web server).
- The GitLab runner runs on the same machine as the cluster. That is why the
  pipeline can reach the cluster and load the image with `kind load` instead of
  pushing it to a registry.
- The kubeconfig context is called `kind-homework`.
- The application reads `ENVIRONMENT` from the container. Terraform sets it to
  `prod` by default and passes it to Helm.

## Known Limitations

- Config is stored in memory. A restart loses it, and with more than one
  replica each pod would have its own copy.
- The app runs on the Flask development server, the container runs as root, and
  there are no unit tests.
- Resource requests and limits are estimates, not measurements.
- Images are built locally and loaded into kind. They are not pushed to a
  container registry.
- The Terraform state is a local file on the runner host, with no locking and no
  backup.
- The shell executor runs jobs directly on the host as the `gitlab-runner`
  user, who is in the `docker` group (effectively root).
- The pipeline deploys automatically from the default branch, with no approval
  step. There is no TLS and no authentication.
- The Ingress host and class are hard-coded in the chart.

## Production Improvements

- Use remote Terraform state with locking.
- Use a container registry and a more isolated GitLab Runner instead of the
  current shell executor.
- Run the app with Gunicorn as a non-root user, with a Kubernetes `securityContext`.
- Add automated tests and a manual approval before deploying to production.
- Use persistent storage for `/config` if the values need to survive restarts or
  be shared between replicas.

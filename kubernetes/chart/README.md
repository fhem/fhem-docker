# FHEM Helm Chart

A production-ready [Helm](https://helm.sh) chart for deploying the [FHEM](https://fhem.de/) home automation system using the official Debian-based container images ([`fhem/fhem-docker`](https://github.com/fhem/fhem-docker) / [`ghcr.io/fhem/fhem-docker`](https://github.com/orgs/fhem/packages)).

[![Artifact Hub](https://img.shields.io/badge/Artifact%20Hub-FHEM-blue)](https://artifacthub.io/)
[![Helm Version](https://img.shields.io/badge/Helm-v3.x-blue.svg)](https://helm.sh/)
[![FHEM Image](https://img.shields.io/badge/fhem--docker-5.4.0--bookworm-orange.svg)](https://github.com/fhem/fhem-docker)

---

## Table of Contents

- [FHEM Helm Chart](#fhem-helm-chart)
  - [Table of Contents](#table-of-contents)
  - [Overview](#overview)
  - [Architecture \& Design](#architecture--design)
  - [Prerequisites](#prerequisites)
  - [Quick Start](#quick-start)
    - [Installing the Chart](#installing-the-chart)
    - [Upgrading the Chart](#upgrading-the-chart)
    - [Uninstalling the Chart](#uninstalling-the-chart)
  - [Configuration via ConfigMap \& Environment Variables](#configuration-via-configmap--environment-variables)
    - [ConfigMap Mechanism](#configmap-mechanism)
    - [Supported Environment Variables Reference](#supported-environment-variables-reference)
  - [Chart Configuration Values](#chart-configuration-values)
    - [Controller \& Core Settings](#controller--core-settings)
    - [Image Parameters](#image-parameters)
    - [Metadata \& Service Account](#metadata--service-account)
    - [Networking \& Security](#networking--security)
    - [Environment Variables \& Secrets](#environment-variables--secrets)
    - [Networking \& Exposure (Service \& Ingress)](#networking--exposure-service--ingress)
    - [Gateway API (HTTPRoute, TCPRoute, UDPRoute \& Gateway)](#gateway-api-httproute-tcproute-udproute--gateway)
    - [Network Policy](#network-policy)
    - [Pod Disruption Budget](#pod-disruption-budget)
    - [Resources \& Probes](#resources--probes)
    - [Persistence \& Hardware Storage](#persistence--hardware-storage)
    - [Scheduling \& Extensibility](#scheduling--extensibility)
  - [Advanced Guides \& Recipes](#advanced-guides--recipes)
    - [1. USB Hardware Dongle Pass-Through (Zigbee, CUL, Z-Wave, EnOcean)](#1-usb-hardware-dongle-pass-through-zigbee-cul-z-wave-enocean)
    - [2. Host Networking for Local Discovery (mDNS, SSDP, Sonos, Cast)](#2-host-networking-for-local-discovery-mdns-ssdp-sonos-cast)
    - [3. Database Configuration (`configDB` \& Secrets)](#3-database-configuration-configdb--secrets)
      - [Using an Existing Secret](#using-an-existing-secret)
      - [Injecting Additional Database Credentials (e.g. for DbLog)](#injecting-additional-database-credentials-eg-for-dblog)
    - [4. Custom Pre-Start and Pre-Init Scripts](#4-custom-pre-start-and-pre-init-scripts)
    - [5. Sidecar Services (alexa-fhem, homebridge)](#5-sidecar-services-alexa-fhem-homebridge)
    - [6. Gateway API (HTTPRoute \& Gateway) Deployment](#6-gateway-api-httproute--gateway-deployment)
      - [Option A: Attaching HTTPRoute to an Existing Cluster Gateway](#option-a-attaching-httproute-to-an-existing-cluster-gateway)
      - [Option B: Creating a Dedicated Gateway with HTTPRoute](#option-b-creating-a-dedicated-gateway-with-httproute)
      - [Option C: Enabling Layer 4 Routes (`TCPRoute` and `UDPRoute`)](#option-c-enabling-layer-4-routes-tcproute-and-udproute)
    - [7. Network Policy Recipes](#7-network-policy-recipes)
      - [Restricting Ingress Traffic](#restricting-ingress-traffic)
      - [Restricting Egress Traffic (DNS, Database \& Smart Home LAN)](#restricting-egress-traffic-dns-database--smart-home-lan)
    - [8. Pod Disruption Budget (PDB) Configurations](#8-pod-disruption-budget-pdb-configurations)
      - [Preventing Disruptions During Node Drains (Zero-Downtime Guard)](#preventing-disruptions-during-node-drains-zero-downtime-guard)
      - [Allowing Automated Node Upgrades](#allowing-automated-node-upgrades)
  - [Persistence, Backups \& Recovery](#persistence-backups--recovery)
  - [Troubleshooting \& FAQs](#troubleshooting--faqs)
    - [Pod remains in `0/1` status or `/health-check.sh` reports `Cannot read url file /tmp/health-check.urls`](#pod-remains-in-01-status-or-health-checksh-reports-cannot-read-url-file-tmphealth-checkurls)
    - [Pod gets killed during startup](#pod-gets-killed-during-startup)
    - [Permission Denied inside `/opt/fhem`](#permission-denied-inside-optfhem)
    - [Viewing Realtime Logs](#viewing-realtime-logs)
    - [Connecting to the Telnet CLI](#connecting-to-the-telnet-cli)
  - [License](#license)

---

## Overview

[FHEM](https://fhem.de/) (Freundliche Hausautomation und Energie-Messung) is a GPL-licensed, highly extensible Perl-based home automation server. It automates common household tasks like switching lamps, shutters, heating, air conditioning, and logging events such as temperature, humidity, and power consumption.

This Helm chart packages the official multi-architecture `fhem-docker` container for Kubernetes deployments. It adheres strictly to Helm standards, provides automatic rollout triggers when configuration changes, and includes comprehensive support for hardware pass-through and persistent storage.

---

## Architecture & Design

1. **Statefulness & Single Replica**:
   FHEM maintains runtime state, logs, and configuration files directly inside `/opt/fhem` (such as `fhem.cfg` and `fhem.save`). Because FHEM is inherently a single-master daemon, running multiple instances concurrently against the same state directory causes split-brain issues. The chart defaults to `replicaCount: 1` and uses `strategy.type: Recreate` so that the volume is cleanly unmounted before a new pod mounts it.

2. **Decoupled Configuration via ConfigMap**:
   All container environment variables specified under `.Values.env` are translated into a Kubernetes `ConfigMap`. This ConfigMap is injected into the container via `envFrom.configMapRef`. A SHA256 checksum annotation (`checksum/config`) is automatically placed on the pod template, ensuring that modifications to `values.yaml` trigger an automatic rolling deployment without manual pod deletion.

3. **Multi-Port Exposure**:
   FHEM serves its primary web interface (`FHEMWEB`) on TCP port `8083` and an interactive command-line interface via Telnet on TCP port `7072`. Both are defined as named ports in the Kubernetes `Service` and `Deployment`. Additional service ports (such as MQTT or HomeKit) can be defined via `service.extraPorts`.

4. **Robust Health Probing**:
   FHEM's startup phase can take anywhere from 10 to 60+ seconds depending on loaded Perl modules and peripheral initialization. The chart implements a dedicated `startupProbe` alongside `livenessProbe` and `readinessProbe` to prevent Kubernetes from prematurely killing slow-starting instances.

5. **Modern Ingress & Gateway API Support**:
   FHEM can be exposed through traditional Kubernetes `Ingress` or modern Kubernetes `Gateway API` (`gateway.networking.k8s.io/v1`). You can deploy an `HTTPRoute` to attach to an existing cluster-wide Gateway (e.g., Envoy Gateway, Cilium, Istio) or provision an optional dedicated `Gateway` resource directly from this chart.

---

## Prerequisites

- Kubernetes cluster 1.19+ (or 1.25+ with Gateway API v1.6+ CRDs installed when using `httpRoute`/`gateway`, and a Gateway controller supporting `TCPRoute`/`UDPRoute` when L4 routes are enabled)
- Helm 3.8.0+ (required for OCI registries)
- A Kubernetes `StorageClass` supporting dynamic volume provisioning (or pre-provisioned PersistentVolumes) for persistent storage

---

## Quick Start

### Installing the Chart

The chart is published as an OCI artifact to the GitHub Container Registry at `oci://ghcr.io/fhem/charts/fhem`. No `helm repo add` is needed. Available versions are listed under [GitHub Packages](https://github.com/orgs/fhem/packages); pin one with `--version`, otherwise the latest version is used.

Install the chart with release name `my-fhem`:

```bash
helm install my-fhem oci://ghcr.io/fhem/charts/fhem
```

To install with traditional **Ingress** enabled:

```bash
helm install my-fhem oci://ghcr.io/fhem/charts/fhem \
  --set env.TZ="Europe/Vienna" \
  --set ingress.enabled=true \
  --set ingress.hosts[0].host="fhem.home.arpa"
```

To install using modern **Gateway API (`HTTPRoute` + `Gateway`)**:

```bash
helm install my-fhem oci://ghcr.io/fhem/charts/fhem \
  --set httpRoute.enabled=true \
  --set "httpRoute.hostnames[0]=fhem.home.arpa" \
  --set gateway.enabled=true \
  --set gateway.gatewayClassName="cilium"
```

> **Tip**: If you are installing directly from a local git checkout, you can replace `oci://ghcr.io/fhem/charts/fhem` with `.`.

### Upgrading the Chart

To upgrade an existing installation:

```bash
helm upgrade my-fhem oci://ghcr.io/fhem/charts/fhem -f my-values.yaml
```

### Uninstalling the Chart

To uninstall/delete the `my-fhem` deployment:

```bash
helm uninstall my-fhem
```

> **Note**: In accordance with Kubernetes standards, PersistentVolumeClaims (PVCs) created by the chart are not deleted automatically by `helm uninstall` to protect your smart home state. If you wish to delete the PVC manually:
> ```bash
> kubectl delete pvc my-fhem
> ```

---

## Configuration via ConfigMap & Environment Variables

### ConfigMap Mechanism

The chart isolates all container configuration into the `.Values.env` dictionary in `values.yaml`. During template rendering:

1. A Kubernetes `ConfigMap` named `<release-name>-fhem-config` is generated from `.Values.env`.
2. Non-empty string keys are converted directly to ConfigMap `data` entries.
3. The pod spec mounts the ConfigMap using `envFrom`:
   ```yaml
   envFrom:
     - configMapRef:
         name: my-fhem-fhem-config
   ```
4. Pod annotations include a SHA-256 hash of the rendered ConfigMap:
   ```yaml
   checksum/config: <sha256-hash>
   ```
   Whenever you update any variable under `env:`, Helm recalculates the checksum and Kubernetes executes a restart with the updated parameters.

### Supported Environment Variables Reference

The following table documents every environment variable supported by `fhem-docker` that can be configured under the `.Values.env` section:

| Variable           |  Type  |      Default      | Description                                                                                                                        |
| :----------------- | :----: | :---------------: | :--------------------------------------------------------------------------------------------------------------------------------- |
| `TZ`               | String | `"Europe/Berlin"` | Timezone inside the container (e.g. `Europe/Berlin`, `UTC`, `America/New_York`).                                                   |
| `CONFIGTYPE`       | String |   `"fhem.cfg"`    | Configuration source. Options: `fhem.cfg` (standard), `fhem.cfg.demo`, or `configDB` (database mode).                              |
| `RESTART`          | String |       `"1"`       | Automatic restart behavior on unexpected process crash. Set to `"0"` to disable.                                                   |
| `UMASK`            | String |     `"0037"`      | Process creation umask applied when FHEM starts.                                                                                   |
| `TELNETPORT`       | String |     `"7072"`      | Port where the internal FHEM Telnet listener binds.                                                                                |
| `TIMEOUT_STARTING` | String |      `"60"`       | Maximum time (in seconds) the container waits for FHEM to initialize before aborting.                                              |
| `TIMEOUT_STOPPING` | String |      `"30"`       | Grace period (in seconds) given to FHEM to save state and terminate cleanly on shutdown.                                           |
| `TIMEOUT_REAPPEAR` | String |      `"15"`       | Timeout (in seconds) for a terminated FHEM process to reappear before flagging failure.                                            |
| `FHEM_UID`         | String |     `"6061"`      | UID assigned to the internal `fhem` user.                                                                                          |
| `FHEM_GID`         | String |     `"6061"`      | GID assigned to the internal `fhem` group.                                                                                         |
| `FHEM_PERM_DIR`    | String |     `"0750"`      | Octal directory permission mask enforced recursively under `/opt/fhem`.                                                            |
| `FHEM_PERM_FILE`   | String |     `"0640"`      | Octal file permission mask enforced recursively under `/opt/fhem`.                                                                 |
| `BLUETOOTH_GID`    | String |     `"6001"`      | Group ID for accessing Bluetooth hardware devices.                                                                                 |
| `GPIO_GID`         | String |     `"6002"`      | Group ID for accessing hardware GPIO pins (e.g. Raspberry Pi).                                                                     |
| `I2C_GID`          | String |     `"6003"`      | Group ID for accessing I2C hardware buses.                                                                                         |
| `DOCKER_HOST`      | String |       `""`        | IPv4 address override for `host.docker.internal` (auto-detected if empty).                                                         |
| `DOCKER_GW`        | String |       `""`        | IPv4 gateway override for `gateway.docker.internal` (auto-detected if empty).                                                      |
| `APT_PKGS`         | String |       `""`        | Space-separated list of Debian `.deb` packages to install at startup (e.g., `libnet-snmp-perl usbutils`).                          |
| `CPAN_PKGS`        | String |       `""`        | Space-separated list of CPAN Perl modules to install at startup (e.g., `Net::MQTT::Simple`).                                       |
| `PIP_PKGS`         | String |       `""`        | Space-separated list of Python packages to install at startup.                                                                     |
| `NPM_PKGS`         | String |       `""`        | Space-separated list of Node.js NPM packages to install at startup.                                                                |
| `PERL_*`           | String |      *none*       | Any environment variable prefixed with `PERL_` is automatically forwarded to `fhem.pl` (e.g. `PERL_LWP_SSL_VERIFY_HOSTNAME: "0"`). |
| `PYTHON_*`         | String |      *none*       | Any environment variable prefixed with `PYTHON_` is forwarded to the Python sub-environment.                                       |
| `NODE_*`           | String |      *none*       | Any environment variable prefixed with `NODE_` is forwarded to the Node.js sub-environment.                                        |

---

## Chart Configuration Values

Below is the complete reference of parameters configurable in `values.yaml`:

### Controller & Core Settings

| Parameter       | Description                                                        | Default    |
| :-------------- | :----------------------------------------------------------------- | :--------- |
| `replicaCount`  | Number of pods. Must remain `1` to avoid FHEM state corruption.    | `1`        |
| `strategy.type` | Deployment replacement strategy. `Recreate` avoids volume locking. | `Recreate` |

### Image Parameters

| Parameter          | Description                                                                          | Default                            |
| :----------------- | :----------------------------------------------------------------------------------- | :--------------------------------- |
| `image.repository` | Image repository (`ghcr.io/fhem/fhem-minimal-docker` or `ghcr.io/fhem/fhem-docker`). | `ghcr.io/fhem/fhem-minimal-docker` |
| `image.tag`        | Image tag (defaults to `Chart.appVersion`).                                          | `"5.4.0-bookworm"`                 |
| `image.pullPolicy` | Image pull policy.                                                                   | `IfNotPresent`                     |
| `imagePullSecrets` | Secrets for private registry access.                                                 | `[]`                               |

### Metadata & Service Account

| Parameter                                     | Description                         | Default |
| :-------------------------------------------- | :---------------------------------- | :------ |
| `nameOverride`                                | Override chart name.                | `""`    |
| `fullnameOverride`                            | Override fully qualified app name.  | `""`    |
| `serviceAccount.create`                       | Whether to create a ServiceAccount. | `true`  |
| `serviceAccount.name`                         | Name of the ServiceAccount to use.  | `""`    |
| `serviceAccount.annotations`                  | Annotations for the ServiceAccount. | `{}`    |
| `serviceAccount.automountServiceAccountToken` | Mount API token into pod.           | `true`  |

### Networking & Security

| Parameter            | Description                                                      | Default |
| :------------------- | :--------------------------------------------------------------- | :------ |
| `hostNetwork`        | Run pod on the host network (required for mDNS/SSDP/broadcasts). | `false` |
| `dnsPolicy`          | DNS policy (`ClusterFirstWithHostNet` when `hostNetwork: true`). | `""`    |
| `podSecurityContext` | Pod-level security context (e.g. `fsGroup: 6061`).               | `{}`    |
| `securityContext`    | Container security context (e.g. `privileged: true` for USB).    | `{}`    |
| `podAnnotations`     | Custom annotations for the pod template.                         | `{}`    |
| `podLabels`          | Custom labels for the pod template.                              | `{}`    |

### Environment Variables & Secrets

| Parameter                    | Description                                                                                         | Default                 |
| :--------------------------- | :-------------------------------------------------------------------------------------------------- | :---------------------- |
| `env`                        | Map of key-value pairs written to ConfigMap and injected via `envFrom`.                             | *(See env table above)* |
| `configMapAnnotations`       | Annotations for the generated ConfigMap.                                                            | `{}`                    |
| `configDB.enabled`           | Enable database-driven configuration (`configDB`). Automatically sets `env.CONFIGTYPE: "configDB"`. | `false`                 |
| `configDB.connection`        | Database connection string in Perl DBI syntax (e.g. `mysql:database=fhem;host=db;port=3306`).       | `""`                    |
| `configDB.user`              | Database username for `configDB`.                                                                   | `""`                    |
| `configDB.password`          | Database password for `configDB`.                                                                   | `""`                    |
| `configDB.mountPath`         | Target container mount path for `configDB.conf` (defaults to `/opt/fhem/configDB.conf`).            | `""`                    |
| `configDB.defaultMode`       | Permission mask for the mounted Secret file (e.g. `0440`).                                          | `nil`                   |
| `configDB.existingSecret`    | Name of an existing Secret containing `configDB.conf` to mount instead of generating one.           | `""`                    |
| `configDB.secretAnnotations` | Annotations for the generated `configDB` Secret.                                                    | `{}`                    |
| `extraEnv`                   | Additional direct environment variables (e.g., from `secretKeyRef`).                                | `[]`                    |
| `extraEnvFrom`               | Additional existing ConfigMaps or Secrets to inject via `envFrom`.                                  | `[]`                    |

### Networking & Exposure (Service & Ingress)

| Parameter                  | Description                                                        | Default        |
| :------------------------- | :----------------------------------------------------------------- | :------------- |
| `service.type`             | Kubernetes service type (`ClusterIP`, `NodePort`, `LoadBalancer`). | `ClusterIP`    |
| `service.port`             | FHEMWEB HTTP port.                                                 | `8083`         |
| `service.telnetEnabled`    | Expose FHEM Telnet port on the Service and Container.              | `false`        |
| `service.telnetPort`       | FHEM Telnet port.                                                  | `7072`         |
| `service.nodePorts.http`   | Explicit NodePort for HTTP when type is `NodePort`.                | `""`           |
| `service.nodePorts.telnet` | Explicit NodePort for Telnet when type is `NodePort`.              | `""`           |
| `service.annotations`      | Annotations for the Service.                                       | `{}`           |
| `service.extraPorts`       | List of additional ports to expose on the Service.                 | `[]`           |
| `ingress.enabled`          | Enable Ingress resource.                                           | `false`        |
| `ingress.className`        | Ingress class name (e.g. `nginx`, `traefik`).                      | `""`           |
| `ingress.annotations`      | Ingress annotations (e.g. TLS issuers, timeouts).                  | `{}`           |
| `ingress.hosts`            | Ingress host rules and paths.                                      | `[fhem.local]` |
| `ingress.tls`              | TLS secrets configuration.                                         | `[]`           |

### Gateway API (HTTPRoute, TCPRoute, UDPRoute & Gateway)

> **Note**: Requires **Gateway API v1.6+** (experimental channel CRDs when using `TCPRoute`/`UDPRoute`). Ensure that your deployed Gateway controller explicitly supports `TCPRoute` and `UDPRoute` resources.

| Parameter                  | Description                                                                                     | Default     |
| :------------------------- | :---------------------------------------------------------------------------------------------- | :---------- |
| `httpRoute.enabled`        | Enable Kubernetes Gateway API `HTTPRoute` resource.                                             | `false`     |
| `httpRoute.annotations`    | Annotations to attach to the `HTTPRoute`.                                                       | `{}`        |
| `httpRoute.hostnames`      | List of hostnames matched by the route (e.g. `["fhem.example.com"]`).                           | `[]`        |
| `httpRoute.parentRefs`     | Parent Gateways to attach to. Defaults to chart Gateway if `gateway.enabled`.                   | `[]`        |
| `httpRoute.rules`          | Custom routing rules list. Defaults to path `/` routing to FHEM web service.                    | `[]`        |
| `tcpRoute.enabled`         | Enable Gateway API `TCPRoute` resource (**requires `httpRoute.enabled: true`**).                | `false`     |
| `tcpRoute.apiVersion`      | API version override for TCPRoute (default: `gateway.networking.k8s.io/v1alpha2`).              | `""`        |
| `tcpRoute.annotations`     | Annotations to attach to the `TCPRoute`.                                                        | `{}`        |
| `tcpRoute.parentRefs`      | Parent Gateways for TCPRoute. Defaults to `httpRoute.parentRefs` or chart Gateway.              | `[]`        |
| `tcpRoute.sectionName`     | Listener section name on Gateway (default: `telnet`).                                           | `"telnet"`  |
| `tcpRoute.port`            | Target TCP service port (defaults to `service.telnetPort`: 7072).                               | `7072`      |
| `tcpRoute.rules`           | Custom routing rules list for TCPRoute.                                                         | `[]`        |
| `udpRoute.enabled`         | Enable Gateway API `UDPRoute` resource (**requires `httpRoute.enabled: true`**).                | `false`     |
| `udpRoute.apiVersion`      | API version override for UDPRoute (default: `gateway.networking.k8s.io/v1alpha2`).              | `""`        |
| `udpRoute.annotations`     | Annotations to attach to the `UDPRoute`.                                                        | `{}`        |
| `udpRoute.parentRefs`      | Parent Gateways for UDPRoute. Defaults to `httpRoute.parentRefs` or chart Gateway.              | `[]`        |
| `udpRoute.sectionName`     | Listener section name on Gateway (default: `udp`).                                              | `"udp"`     |
| `udpRoute.port`            | Target UDP service port (default: 3671, e.g. for KNX/IP).                                       | `3671`      |
| `udpRoute.rules`           | Custom routing rules list for UDPRoute.                                                         | `[]`        |
| `gateway.enabled`          | Whether to create a managed `Gateway` object alongside the routes.                              | `false`     |
| `gateway.annotations`      | Annotations to attach to the `Gateway`.                                                         | `{}`        |
| `gateway.gatewayClassName` | GatewayClass name (`cilium`, `envoy-gateway`, `istio`, `nginx`). Required if `gateway.enabled`. | `""`        |
| `gateway.listeners`        | List of listener definitions for the Gateway.                                                   | `[HTTP:80]` |
| `gateway.addresses`        | Specific IP/hostname addresses requested for the Gateway.                                       | `[]`        |

### Network Policy

| Parameter                   | Description                                                                             | Default             |
| :-------------------------- | :-------------------------------------------------------------------------------------- | :------------------ |
| `networkPolicy.annotations` | Annotations to attach to the NetworkPolicy.                                             | `{}`                |
| `networkPolicy.policyTypes` | List of policy types to enforce (`Ingress`, `Egress`).                                  | `[Ingress, Egress]` |
| `networkPolicy.ingress`     | Ingress rules for incoming traffic (by default allows all incoming traffic via `[{}]`). | `[{}]`              |
| `networkPolicy.egress`      | Egress rules for outgoing traffic (by default allows all outgoing traffic via `[{}]`).  | `[{}]`              |

### Pod Disruption Budget

| Parameter                                        | Description                                                                                                 | Default |
| :----------------------------------------------- | :---------------------------------------------------------------------------------------------------------- | :------ |
| `podDisruptionBudget.enabled`                    | Enable PodDisruptionBudget resource.                                                                        | `false` |
| `podDisruptionBudget.annotations`                | Annotations to attach to the PodDisruptionBudget.                                                           | `{}`    |
| `podDisruptionBudget.minAvailable`               | Minimum number or percentage of pods that must remain available (mutually exclusive with `maxUnavailable`). | `""`    |
| `podDisruptionBudget.maxUnavailable`             | Maximum number or percentage of pods that can be unavailable (mutually exclusive with `minAvailable`).      | `""`    |
| `podDisruptionBudget.unhealthyPodEvictionPolicy` | Unhealthy pod eviction policy for Kubernetes 1.27+ (`IfHealthyBudget` or `AlwaysAllow`).                    | `""`    |

### Resources & Probes

| Parameter                   | Description                                                 | Default                             |
| :-------------------------- | :---------------------------------------------------------- | :---------------------------------- |
| `resources.limits.cpu`      | Container CPU limit.                                        | `300m`                              |
| `resources.limits.memory`   | Container Memory limit.                                     | `256Mi`                             |
| `resources.requests.cpu`    | Container CPU request.                                      | `100m`                              |
| `resources.requests.memory` | Container Memory request.                                   | `128Mi`                             |
| `startupProbe`              | Probe allowing startup grace period before liveness checks. | Enabled (`exec` `/health-check.sh`) |
| `livenessProbe`             | Periodic check confirming FHEM process is healthy.          | Enabled (`exec` `/health-check.sh`) |
| `readinessProbe`            | Periodic check confirming FHEM is ready for traffic.        | Enabled (`exec` `/health-check.sh`) |

> **Note**: When using the default probes (`exec` `/health-check.sh`), a `define DockerImageInfo DockerImageInfo` device **must** be configured in FHEM so that `/tmp/health-check.urls` is generated upon startup (this device is only added automatically on a brand-new `fhem.cfg` installation, not when migrating an existing configuration or using `configDB`). Alternatively, an `httpGet` approach can be configured for all three probes (see [Troubleshooting & FAQs](#pod-remains-in-01-status-or-health-checksh-reports-cannot-read-url-file-tmphealth-checkurls)).

### Persistence & Hardware Storage

| Parameter                   | Description                                                            | Default                               |
| :-------------------------- | :--------------------------------------------------------------------- | :------------------------------------ |
| `persistence.enabled`       | Enable PersistentVolumeClaim for `/opt/fhem`.                          | `true`                                |
| `persistence.storageClass`  | StorageClass name (`""` uses cluster default, `"-"` disables dynamic). | `""`                                  |
| `persistence.accessMode`    | Access mode for PVC (`ReadWriteOnce`).                                 | `ReadWriteOnce`                       |
| `persistence.size`          | PVC disk size.                                                         | `10Gi`                                |
| `persistence.existingClaim` | Name of an existing PVC to use instead of creating one.                | `""`                                  |
| `persistence.mountPath`     | Target mount point inside the container.                               | `/opt/fhem`                           |
| `persistence.subPath`       | Subpath inside the volume to mount.                                    | `""`                                  |
| `persistence.annotations`   | Custom annotations for the PVC.                                        | `{"helm.sh/resource-policy": "keep"}` |
| `extraVolumes`              | Additional volumes to mount into the pod (e.g. host USB devices).      | `[]`                                  |
| `extraVolumeMounts`         | Mounts for `extraVolumes`.                                             | `[]`                                  |

### Scheduling & Extensibility

| Parameter         | Description                                                         | Default |
| :---------------- | :------------------------------------------------------------------ | :------ |
| `nodeSelector`    | Node labels for pod assignment (e.g. pinning to physical USB host). | `{}`    |
| `tolerations`     | Tolerations for node taints.                                        | `[]`    |
| `affinity`        | Pod/node affinity and anti-affinity rules.                          | `{}`    |
| `initContainers`  | List of initContainers to run before FHEM.                          | `[]`    |
| `extraContainers` | List of sidecar containers (e.g. `alexa-fhem`).                     | `[]`    |

---

## Advanced Guides & Recipes

### 1. USB Hardware Dongle Pass-Through (Zigbee, CUL, Z-Wave, EnOcean)

Many FHEM installations rely on physical USB transceivers (such as ConBee II, nanoCUL, CC1101, or Aeotec Z-Stick). To pass through hardware dongles in Kubernetes:

1. Pin the pod to the node where the physical dongle is plugged in using `nodeSelector`.
2. Mount the device node using `extraVolumes` and `extraVolumeMounts` using the stable `/dev/serial/by-id/*` path.
3. Grant permissions via `securityContext.privileged: true` or container capabilities.

Example `values.yaml` snippet:

```yaml
nodeSelector:
  kubernetes.io/hostname: "smart-home-node-01"

securityContext:
  privileged: true

extraVolumes:
  - name: zigbee-dongle
    hostPath:
      path: /dev/serial/by-id/usb-dresden_elektronik_ingenieurtechnik_GmbH_ConBee_II_DE2123456-if00
  - name: cul-dongle
    hostPath:
      path: /dev/serial/by-id/usb-FTDI_FT232R_USB_UART_A1012345-if00-port0

extraVolumeMounts:
  - name: zigbee-dongle
    mountPath: /dev/ttyACM0
  - name: cul-dongle
    mountPath: /dev/ttyUSB0
```

### 2. Host Networking for Local Discovery (mDNS, SSDP, Sonos, Cast)

Certain FHEM modules (such as `SONOS`, `Cast`, `HUEBridge`, or `FritzBox`) require broadcast and multicast packets to discover devices across your local network:

```yaml
hostNetwork: true
dnsPolicy: ClusterFirstWithHostNet
```

> **Note**: When `hostNetwork: true` is configured, FHEM binds directly to host interfaces on port 8083 and 7072.

### 3. Database Configuration (`configDB` & Secrets)

FHEM can run in database configuration mode using `configDB`. When `configDB.enabled: true` or `env.CONFIGTYPE: "configDB"` is set, the Helm chart automatically generates a Kubernetes Secret containing `configDB.conf` and mounts it read-only into `/opt/fhem/configDB.conf`:

```yaml
configDB:
  enabled: true
  connection: "mysql:database=fhem;host=mariadb-service;port=3306"
  user: "fhemuser"
  password: "MyDatabasePassword"
```

The generated Secret stores the Perl database hash:
```perl
%dbconfig= (
  connection => 'mysql:database=fhem;host=mariadb-service;port=3306',
  user => 'fhemuser',
  password => 'MyDatabasePassword'
);
```

#### Using an Existing Secret

If you manage your secrets externally (e.g. via SealedSecrets, External Secrets Operator, or Vault), specify `configDB.existingSecret`:

```yaml
configDB:
  enabled: true
  existingSecret: "my-precreated-fhem-configdb-secret"
```

The Secret must contain a key named `configDB.conf`.

#### Injecting Additional Database Credentials (e.g. for DbLog)

If using SQL logging with `DbLog` or custom Perl modules, you can inject additional database passwords from external Secrets via `extraEnv`:

```bash
kubectl create secret generic fhem-db-credentials \
  --from-literal=DB_PASSWORD="SuperSecretPassword"
```

In your `values.yaml`:

```yaml
extraEnv:
  - name: DB_PASSWORD
    valueFrom:
      secretKeyRef:
        name: fhem-db-credentials
        key: DB_PASSWORD
```

### 4. Custom Pre-Start and Pre-Init Scripts

The `fhem-docker` container natively supports hook scripts executed at various stages:
- `/pre-init.sh` or `/docker/pre-init.sh` (executed before package installations)
- `/post-init.sh` or `/docker/post-init.sh` (executed after initialization)
- `/pre-start.sh` or `/docker/pre-start.sh` (executed immediately before FHEM starts)
- `/post-start.sh` or `/docker/post-start.sh` (executed after FHEM starts)

Mount your custom script from a ConfigMap using `extraVolumes`:

```yaml
extraVolumes:
  - name: pre-start-hook
    configMap:
      name: fhem-custom-hooks
      defaultMode: 0755

extraVolumeMounts:
  - name: pre-start-hook
    mountPath: /docker/pre-start.sh
    subPath: pre-start.sh
```

### 5. Sidecar Services (alexa-fhem, homebridge)

To run auxiliary services such as `alexa-fhem` in the same pod:

```yaml
extraContainers:
  - name: alexa-fhem
    image: ghcr.io/fhem/alexa-fhem:5.1.6
    imagePullPolicy: IfNotPresent
    ports:
      - name: alexa
        containerPort: 3000
    volumeMounts:
      - name: fhem-data
        mountPath: /root/.alexa
        subPath: alexa-fhem
```

### 6. Gateway API (HTTPRoute & Gateway) Deployment

The Kubernetes Gateway API provides cleaner role separation and more expressive routing than Ingress.

> **Requirements**: A minimum of **Gateway API v1.6+** is expected. Additionally, if you use Layer 4 routes (`TCPRoute` and `UDPRoute`), the deployed Gateway controller (e.g. Cilium, Envoy Gateway, Istio, NGINX Gateway Fabric) must explicitly support `TCPRoute` and `UDPRoute` (including the experimental channel CRDs).

#### Option A: Attaching HTTPRoute to an Existing Cluster Gateway
If your cluster already has a shared Gateway managed by platform administrators (e.g. Envoy Gateway, Cilium, Istio, Traefik):

```yaml
ingress:
  enabled: false

httpRoute:
  enabled: true
  hostnames:
    - "fhem.home.arpa"
  parentRefs:
    - name: shared-gateway
      namespace: gateway-system
      sectionName: http
```

#### Option B: Creating a Dedicated Gateway with HTTPRoute
If you wish this chart to manage both the `Gateway` and the `HTTPRoute` resources together:

```yaml
ingress:
  enabled: false

httpRoute:
  enabled: true
  hostnames:
    - "fhem.home.arpa"

gateway:
  enabled: true
  gatewayClassName: "cilium" # or "envoy-gateway", "istio", "nginx"
  listeners:
    - name: http
      port: 80
      protocol: HTTP
      allowedRoutes:
        namespaces:
          from: Same
```

When `gateway.enabled: true` and `httpRoute.parentRefs` is omitted, the `HTTPRoute` automatically binds to the newly created `Gateway`.

#### Option C: Enabling Layer 4 Routes (`TCPRoute` and `UDPRoute`)
> **Important Constraint**: By design, `TCPRoute` and `UDPRoute` can **only be enabled if `httpRoute.enabled: true`** is also set. Furthermore, Gateway API **v1.6+** is required and the used Gateway controller must support `TCPRoute` and `UDPRoute`.

To expose the FHEM Telnet command interface via a `TCPRoute` (port 7072) and a UDP home automation service (e.g., KNX/IP on port 3671) via `UDPRoute`:

```yaml
ingress:
  enabled: false

httpRoute:
  enabled: true
  hostnames:
    - "fhem.home.arpa"

tcpRoute:
  enabled: true
  port: 7072
  sectionName: "telnet"

udpRoute:
  enabled: true
  port: 3671
  sectionName: "udp"

gateway:
  enabled: true
  gatewayClassName: "cilium"
  listeners:
    - name: http
      port: 80
      protocol: HTTP
      allowedRoutes:
        namespaces:
          from: Same
    - name: telnet
      port: 7072
      protocol: TCP
      allowedRoutes:
        namespaces:
          from: Same
    - name: udp
      port: 3671
      protocol: UDP
      allowedRoutes:
        namespaces:
          from: Same
```

### 7. Network Policy Recipes

The chart always provisions a Kubernetes `NetworkPolicy` targeting FHEM pods. By default, it allows all incoming and outgoing connections (`ingress: [{}]`, `egress: [{}]`), ensuring that out-of-the-box local network discovery, MQTT brokers, databases, and ingress controllers function without disruption.

In production clusters enforcing strict zero-trust network isolation, you can customize the ingress and egress rules in `values.yaml`.

#### Restricting Ingress Traffic

To lock down access so that only an Ingress controller (e.g., in namespace `ingress-nginx`) can access the FHEMWEB interface (port 8083), while allowing administrative Telnet access (port 7072) only from a trusted management CIDR:

```yaml
networkPolicy:
  policyTypes:
    - Ingress
    - Egress
  ingress:
    # Allow FHEMWEB traffic only from the ingress controller namespace
    - from:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: ingress-nginx
      ports:
        - protocol: TCP
          port: 8083
    # Allow Telnet CLI management only from a trusted management subnet
    - from:
        - ipBlock:
            cidr: 192.168.1.0/24
      ports:
        - protocol: TCP
          port: 7072
  # Keep egress open or restrict as shown below
  egress:
    - {}
```

#### Restricting Egress Traffic (DNS, Database & Smart Home LAN)

If you enforce egress isolation, FHEM typically requires egress access for cluster DNS resolution, the internal database (e.g. MariaDB or PostgreSQL for `configDB` / `DbLog`), an MQTT broker, and local LAN devices:

```yaml
networkPolicy:
  policyTypes:
    - Ingress
    - Egress
  egress:
    # 1. Allow cluster DNS lookups (CoreDNS in kube-system)
    - to:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: kube-system
          podSelector:
            matchLabels:
              k8s-app: kube-dns
      ports:
        - protocol: UDP
          port: 53
        - protocol: TCP
          port: 53

    # 2. Allow connection to MySQL/MariaDB database in the database namespace
    - to:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: database
      ports:
        - protocol: TCP
          port: 3306

    # 3. Allow outbound connections to local smart home hardware and MQTT broker
    - to:
        - ipBlock:
            cidr: 192.168.1.0/24
      ports:
        - protocol: TCP
          port: 1883    # MQTT broker
        - protocol: TCP
          port: 80      # Tasmota / Shelly HTTP web hooks
        - protocol: TCP
          port: 443     # External HTTPS APIs (weather, push notifications)
```

### 8. Pod Disruption Budget (PDB) Configurations

FHEM operates as a single-master home automation server (`replicaCount: 1`) bound to persistent storage and state files. Enabling a `PodDisruptionBudget` helps manage how voluntary disruptions (such as `kubectl drain`, node maintenance, or cluster autoscaler scale-downs) affect FHEM.

#### Preventing Disruptions During Node Drains (Zero-Downtime Guard)

To prevent automated node evictions from terminating FHEM during node maintenance, enable the PDB with `minAvailable: 1` (or `maxUnavailable: 0`). Any `kubectl drain` operation on the node hosting FHEM will be blocked until the eviction is manually forced (`kubectl drain --disable-eviction=true` / `--force`):

```yaml
podDisruptionBudget:
  enabled: true
  minAvailable: 1
```

> **Note**: Because FHEM has only 1 replica, `minAvailable: 1` ensures the pod cannot be voluntarily evicted by the eviction API. Use this in mission-critical environments where home automation downtime must be scheduled intentionally.

#### Allowing Automated Node Upgrades

In managed Kubernetes clusters (such as k3s, GKE, or EKS) with automated rolling node upgrades, blocking node drains might cause node upgrades to time out. To allow the node drain process to proceed and evict FHEM (triggering a recreate on another node):

```yaml
podDisruptionBudget:
  enabled: true
  maxUnavailable: 1
  # For Kubernetes 1.27+, allow eviction immediately if pod is unhealthy:
  unhealthyPodEvictionPolicy: AlwaysAllow
```

---

## Persistence, Backups & Recovery

- **What is stored in `/opt/fhem`?**
  - `fhem.cfg`: Your device definitions and attributes
  - `fhem.save`: Current device state variables (readings, timestamps)
  - `log/`: Event logs, temperature logs, and debug dumps
  - `FHEM/`: Standard and custom third-party Perl modules (e.g. `99_myUtils.pm`)
  - `www/`: Custom images, SVG floor plans, and web assets

- **Backups**:
  You can execute FHEM's native backup command via Telnet or the web command bar:
  ```text
  backup
  ```
  The resulting tarball will be saved in `/opt/fhem/backup/`. Alternatively, utilize volume snapshot tools such as [Velero](https://velero.io/) or CSI VolumeSnapshots pointing to your PVC.

---

## Troubleshooting & FAQs

### Pod remains in `0/1` status or `/health-check.sh` reports `Cannot read url file /tmp/health-check.urls`
By default, `startupProbe`, `livenessProbe`, and `readinessProbe` execute the container's built-in `/health-check.sh` script. This script reads target FHEMWEB URLs from `/tmp/health-check.urls`, which is generated by the FHEM module `99_DockerImageInfo.pm` once FHEM finishes initializing.

If you migrated an existing `fhem.cfg` or use `configDB`, this device may not exist in your FHEM configuration. You can resolve this in two ways:

1. **Define the `DockerImageInfo` device in FHEM** (and save your configuration):
   ```text
   define DockerImageInfo DockerImageInfo
   save
   ```
2. **Switch the probes to `httpGet`** in your custom `values.yaml` (setting `exec: null` removes the default `exec` handler when Helm merges values):
   ```yaml
   startupProbe:
     enabled: true
     exec: null
     httpGet:
       path: /fhem
       port: http
     initialDelaySeconds: 10
     periodSeconds: 5
     timeoutSeconds: 5
     failureThreshold: 30

   livenessProbe:
     enabled: true
     exec: null
     httpGet:
       path: /fhem
       port: http
     initialDelaySeconds: 30
     periodSeconds: 15
     timeoutSeconds: 5
     failureThreshold: 3

   readinessProbe:
     enabled: true
     exec: null
     httpGet:
       path: /fhem
       port: http
     initialDelaySeconds: 15
     periodSeconds: 10
     timeoutSeconds: 5
     failureThreshold: 2
   ```

### Pod gets killed during startup
FHEM can take longer to boot if it initializes multiple serial dongles or network bridges. Check the `startupProbe` configuration in `values.yaml` and increase `failureThreshold` or `TIMEOUT_STARTING`:
```yaml
env:
  TIMEOUT_STARTING: "120"

startupProbe:
  failureThreshold: 40
  periodSeconds: 5
```

### Permission Denied inside `/opt/fhem`
The container automatically fixes directory ownership on startup using `FHEM_UID` and `FHEM_GID`. Ensure that neither `podSecurityContext.runAsNonRoot: true` nor `podSecurityContext.runAsUser` is set to a non-zero value, because `entry.sh` must start with sufficient privileges to run `chown` on the mounted volume.

### Viewing Realtime Logs
FHEM redirects its daily log file to container stdout in real time:
```bash
kubectl logs -f deployment/my-fhem-fhem
```

### Connecting to the Telnet CLI
Run:
```bash
kubectl port-forward svc/my-fhem-fhem 7072:7072
nc 127.0.0.1 7072
```
Now type any FHEM command (e.g. `list`, `version`, `save`).

---

## License

This Helm chart is licensed under the Apache 2.0 License. FHEM is licensed under the GPL-2.0 License.

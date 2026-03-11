# AKS-DEV

A dev/lab environment demonstrating a private Azure Kubernetes Service (AKS) cluster with Workload Identity and Key Vault secret injection, automated via Azure DevOps pipelines.

## Overview

This project provisions a fully private AKS cluster and supporting infrastructure using Terraform, then deploys a test application to validate that pods can securely access Azure Key Vault secrets using Workload Identity and the CSI Secrets Store driver — without any credentials baked into the workload.

## Architecture

```text
Azure DevOps (pipelines)
    │
    ▼
Windows Jump Server (self-hosted ADO agent, accessed via Azure Bastion)
    │
    ▼
Private AKS Cluster ──► Azure Container Registry
    │
    ▼ (CSI Secrets Store + Workload Identity)
Azure Key Vault (private endpoint)
```

### Networking

- **VNet** `10.52.0.0/16` in Germany West Central
  - `test-sn` (`10.52.0.0/24`) — general subnet (jump server, KV private endpoint)
  - `aks-sn` (`10.52.1.0/24`) — AKS node subnet
  - `AzureBastionSubnet` (`10.52.2.0/24`) — Azure Bastion
- Private DNS zones for AKS (`privatelink.germanywestcentral.azmk8s.io`) and Key Vault (`privatelink.vaultcore.azure.net`)

## Infrastructure (Terraform)

| Resource | Details |
| --- | --- |
| AKS Cluster | Private, Azure CNI, Network Policy, OIDC issuer, Workload Identity |
| Azure Container Registry | Premium SKU, AKS kubelet identity has `AcrPull` |
| Azure Key Vault | Premium SKU, RBAC auth, private endpoint, example secret pre-created |
| Jump Server VM | Windows Server 2022, auto-registered as Azure DevOps self-hosted agent |
| Azure Bastion | For secure RDP access to the jump server |

### Key AKS features enabled

- **Workload Identity** — OIDC issuer + federated identity credentials link Entra ID managed identities to Kubernetes service accounts, letting pods authenticate to Azure without secrets.
- **Key Vault Secrets Provider (CSI driver)** — Secrets are mounted into pods as files via a `SecretProviderClass`.
- **Azure AD RBAC** — Cluster access is controlled via Entra ID group membership.
- **Private cluster** — API server is not publicly accessible; access goes through the jump server.

### Terraform state

Stored remotely in Azure Blob Storage (`companystorage` / `companycontainer` / `companydev.terraform.tfstate`).

## Pipelines (Azure DevOps)

| File | Trigger | Purpose |
| --- | --- | --- |
| `azure-pipelines.yaml` | Manual | Terraform apply + import nginx into ACR + restart jump server |
| `azure-pipelines-with-graph.yaml` | Manual | Same as above, also generates and publishes a Terraform dependency graph (PNG) |
| `DeployTestApp.yaml` | Manual | Deploy test app via Helm, then verify the KV secret is readable from inside the pod |
| `TestAppFailureMode.yaml` | Manual | Same as above but uses a wrong secret name — demonstrates failure behaviour |
| `destory.yaml` | Nightly (18:00 UTC) | Terraform destroy + remove offline Azure DevOps agents (cost control) |
| `DeleteAgent.yaml` | Manual | Remove offline Azure DevOps agents from the pool |

## Prerequisites

- Azure subscription with a pre-existing resource group (`company`)
- Azure DevOps organisation with a service connection (`OS_fra_connection`)
- Storage account for Terraform remote state
- Terraform >= 1.3

## Getting Started

1. **Provision infrastructure** — run the `azure-pipelines.yaml` pipeline (or `terraform apply` locally).
2. **Access the cluster** — connect to the jump server via Azure Bastion, then use `az aks get-credentials` and `kubelogin`.
3. **Deploy the test app** — run `DeployTestApp.yaml` to deploy via Helm and confirm the Key Vault secret is mounted successfully.
4. **Tear down** — run `destory.yaml` manually or let the nightly schedule handle it.

## Security Notes

> **This is a lab environment.** Several settings are intentionally relaxed for ease of use and should not be replicated in production.

- Jump server credentials are hardcoded (`Password1234!`)
- Azure DevOps PATs appear in plaintext in pipeline YAML — use secret variables instead
- Key Vault allows public network access
- Terraform state access key is stored in `providers.tf` — use a service principal or managed identity instead

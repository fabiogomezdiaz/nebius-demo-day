# Operators

NVIDIA GPU Operator, Kubeflow Training Operator, Flux, and Soperator are Helm/kubectl in **`terraform/platform`**, not ArgoCD Applications. Network Operator is not installed (no InfiniBand).

Flux is required by Soperator (HelmReleases). ArgoCD is the GitOps UI for demo-day apps. Do not delete Flux.

Do not install the same charts from the Nebius console as well — that dual-installs them.

`driver.enabled=false` because this lab uses MK8s driverfull images.

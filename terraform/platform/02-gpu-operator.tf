# NVIDIA GPU Operator — MK8s nodes already have CUDA drivers, so driver=false.

resource "helm_release" "gpu_operator" {
  depends_on = [terraform_data.platform_k8s_wipe]

  name             = "gpu-operator"
  namespace        = "nvidia-gpu-operator"
  create_namespace = true
  repository       = "oci://cr.eu-north1.nebius.cloud/marketplace/nebius/nvidia-gpu-operator/chart"
  chart            = "gpu-operator"
  version          = "v25.10.0"
  wait             = true
  timeout          = 900

  set {
    name  = "driver.enabled"
    value = "false"
  }

  set {
    name  = "dcgmExporter.enabled"
    value = "true"
  }
}

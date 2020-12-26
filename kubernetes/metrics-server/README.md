# metrics-server

The manifests in this directory mirror the manifests from the project https://github.com/kubernetes-sigs/metrics-server. Only selected versions are mirrored.

We add the `--kubelet-insecure-tls` flag to the deployment, to allow the metrics server to work correctly in kubeadm-created clusters. WARNING: This is insecure, and should not be done in production clusters. We do it because we use these manifests only for training.

The raw form of these files will be available by tiny.cc shortened URLS, as follows:

|Manifest|URL|
|---|---|
|metricsserver-0.3.6.yaml|http://tiny.cc/rw-metrics-server-1|
|metricsserver-0.4.1.yaml|http://tiny.cc/rw-metrics-server-2|

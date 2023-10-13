# EKS-Crossplane-ArgoCD

    # ISTIO-INGRESS
    # ISTIOD
    # ISTIO-BASE
    # PROMETHEUS, KIALI, GRAFANA, JAEGER, KUBE STATE METRICS
    # ALB INGRESS CONTROLLER
    # METRICS SERVER
    # EKS ADDONS
    # KARPENTER
    # CROSSPLANE WITH AWS PROVIDERS
    # ARGOCD

        # Adicionar ao ConfigMap (argocd-cmd-params-cm)
        
          kubectl edit cm argocd-cmd-params-cm -n argocd
        
            data:
              server.insecure: 'true'

        # Adicionar ao ConfigMap (argocd-cm)
        
          kubectl edit cm argocd-cm -n argocd

            data:
              application.resourceTrackingMethod: annotation

        # Recuperar password ArgoCD

          kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo
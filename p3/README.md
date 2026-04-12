sudo kubectl port-forward svc/argocd-server -n argocd --address 0.0.0.0 8080:443

kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo
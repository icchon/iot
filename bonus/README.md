kubectl get secret gitlab-gitlab-initial-root-password -n gitlab -o jsonpath="{.data.password}" | base64 --decode; echo

helm upgrade --install gitlab gitlab/gitlab -n gitlab -f values.yaml

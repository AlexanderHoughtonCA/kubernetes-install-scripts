
kubectl delete -A ValidatingWebhookConfiguration ingress-nginx-admission
kubectl delete -f ./metallb/deploy-ingress-nginx-controller.yaml

kubectl delete -f https://raw.githubusercontent.com/metallb/metallb/v0.13.11/config/manifests/metallb-native.yaml

kubectl delete -f ./metallb/pool-config.yaml



	
kubectl get ns ingress-nginx >/dev/null 2>&1 || kubectl create ns ingress-nginx

kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.11/config/manifests/metallb-native.yaml

kubectl apply -f ./metallb/deploy-ingress-nginx-controller.yaml
kubectl get pods -n ingress-nginx
kubectl get service ingress-nginx-controller -n=ingress-nginx

kubectl delete -A ValidatingWebhookConfiguration ingress-nginx-admission

kubectl apply -f ./metallb/pool-config.yaml
kubectl delete pod -n ingress-nginx -l job-name=ingress-nginx-admission-create
kubectl delete pod -n ingress-nginx -l job-name=ingress-nginx-admission-patch



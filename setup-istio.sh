kubectl delete -f k8s/database
kubectl delete -f k8s/api/v1
kubectl delete -f k8s/api/v2
kubectl delete -f nginx

curl -L https://istio.io/downloadIstio | sh -
cd istio-1.22.0
export PATH=$PWD/bin:$PATH
istioctl x precheck

istioctl install --set profile=default -y
kubectl label namespace default istio-injection=enabled

kubectl apply -f k8s/database
kubectl apply -f k8s/api/v1
kubectl apply -f k8s/api/v2
kubectl apply -f nginx/controller-nginx.yaml
kubectl wait --namespace ingress-nginx --for=condition=ready pod --selector=app.kubernetes.io/component=controller --timeout=180s && kubectl apply -f ./nginx/ingress-nginx.yaml
kubectl port-forward --namespace=ingress-nginx service/ingress-nginx-controller 8080:80

kubectl apply -f k8s/kiali
istioctl dashboard kiali
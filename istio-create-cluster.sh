kind create cluster --config ./kind/cluster-config.yaml --name redes-cluster

istioctl install --set profile=default -y


cd api/v1 
docker build -t apiexpress:v1 .
cd ../v2
docker build -t apiexpress:v2 .

kind load docker-image apiexpress:v1 --name redes-cluster
kind load docker-image apiexpress:v2 --name redes-cluster

kubectl create namespace default
kubectl create namespace ingress-nginx

kubectl label ns default istio-injection=enabled
kubectl label ns ingress-nginx istio-injection=enabled


cd ../..
kubectl apply -f ./k8s/database/
kubectl apply -f ./k8s/api/v1
kubectl apply -f ./k8s/api/v2

kubectl apply -f k8s/kiali
kubectl apply --kustomize k8s/prometheus
kubectl apply --kustomize k8s/grafana

kubectl apply -f ./nginx/controller-nginx.yaml
# execute this apart
kubectl wait --namespace ingress-nginx --for=condition=ready pod --selector=app.kubernetes.io/component=controller --timeout=180s && kubectl apply -f ./nginx/ingress-nginx.yaml
kubectl port-forward --namespace=ingress-nginx service/ingress-nginx-controller 8080:80

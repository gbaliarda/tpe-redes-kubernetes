kind create cluster --config ./kind/cluster-config.yaml --name redes-cluster

cd api/v1 
docker build -t apiexpress:v1 .

kind load docker-image apiexpress:v1 --name redes-cluster

cd ../..
kubectl apply -f ./k8s/database/
kubectl apply -f ./k8s/api/v1
kubectl apply -f ./nginx/controller-nginx.yaml
kubectl wait --namespace ingress-nginx --for=condition=ready pod --selector=app.kubernetes.io/component=controller --timeout=180s && kubectl apply -f ./nginx/ingress-nginx.yaml
kubectl port-forward --namespace=ingress-nginx service/ingress-nginx-controller 8080:80

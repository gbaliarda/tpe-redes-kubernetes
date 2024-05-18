kind create cluster --config ./kind/cluster-config.yaml --name redes-cluster

cd api 
docker build -t apiexpress:latest .
docker tag apiexpress:latest kind.local/apiexpress:latest

kind load docker-image apiexpress:latest --name redes-cluster

cd ..
kubectl apply -f ./k8s/database/
kubectl apply -f ./k8s/api/
kubectl apply -f ./nginx/controller-nginx.yaml
kubectl wait --namespace ingress-nginx --for=condition=ready pod --selector=app.kubernetes.io/component=controller --timeout=180s && kubectl apply -f ./nginx/ingress-nginx.yaml
kubectl port-forward --namespace=ingress-nginx service/ingress-nginx-controller 8080:80

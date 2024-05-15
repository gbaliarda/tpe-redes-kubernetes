kind create cluster --config ./kind/cluster-config.yaml --name redes-cluster

cd api 
docker build -t apiexpress:latest .
docker tag apiexpress:latest kind.local/apiexpress:latest

kind load docker-image apiexpress:latest --name redes-cluster

cd ..
kubectl apply -f ./k8s/database/
kubectl apply -f ./k8s/api/
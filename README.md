## Setup database
In the folder /database run:
```bash
$> docker-compose up
```

## Create Kubernetes API Cluster
### 1. Create KinD cluster
```bash
$> kind create cluster --config ./kind/cluster-config.yaml --name redes-cluster
```
You can check your running clusters with:
```bash 
$> kind get clusters 
```
### 2. Build Docker Image
In the folder /api run:
```bash
$> docker build -t apiexpress:latest .
```
### 3. Tag your Docker Image so KinD can recognize it
In the folder /api run:
```bash
$> docker tag apiexpress:latest kind.local/apiexpress:latest
```
### 4. Load Docker Image to the Cluster
```bash
$> kind load docker-image apiexpress:latest --name redes-cluster
```
### 5. Add the Database Endpoint and Service configuration to your cluster
```bash
$> kubectl apply -f k8s/database/
```
### 6. Add the API Deployment and Service configuration to your cluster
```bash
$> kubectl apply -f k8s/api/
```
You can check your running pods with:
```bash 
$> kubectl get pods 
```
All pods should have STATUS="Running"
### 7. Test your cluster with cURL
```bash 
$> kubectl exec <pod-name> -- curl -s http://localhost:8080
```
Instead of ``http://localhost:8080`` you can also curl ``http://apiexpress-service:8080``

To delete your cluster you can run
```bash
$> kind delete cluster --name redes-cluster
```
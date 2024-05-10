## Create Kubernetes API Cluster
### 1. Create KinD cluster
```bash
$> kind create cluster --config cluster-config.yaml --name apiexpress-cluster
```
You can check your running clusters with:
```bash 
$> kind get clusters 
```
### 2. Add the Deployment and Service configuration to your cluster
```bash
$> kubectl apply -f apiexpress-deployment.yaml -f apiexpress-service.yaml
```
### 3. Build Docker Image
```bash
$> docker build -t apiexpress:latest .
```
### 4. Tag your Docker Image so KinD can recognize it
```bash
$> docker tag apiexpress:latest kind.local/apiexpress:latest
```
### 5. Load Docker Image to the Cluster
```bash
$> kind load docker-image apiexpress:latest --name apiexpress-cluster
```
You can check your running pods with:
```bash 
$> kubectl get pods 
```
All pods should have STATUS="Running"
### 6. Test your cluster with cURL
```bash 
$> kubectl exec <pod-name> -- curl -s http://localhost:8080
```
Instead of ``http://localhost:8080`` you can also curl ``http://apiexpress-service:8080``

To delete your cluster you can run
```bash
$> kind delete cluster --name apiexpress-cluster
```
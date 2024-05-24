## Setup database
In the folder /database run:
```bash
docker compose up
```

## Create Kubernetes API Cluster
### 1. Create Kind cluster
```bash
kind create cluster --config ./kind/cluster-config.yaml --name redes-cluster
```
You can check your running clusters with:
```bash 
kind get clusters 
```
### 2. Build Docker Image
In the folder /api run:
```bash
cd api/v1 
docker build -t apiexpress:v1 .
```

### 3. Load Docker Image to the Cluster
```bash
kind load docker-image apiexpress:v1 --name redes-cluster
```
### 5. Add the Database Endpoint and Service configuration to your cluster
```bash
kubectl apply -f k8s/database/
```
### 6. Add the API Deployment and Service configuration to your cluster
```bash
kubectl apply -f k8s/api/
```
### 7. Create the Nginx Controller for the API with ingress

```bash
kubectl apply -f ./nginx/controller-nginx.yaml
```

### 8. Apply the Ingress configuration to the pods of the nginx controller
```bash
kubectl wait --namespace ingress-nginx --for=condition=ready pod --selector=app.kubernetes.io/component=controller --timeout=180s && kubectl apply -f ./nginx/ingress-nginx.yaml
```

### 9. Port forward the Nginx Controller to your localhost
```bash
kubectl port-forward --namespace=ingress-nginx service/ingress-nginx-controller 8080:80
```
This will allow you to access the API through the Nginx Controller. You can check the API by running:

```bash
curl http://localhost:8080/api/v1
```

### 10. Check the status of your pods
```bash 
kubectl get pods 
```
All pods should have STATUS="Running"
### 11. Test the API
```bash 
curl http://localhost:8080/api/v1
```
Instead of ``http://localhost:8080`` you can also curl ``http://apiexpress-service:8080``

To delete your cluster you can run
```bash
kind delete cluster --name redes-cluster
```

# Cluster Monitoring

## Istio & Kiali

To install istio, first delete the previously applied manifests. They will be reinstated after the installation is done:

```bash
kubectl delete -f k8s/database
kubectl delete -f k8s/api --recursive
```

Now. for the install we'll use the latest version (1.22). Otherwise, refer to the [Istio install page](https://istio.io/latest/docs/setup/getting-started/) to check the available options.

### Download Istio

Firstly, download istio and add it to the path variable.

```sh
curl -L https://istio.io/downloadIstio | sh -
cd istio-1.22.0
export PATH=$PWD/bin:$PATH
```

Optionally, said installation can be checked using the following command

```sh
istioctl x precheck
```

### Install Istio

To install Istio, run the following command. We´ll use the _default_ configuration profile, but [others can be chosen](https://istio.io/latest/docs/setup/additional-setup/config-profiles/) based on the given case.

```sh
istioctl install --set profile=default -y
```

Then, we label the namespaces to let istio inject its sidecars for monitoring

```sh
kubectl label ns default istio-injection=enabled
kubectl label ns ingress-nginx istio-injection=enabled
```

Now we can finally reinstate the previously removed manifests, using:

```sh
kubectl apply -f k8s/api --recursive
kubectl apply -f k8s/database
```

The same goes for all of nginx setup commands

### Kiali

To install Kiali, add the manifest with the same procedure used for the api and database.

```sh
kubectl apply -f k8s/kiali
```
Then, init the kiali dashboard with istio to check the traffic on the cluster.

```sh
istioctl dashboard kiali
```

## Prometheus & Grafana

Prometheus is a tool that collects metrics from NGINX, and Grafana can be used to make dashboards to visualize said data.

### Install

To install Prometheus and Grafana run:

```sh
kubectl apply --kustomize github.com/kubernetes/ingress-nginx/deploy/prometheus/
kubectl apply --kustomize github.com/kubernetes/ingress-nginx/deploy/grafana/
```

## Traffic Monitoring

Additionally, traffic through both apis on the cluster can be generated using:

```sh
while sleep 1; do curl "localhost:8080/v1" && curl "localhost:8080/v2"; done
```

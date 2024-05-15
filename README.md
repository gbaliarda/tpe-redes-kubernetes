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

# Istio & Kiali

To install istio, first delete the previously applied manifests. They will be reinstated after the installation is done:

```bash
$> kubectl delete -f k8s/database
$> kubectl delete -f k8s/api
```

Now. for the install we'll use the latest version (1.22). Otherwise, refer to the [Istio install page](https://istio.io/latest/docs/setup/getting-started/) to check the available options.

## Download Istio

Firstly, download istio and add it to the path variable.

```
$> curl -L https://istio.io/downloadIstio | sh -
$> cd istio-1.22.0
$> export PATH=$PWD/bin:$PATH
```

Optionally, said installation can be checked using the following command

```
$> istioctl x precheck
```

## Install Istio

To install Istio, run the following command. We´ll use the _default_ configuration profile, but [others can be chosen](https://istio.io/latest/docs/setup/additional-setup/config-profiles/) based on the given case.

```
$> istioctl install --set profile=default -y
$> kubectl label namespace default istio-injection=enabled
```

Now we can finally reinstate the previously removed manifests of the api and database, using:

```
$> kubectl apply -f k8s/api
$> kubectl apply -f k8s/database
```

## Kiali

To install Kiali, add the manifest with the same procedure used for the api and database.

```
$> kubectl apply -f k8s/kiali
```
Then, init the kiali dashboard with istio to check the traffic on the cluster.

```
$> istioctl dashboard kiali
```

Furthermore, other cluster applications can be installed using the same set of commands. E.g. Prometheus can be installed just using the example file provided by Istio by running the following command.

```
$> kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.18/samples/addons/prometheus.yaml
```
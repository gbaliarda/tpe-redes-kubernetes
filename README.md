# Assignment

TODO.

# Pre-requisites

TODO.

# Installation

## Setup database

1. Start Docker.
2. Run the docker compose file within the `database` folder.

```bash
cd database
docker compose up
```

## Create Kubernetes API Cluster

### 1. Create `kind` cluster

```bash
kind create cluster --config ./kind/cluster-config.yaml --name redes-cluster
```

You can check your running clusters with:

```bash 
kind get clusters
```

You can also check the nodes of the cluster with:

```bash
kubectl get nodes
```

You should see three nodes running: one control plane and two workers.

### 2. Build API Docker images

First, make a copy of the `.env.example` file and rename it to `.env`. This file contains the environment variables needed to connect to the database.

```bash
cp api/v1/.env.example api/v1/.env
cp api/v2/.env.example api/v2/.env
```

Adjust the values as needed, but the default values should work with the provided database configuration.

To build the docker images for both versions of the API, run the following commands from the root of the project:

```bash
docker build -t apiexpress:v1 api/v1
docker build -t apiexpress:v2 api/v2
```

### 3. Load API Docker images into the cluster

```bash
kind load docker-image apiexpress:v1 --name redes-cluster
kind load docker-image apiexpress:v2 --name redes-cluster
```

### 5. Add the database endpoint and service configuration to the cluster

From the root of the project, run the following command:

```bash
kubectl apply -f k8s/database/
```

### 6. Add the API deployment and service configuration to the cluster

From the root of the project, run the following command:

```bash
kubectl apply -f k8s/api/ --recursive
```

### 7. Create the Nginx controller

Install the Nginx controller using the following command:

```bash
kubectl apply -f ./nginx/controller-nginx.yaml
```

This will create the `ingress-nginx` namespace. You can check the pods running in this namespace with:

```bash
kubectl get pods -n ingress-nginx
```

### 8. Apply the Ingress configuration to the nginx controller

The following command will wait for the Nginx controller pod to be ready and then apply the Ingress configuration to it:

```bash
kubectl wait --namespace ingress-nginx --for=condition=ready pod --selector=app.kubernetes.io/component=controller --timeout=180s && kubectl apply -f ./nginx/ingress-nginx.yaml
```

### 9. Port forward the Nginx controller to your localhost

The following command will allow you to access the Nginx controller (and hence the API) from your localhost:

```bash
kubectl port-forward --namespace=ingress-nginx service/ingress-nginx-controller 8080:80
```

You can check the running pods with:

```bash 
kubectl get pods
```

All pods should have status `Running`.

### 10. Test the API

To test that both version of the API are running, you can run the following commands:

```bash 
curl http://localhost:8080/v1
curl http://localhost:8080/v2
```

The difference between the two versions is that:
- V1 allows you to create and read users.
- V2 adds the ability to update and delete users.

Create users using both versions and check that they are stored in the database.

```bash
# V1
curl -X POST -H "Content-Type: application/json" -d '{"username":"user1", "password":"pass1"}' http://localhost:8080/v1/user

# V2
curl -X POST -H "Content-Type: application/json" -d '{"username":"user2", "password":"pass2"}' http://localhost:8080/v2/user
```

Read the users using both versions:

```bash
# V1
curl http://localhost:8080/v1/user/2

# V2
curl http://localhost:8080/v2/user/1
```

Update a user using V2:

```bash
# V1, this should return an error
curl -X PUT -H "Content-Type: application/json" -d '{"username":"newuser11", "password":"newpass11"}' http://localhost:8080/v1/user/1

# V2
curl -X PUT -H "Content-Type: application/json" -d '{"username":"newuser1", "password":"newpass1"}' http://localhost:8080/v2/user/1
```

Delete a user using V2:

```bash
# V1, this should return an error
curl -X DELETE http://localhost:8080/v1/user/2

# V2
curl -X DELETE http://localhost:8080/v2/user/1
```

### 11. Cleanup

To delete your cluster, you can run:

```bash
kind delete cluster --name redes-cluster
```

# Cluster Monitoring

## Istio & Kiali

To install Istio, first delete the previously applied manifests. They will be reinstated after the installation is done:

```bash
kubectl delete -f k8s/database
kubectl delete -f k8s/api --recursive
kubectl delete -f nginx
```

We'll install the latest Istio version (1.22). To install a previous version, refer to the [Istio install page](https://istio.io/latest/docs/setup/getting-started/) to check the available options.

### Download Istio

Firstly, download Istio and add it to the path variable.
- Linux or macOS:
    ```sh
    curl -L https://istio.io/downloadIstio | sh -
    cd istio-1.22.0
    # The command below adds istioctl to the PATH variable, but only for the current session.
    # To make it permanent, add the bin folder to the PATH variable in the .bashrc or .bash_profile file.
    export PATH=$PWD/bin:$PATH
    ```
- Windows:
    1. Go to the [Istio releases page]() and download the latest version. We ran our tests on [v1.22.0](https://github.com/istio/istio/releases/download/1.22.0/istio-1.22.0-win.zip).
    2. Edit the system environment variables and add the path to the `bin` folder of the extracted zip file.

To verify that Istio can be installed in the Kubernetes cluster run:

```sh
istioctl x precheck
```

### Install Istio in the cluster

To install Istio, run the following command. We´ll use the _default_ configuration profile, but [others can be chosen](https://istio.io/latest/docs/setup/additional-setup/config-profiles/) based on the given case.

```sh
istioctl install --set profile=default -y
```

Then, we label the namespaces to let istio inject its sidecars for monitoring:

```sh
kubectl label ns default istio-injection=enabled
kubectl label ns ingress-nginx istio-injection=enabled
```

Now we can finally reinstate the previously removed manifests, using:

```sh
kubectl apply -f k8s/api --recursive
kubectl apply -f k8s/database
```

The same goes for all the nginx setup commands:

```sh
kubectl apply -f ./nginx/controller-nginx.yaml

kubectl wait --namespace ingress-nginx --for=condition=ready pod --selector=app.kubernetes.io/component=controller --timeout=180s && kubectl apply -f ./nginx/ingress-nginx.yaml
```

### Kiali

To install Kiali, add the manifest with the same procedure used for the api and database.

```sh
kubectl apply -f k8s/kiali
```

Wait for the pod to be ready, and then init the kiali dashboard with istio to check the traffic on the cluster.

```sh
istioctl dashboard kiali
```

This will run the Kiali dashboard on `localhost:20001`, which can be accessed on the browser.

**TODO**: add Prometheus installation instructions and then show how to see the Traffic Graph on Kiali, including images.

## Prometheus & Grafana

Prometheus is a tool that collects metrics from NGINX, and Grafana can be used to make dashboards to visualize said data.

### Install

Before installing Prometheus and Grafana, make sure to have the NGINX controller and service running. If not, refer to steps 7 and 8 of the first section.

To install Prometheus and Grafana run:

```sh
kubectl apply --kustomize k8s/prometheus
kubectl apply --kustomize k8s/grafana
```

You can check the running pods with:

```bash
kubectl get pods -n ingress-nginx
```

Then, to get the services' port run the following command:

```bash
kubectl get svc -n ingress-nginx
```

### Grafana Dashboard

To access the Grafana dashboard, you must port-forward the service to your localhost:

```sh
kubectl port-forward -n ingress-nginx service/grafana 3000:3000
```

The Grafana dashboard will be accessible on `localhost:3000`, where the default user and password are both `admin`.

To load the example dashboard from `dashboard.json`, follow these steps:

1. Using the search bar, go to 'Data Sources'.
2. Click on 'Add data source'.
3. Select Prometheus.
4. Enter the configuration details. The only mandatory one is the prometheus server URL.
    
   - To get this URL, run `kubectl get svc -n ingress-nginx` and get the CLUSTER-IP address of the `prometheus-server` service, as well as the PORT (the one at the left, which should be 9090).
   - The URL will then look like this: `http://10.96.5.14:9090`.

5. Click on 'Save and Test' at the end of the page.
6. Go to Dashboards -> New -> Import -> Upload dashboard JSON file.
7. Load the `dashboard.json` file located on the root of the project.
8. Select a Prometheus data source (you should see the default prometheus data source created on step 4).
9. Click "Import".

## Traffic Monitoring

Traffic on both apis running on the cluster can be generated using:

```sh
while sleep 1; do curl "localhost:8080/v1" && curl "localhost:8080/v2"; done
```

You should then be able to see the traffic on the monitoring tools.

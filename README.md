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

### 2. Build API Docker images

First, make a copy of the `.env.example` file and rename it to `.env`. This file contains the environment variables needed to connect to the database.

```bash
cp api/v1/.env.example api/v1/.env
cp api/v2/.env.example api/v2/.env
```

Adjust the values as needed, but the default values should work with the provided database configuration.

To build the docker image for the V1 of the API, run the following command from the root of the project:

```bash
docker build -t apiexpress:v1 api/v1
```

To build the docker image for the V2 of the API, run the following command from the root of the project:

```bash
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

```bash
kubectl apply -f ./nginx/controller-nginx.yaml
```

### 8. Apply the Ingress configuration to the pods of the nginx controller

```bash
kubectl wait --namespace ingress-nginx --for=condition=ready pod --selector=app.kubernetes.io/component=controller --timeout=180s && kubectl apply -f ./nginx/ingress-nginx.yaml
```

### 9. Port forward the Nginx controller to your localhost

```bash
kubectl port-forward --namespace=ingress-nginx service/ingress-nginx-controller 8080:80
```

This will allow you to access the API through the nginx controller.

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

Firstly, download Istio and add it to the path variable. Make sure to use Linux or MacOS, as the script is not compatible with Windows.

```sh
curl -L https://istio.io/downloadIstio | sh -
cd istio-1.22.0
export PATH=$PWD/bin:$PATH
```

Optionally, said installation can be checked using the following command:

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

Then, to access both Prometheus and Grafana we must get the *IP:PORT* of both, where *IP* refers to the cluster node monitored, and *PORT* to the port in which the service is run.

Firstly, to get the cluster nodes' IP run:

```bash
kubectl get nodes -o wide
```

We need the IP from the INTERNAL-IP column.

Then, to get the services' port run the following command:

```bash
kubectl get svc -n ingress-nginx
```

### Grafana

When accessing grafana, both user and password are required to enter, with _admin_ _admin_ as default values.

Then, to load the dashboard on *dashboard.json* do the following steps:

- Using the search bar, go to 'Data Sources'
- Click on 'Add data source'
- Select Prometheus
- Enter the configuration details. The only mandatory one is to specify prometheus IP:PORT to access.
- Click on 'Save and Test' at the end of the page.
- Go back to the main menu, then click on '+' -> Add Dashboard -> Import Dashboard
- Load the provided _dashboard.json_ file
- Click "Import"

## Traffic Monitoring

Additionally, traffic through both apis on the cluster can be generated using:

```sh
while sleep 1; do curl "localhost:8080/v1" && curl "localhost:8080/v2"; done
```

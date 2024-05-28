# Authors

- Baliarda Gonzalo
- Birsa Nicolás
- Perez Ezequiel Agustín
- Ye Li Valentín

# Assignment

- Create a Kubernetes cluster with one Master and at least two slaves, exposing an API on a generic port (different from 80).
- Implement a local database on a server (outside the cluster) and expose a service that redirects cluster traffic to the server.
- Deploy a web server (nginx or Apache HTTPD listening on port 80) and set up a reverse proxy to the API.
- Show two different versions of the API coexisting.
- Integrate Istio and Kiali services into the cluster.

# Pre-requisites

- `docker`
- `docker compose`
- `kubectl`
- `kind`
- `istio`

### Install Docker

Obtaining Docker Certificates and Keys for Ubuntu

```bash
# Add Docker's official GPG key:
sudo apt-get update
sudo apt-get install ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources:
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
```

Install the latest version:

```bash
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

Verify installation:

```bash
sudo docker run hello-world
```

To avoid using Docker as root:

Create docker group:

```bash
sudo groupadd docker
```

Add user to docker group:

```bash
sudo usermod -aG docker $USER
```

Log out and back in, or run:

```bash
newgrp docker
```

### Install kubectl

Using curl:

```bash
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
```

Install kubectl:

```bash
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
```

### Install kind

Using curl:

```bash
[ $(uname -m) = x86_64 ] && curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.22.0/kind-linux-amd64
```

Change permissions:

```bash
chmod +x ./kind
```

Move kind to `/usr/local/bin`:

```bash
sudo mv ./kind /usr/local/bin/kind
```

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

## Istio

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
4. Enter the configuration details. The only mandatory one is the prometheus server URL, which should be `http://prometheus-server.ingress-nginx.svc.cluster.local:9090`.

<img loading="lazy" src="images/prometheus_url.png" alt="Prometheus url" />

5. Click on 'Save and Test' at the end of the page. Then prometheus' availability will be queried, which should output a popup message as shown.

<img loading="lazy" src="images/save_and_test.png" alt="Save and test prometheus API" />

6. On the side menu, click on Dashboards. Then, New -> Import -> Upload dashboard JSON file.
7. Load the `dashboard.json` file located on the root of the project.
8. Select a Prometheus data source (you should see the default prometheus data source created on step 4). After these steps, the import screen should be as follows.

<img loading="lazy" src="images/import_dashboard.png" alt="Final import screen" />

9. Click "Import". Then you will be prompted to the home page and shown the imported dashboard.

<img loading="lazy" src="images/dashboard_screen.png" alt="Home page with dashboard" />

## Kiali

Kiali is an observavility console for Istio, letting us understand the structure and health of the service mesh by monitoring traffic flow to infer the topology and report errors.

### Install

To install Kiali, add the manifest with the same procedure used for the api and database.

```sh
kubectl apply -f k8s/kiali
```

Prometheus must also be installed, as Kiali uses its metrics to operate. In case the 'Prometheus & Grafana' section install step was skipped, install Prometheus using:

```sh
kubectl apply --kustomize k8s/prometheus
```

### Run

Wait for the pod to be ready, and then init the kiali dashboard with istio to check the traffic on the cluster.

```sh
istioctl dashboard kiali
```

Then, you will be prompted to Kiali UI on the url `http://localhost:20001`. There, you can monitor multiple things such as the _Traffic Graph_, which should be as follows:

<img loading="lazy" src="images/traffic_graph.png" alt="Kiali traffic graph" />

It should be noted that there must be traffic present on the cluster, otherwise the previous graph will only contain idle nodes. Said traffic can be generated using the command shown on the following section.


## Generating Traffic

Traffic through both apis running on the cluster can be generated using:

```sh
while sleep 1; do curl "localhost:8080/v1" && curl "localhost:8080/v2"; done
```
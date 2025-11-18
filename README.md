# Microservices E-commerce Platform

This is a microservice-based (e-commerce) designed to demonstrate DevOps best practices using Kubernetes,CI/CD pipelines and istio. The system is composed of seven services (cart,inventory,notification built with go, (order,product) node.js and shipping,user build with python) each running in its own container and orchestrated with Kubernetes.


Prerequisite
-Programming language - Node.js, Python, Go and Javascript (for building)
-Kubernetes for app orchestration
-docker for containerization
-istio for ingress mesh
-kustomization
-promethues 
-grafana
-terraform



Step 1. Environment setup (installation and configuration)
-python (link)
-node.js (link)
-go (link)
- vs code IDE (link)
- istio installation
- local registry or (Docker HUb), i used ACR (azure)

-file tree set-up


Step 2. Setting up services and test locally
-cart, product, inventory - Node.js and express
-notification, user, product - Go
-shipping - python

all api are tested locally and before implementing docker and kubernetes

step 3. Docker setup
Docker container were configure for all the service created 

image/video

step 4- Cloud integration (Azure)
Set-up Azure AKS ACR 
-create resource group
-create acr
-login to acr
-create aks
-merge acr to work with aks
kubectl get nodes (to test if node is connected and running)


step 5 -set up kubernetes deployment and service file

make sure the selector-image of the file is the same as the image you'll build new docker in the next step


step 6- build docker image and push to Azure registry


# Build Docker image
docker build -t briitzacr.azurecr.io/order-service:v1

docker build -t briitzacr.azurecr.io/shipping-service:v1
docker build -t briitzacr.azurecr.io/notification-service:v1
docker build -t briitzacr.azurecr.io/cart-service:v1
docker build -t briitzacr.azurecr.io/inventory-service:v1


 . (Ensure image name is the)

# Log in to Azure Container Registry (ACR)
az acr login --name <my-acr-name> make sure you're login before pushing.

# Push the image to ACR
docker push <my-acr-name>.azurecr.io/my--name:v1

docker push briitzacr.azurecr.io/cart-service:v1
docker push briitzacr.azurecr.io/shipping-service:v1
docker push briitzacr.azurecr.io/notification-service:v1
docker push briitzacr.azurecr.io/inventory-service:v1

docker push briitzacr.azurecr.io/order-service:v1

## On Local: If using minikube

# Build Docker image
docker build -t order-service:v1

# login to docker locally
docker login

# Tag the image for ACR
docker tag my-image-name:v1 docker.io/my-image-name:v1

# Push the image to ACR
docker push docker.io/my-image-name:v1



step 7 - set up namespace, deployment and service file and apply all

kubectl apply -f cart/deployment.yaml
kubectl apply -f inventory/deployment.yaml
kubectl apply -f notification/deployment.yaml
kubectl apply -f shipping/deployment.yaml

kubectl apply -f service.yaml


step 8 - check id the apply is successfully build and running
kubectl get deployment -n your-namespace
kubectl get pods -n my-namespace

kubectl get service -n you-name-space











## SETTING UP ISTIO FOR MESH ROUTING

-Step-1 Installation

# download latest (Linux/macOS)
curl -L https://istio.io/downloadIstio | sh -

# move into the new istio directory (example name)
cd istio-*

# add istioctl to path for this shell session
export PATH=$PWD/bin:$PATH

# check
istioctl version


-install Istio control panel
# demo profile 
istioctl install --set profile=demo -y


after verifying istio installation and configuration. three files were created gateway file which handles external traffic of all the services,  Virtualservice (handles retires and timeout of each services) destinationrul and peerauthentication (Encrypts all traffic between your microservices inside the mesh 'user-mtls.yaml') for each microservices

```
kubectl apply -f istio/virtualservices/user-virtualservice.yaml
kubectl apply -f istio/destinationrules/user-destinationrule.yaml


```
verify if setup is wprking 'curl http://<EXTERNAL-IP>/user
'


Add observabity and telemetry (promethues, grafana and jaeger)
run this command to authematically install the tools for observability
---
kubectl apply -f samples/addons -n istio-system
---

## canary deployment set up

for canary deployment, a new deployment file is created 'deployment-v2' with another image created on with the same docker file, a user-dr-subset is created
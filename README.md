## Microservices E-commerce Platform

This is a microservice-based (e-commerce) designed to demonstrate DevOps best practices using Kubernetes,CI/CD pipelines and istio. The system is composed of seven services: cart,inventory,notification,order,products, payment and shipping, each running in its own container and orchestrated with Kubernetes.


Prerequisite
-Programming language - Node.js, Python, Go and Javascript (for building)
-Kubernetes for app orchestration
-docker for containerization
-istio for ingress mesh

## Project Structure
Services                   Programming-language          Function
Product Service            Go                            Listing Products    
Cart Service               Node.js                       Shopping cart management
Order Service              Python                        Order orchestration
Payment Service            Go                            Payment processing with 10% simulated failures
User Service               Go                            User management
Inventory Service          Python                        Stock management
Shipping Service           Node.js                       Shipment tracking
Notification Service       Python                        Event notifications


## Key Features Implemented:
✅ Istio Service Mesh
Automatic sidecar injection
mTLS (STRICT mode) for all service communication
Envoy proxy for traffic management

✅ Traffic Management
Canary Deployment: 10% traffic to v2, 90% to v1
Virtual Services for routing
Destination Rules for load balancing

✅ Resilience Patterns
Circuit Breaker: Ejects failing instances after 3 consecutive errors
Automatic Retries: 3 attempts with 2s timeout
Timeouts: 10s for critical paths
Connection Pooling: Limits to prevent resource exhaustion

✅ Fault Injection
Delay injection (configurable percentage and duration)
HTTP abort injection (simulated 503 errors)
Combined fault scenarios

✅ Observability
Kiali: Service mesh visualization
Grafana: Metrics dashboards
Jaeger: Distributed tracing
Prometheus: Metrics collection


## Step 1. Environment setup (installation and configuration)
-python (link)
-node.js (link)
-go (link)
- vs code IDE (link)
- istio installation
- local registry or (Docker HUb), i used ACR (azure)

-file tree set-up


Step 2. Setting up services and test locally


step 3. Docker setup
Docker container were configure for all the service created 


## Cloud integration (Azure)
Step 4
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


# Log in to Azure Container Registry (ACR)
az acr login --name <my-acr-name> make sure you're login before pushing.

# Build and Push Docker image to the registry ACR
docker push briitzacr.azurecr.io/cart-service:v1

docker push briitzacr.azurecr.io/cart-service:v1




step 7 - set up namespace, deployment and service file and apply all

kubectl apply -f cart/deployment-v1.yaml

(For canary deployment v2 is created)
kubectl apply -f cart/deployment-v2.yaml

kubectl apply -f cart/service.yaml

Note: Service type must be set to clusterIP because istio handles the service within the cluster


step 8 - check if the apply is successfully build and running
kubectl get deployment -n namespace
kubectl get pods -n namespace

kubectl get service -n namespace











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
kubectl apply -f istio/user-virtualservice.yaml
kubectl apply -f istio/user-destinationrule.yaml
kubectl apply -f istio/user-peerauthentication.yaml


```
verify if setup is working 'curl http://<EXTERNAL-IP>/user
'


## Add observabity and telemetry (promethues, grafana and jaeger)

Run this command to authematically install the tools for observability
---
kubectl apply -f samples/addons -n istio-system
---
    
## Step 2: Monitor Metrics
Check error rates, latency, and throughput:
  ```bash
    # View service mesh metrics in Kiali
    kubectl port-forward -n istio-system svc/kiali 20001:20001
    
    # View Grafana dashboards
    kubectl port-forward -n istio-system svc/grafana 3000:3000
    
    # Check Jaeger traces
    kubectl port-forward -n istio-system svc/tracing 16686:16686
    ```






To list container images stored in **Azure Container Registry (ACR)**, you use the Azure CLI. Here are the key commands:

### 🔑 Steps
1. **Log in to ACR** (if not already):
   ```bash
   az acr login --name <registry-name>
   ```

2. **List repositories** (top-level image names):
   ```bash
   az acr repository list --name <registry-name> --output table
   ```

3. **List tags for a specific repository** (versions of an image):
   ```bash
   az acr repository show-tags --name <registry-name> --repository <image-name> --output table
   ```

4. **Show details of an image**:
   ```bash
   az acr repository show-manifests --name <registry-name> --repository <image-name> --output table
   ```

### ⚡ Example
If your registry is `briitzacr` and you want to see all images:
```bash
az acr repository list --name briitzacr --output table
```

To see all tags of `order-service`:
```bash
az acr repository show-tags --name briitzacr --repository order-service --output table
```

This way you can confirm which versions (e.g., `v5`, `v6`) are available in your ACR.  

Would you like me to also show you how to **delete old tags/images** from ACR to keep it clean?





Your current Dockerfile only copies `main.py` and doesn’t install any dependencies, which is why Flask is missing. You need to add a `pip install` step. Here’s the corrected minimal version:

```dockerfile
# Use an official Python runtime as a parent image
FROM python:3.12-slim

# Set working directory
WORKDIR /app

# Copy the Python script into the container
COPY main.py .

# Install required libraries directly
RUN pip install flask requests

# Command to run your app
CMD ["python", "main.py"]
```

### Next steps
1. Save this updated Dockerfile.  
2. Rebuild and push the image:  
   ```bash
   docker build -t briitzacr.azurecr.io/order-service:v6 .
   docker push briitzacr.azurecr.io/order-service:v6
   ```
3. Update your deployment to use the new image:  
   ```bash
   kubectl set image deployment/order-deployment-v1 order-service=briitzacr.azurecr.io/order-service:v6 -n k8s
   ```

That will ensure Flask and requests are installed, so the container won’t crash on startup.  

Would you like me to also show you how to extend this so you can add more libraries later without editing the Dockerfile each time?

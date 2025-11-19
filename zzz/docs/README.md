You have two issues here:

1. **Authentication**: AKS can't authenticate to pull from your Azure Container Registry (ACR)
2. **Image not found**: The image `user-service:v1` might not exist in your ACR

## Step 1: Verify the Image Exists

```bash
# Login to ACR
az acr login --name briitzacr

# List all repositories
az acr repository list --name briitzacr --output table

# Check if user-service exists and list tags
az acr repository show-tags --name briitzacr --repository user-service --output table
```

If the image doesn't exist, you need to build and push it first:

```bash
# Build and push (from your user-service directory)
docker build -t briitzacr.azurecr.io/user-service:v1 .
docker push briitzacr.azurecr.io/user-service:v1
```

## Step 2: Fix AKS-ACR Authentication

The `401 Unauthorized` error means AKS can't pull from ACR. Attach ACR to your AKS cluster:

```bash
# Option 1: Attach ACR to AKS (Recommended - uses managed identity)
az aks update --resource-group briitz --name briitzCluster --attach-acr briitzacr
```

This command grants the AKS cluster's managed identity permission to pull images from your ACR.

## Step 3: Verify the Connection

```bash
# Check if the attachment was successful
az aks check-acr --resource-group briitz --name briitzCluster --acr briitzacr.azurecr.io
```

## Step 4: Restart Your Deployment

```bash
# Delete the failing pods to trigger a fresh pull
kubectl rollout restart deployment user-deployment -n k8s-microservices

# Watch the status
kubectl get pods -n k8s-microservices -w
```

## Alternative: Use Image Pull Secret (Manual Method)

If `attach-acr` doesn't work, create an image pull secret:

```bash
# Get ACR credentials
ACR_USERNAME=$(az acr credential show --name briitzacr --query username -o tsv)
ACR_PASSWORD=$(az acr credential show --name briitzacr --query passwords[0].value -o tsv)

# Create Kubernetes secret
kubectl create secret docker-registry acr-secret \
  --namespace k8s-microservices \
  --docker-server=briitzacr.azurecr.io \
  --docker-username=$ACR_USERNAME \
  --docker-password=$ACR_PASSWORD

# Update your deployment to use the secret
kubectl patch deployment user-deployment -n k8s-microservices -p '{"spec":{"template":{"spec":{"imagePullSecrets":[{"name":"acr-secret"}]}}}}'
```

## Quick Verification Commands

```bash
# Check current ACR attachment
az aks show --resource-group briitz --name briitzCluster --query "servicePrincipalProfile"

# Check if managed identity has ACR pull role
az role assignment list --scope /subscriptions/$(az account show --query id -o tsv)/resourceGroups/briitz/providers/Microsoft.ContainerRegistry/registries/briitzacr --query "[?roleDefinitionName=='AcrPull']" -o table
```

The **attach-acr** method is the cleanest and most secure solution. It usually takes 1-2 minutes to propagate, then your pods should pull successfully.





















# Microservices E-commerce Platform

This project is a microservices-based e-commerce platform designed to demonstrate DevOps best practices using Kubernetes and CI/CD pipelines. The system is composed of four main services, each running in its own container and orchestrated with Kubernetes.




# 1. Build Docker image
docker build -t order-service:v1 .

docker build -t briitzacr.azurecr.io/order-service:v1 .
docker build -t briitzacr.azurecr.io/user-service:v1 .

# 2. Log in to Azure
az login

# 3. Log in to Azure Container Registry (ACR)
az acr login --name <your-acr-name>

# 4. Tag the image for ACR
docker tag myimage:v1 <your-acr-name>.azurecr.io/myimage:v1

docker tag order-service:v1 briitzacr.azurecr.io/order-service:v1
docker tag order-service:v1 briitzacr.azurecr.io/order-service:v1

# 5. Push the image to ACR
docker push <your-acr-name>.azurecr.io/myimage:v1

docker push briitzacr.azurecr.io/order-service:v1
docker push briitzacr.azurecr.io/user-service:v1






# What is mTLS?
-Mutual TLS (mTLS) ensures both client and server authenticate each other using certificates.
-Enhances security by requiring trusted identities on both ends.

# What are retries?
-Automatic reattempts of failed requests due to transient issues (e.g. timeouts, network errors).
-Configurable in most HTTP clients or service meshes.





#!/bin/bash

# ============================================
# Microservices E-Commerce Deployment Guide
# with Istio Service Mesh
# ============================================

echo "======================================"
echo "E-Commerce Microservices Deployment"
echo "======================================"

# STEP 1: Prerequisites Check
echo ""
echo "Step 1: Checking Prerequisites..."
echo "-----------------------------------"

check_command() {
  if ! command -v $1 &> /dev/null; then
    echo "❌ $1 is not installed"
    exit 1
  else
    echo "✓ $1 is installed"
  fi
}

check_command kubectl
check_command istioctl

# STEP 2: Install Istio
echo ""
echo "Step 2: Installing Istio..."
echo "----------------------------"

# Download Istio (if not already installed)
if [ ! -d "istio-1.20.0" ]; then
  echo "Downloading Istio..."
  curl -L https://istio.io/downloadIstio | ISTIO_VERSION=1.20.0 sh -
  cd istio-1.20.0
  export PATH=$PWD/bin:$PATH
  cd ..
fi

# Install Istio with demo profile
echo "Installing Istio control plane..."
istioctl install --set profile=demo -y

# Verify Istio installation
kubectl get pods -n istio-system

# Install Istio addons (Kiali, Prometheus, Grafana, Jaeger)
echo "Installing observability tools..."
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.20/samples/addons/prometheus.yaml
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.20/samples/addons/grafana.yaml
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.20/samples/addons/kiali.yaml
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.20/samples/addons/jaeger.yaml

# Wait for addons to be ready
kubectl rollout status deployment/kiali -n istio-system
kubectl rollout status deployment/grafana -n istio-system

# STEP 3: Create Namespace and Deploy Services
echo ""
echo "Step 3: Deploying Microservices..."
echo "-----------------------------------"

# Create namespace with Istio injection
kubectl apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: ecommerce
  labels:
    istio-injection: enabled
EOF

# Deploy all ConfigMaps (service code)
echo "Creating ConfigMaps..."
kubectl apply -f service_code_configmaps.yaml
kubectl apply -f remaining_services.yaml

# Deploy all services and deployments
echo "Deploying services..."
kubectl apply -f k8s_deployments.yaml

# Deploy Istio configuration
echo "Configuring Istio..."
kubectl apply -f ecommerce_namespace.yaml

# Wait for all deployments
echo "Waiting for deployments to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment --all -n ecommerce

# STEP 4: Verify Deployment
echo ""
echo "Step 4: Verifying Deployment..."
echo "--------------------------------"

echo "Pods:"
kubectl get pods -n ecommerce

echo ""
echo "Services:"
kubectl get svc -n k8s

echo ""
echo "Istio Virtual Services:"
kubectl get virtualservices -n k8s

echo ""
echo "Istio Destination Rules:"
kubectl get destinationrules -n k8s

# STEP 5: Get Gateway IP
echo ""
echo "Step 5: Getting Ingress Gateway IP..."
echo "--------------------------------------"

export INGRESS_HOST=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
export INGRESS_PORT=$(kubectl -n istio-system get service 

istio-ingressgateway -o jsonpath='{.spec.ports[?(@.name=="http2")].port}')
export GATEWAY_URL=$INGRESS_HOST:$INGRESS_PORT

if [ -z "$INGRESS_HOST" ]; then
  echo "Using NodePort instead of LoadBalancer..."
  export INGRESS_HOST=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="ExternalIP")].address}')
  export INGRESS_PORT=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.spec.ports[?(@.name=="http2")].nodePort}')
  export GATEWAY_URL=$INGRESS_HOST:$INGRESS_PORT
fi

echo "Gateway URL: http://$GATEWAY_URL"

# STEP 6: Test Services
echo ""
echo "Step 6: Testing Services..."
echo "----------------------------"

echo "Testing Product Service..."
curl -s http://$GATEWAY_URL/api/products | jq '.' || curl -s http://$GATEWAY_URL/api/products

echo ""
echo "Testing specific product..."
curl -s http://$GATEWAY_URL/api/products/1 | jq '.' || curl -s http://$GATEWAY_URL/api/products/1

# STEP 7: Deploy Canary (10% traffic to v2)
echo ""
echo "Step 7: Deploying Canary (10% to v2)..."
echo "----------------------------------------"

kubectl apply -f canary_deployment.yaml

echo "Canary deployment active. Testing traffic distribution..."
sleep 5

# Run canary test
kubectl apply -f - <<EOF
apiVersion: batch/v1
kind: Job
metadata:
  name: canary-test-$(date +%s)
  namespace: ecommerce
spec:
  template:
    spec:
      containers:
      - name: test
        image: curlimages/curl:latest
        command: ["/bin/sh", "-c"]
        args:
        - |
          echo "Testing 100 requests for traffic distribution..."
          v1_count=0
          v2_count=0
          for i in \$(seq 1 100); do
            response=\$(curl -s http://product-service:8080/api/products)
            version=\$(echo \$response | grep -o '"version":"v[12]"' | cut -d'"' -f4)
            if [ "\$version" = "v1" ]; then
              v1_count=\$((v1_count + 1))
            elif [ "\$version" = "v2" ]; then
              v2_count=\$((v2_count + 1))
            fi
          done
          echo "Results: v1=\$v1_count (~90%), v2=\$v2_count (~10%)"
      restartPolicy: Never
  backoffLimit: 1
EOF

# STEP 8: Configure Fault Injection
echo ""
echo "Step 8: Setting up Fault Injection..."
echo "--------------------------------------"

kubectl apply -f fault_injection.yaml

echo "Fault injection configured. To test:"
echo "  kubectl create job --from=cronjob/fault-injection-test test-$(date +%s) -n ecommerce"

# STEP 9: Access Observability Tools
echo ""
echo "Step 9: Observability Dashboard URLs"
echo "-------------------------------------"

echo "Starting port-forwards for observability tools..."

# Kiali
kubectl port-forward -n istio-system svc/kiali 20001:20001 > /dev/null 2>&1 &
echo "Kiali (Service Mesh): http://localhost:20001"

# Grafana
kubectl port-forward -n istio-system svc/grafana 3000:3000 > /dev/null 2>&1 &
echo "Grafana (Metrics): http://localhost:3000"

# Jaeger
kubectl port-forward -n istio-system svc/tracing 16686:16686 > /dev/null 2>&1 &
echo "Jaeger (Tracing): http://localhost:16686"

# Prometheus
kubectl port-forward -n istio-system svc/prometheus 9090:9090 > /dev/null 2>&1 &
echo "Prometheus (Metrics): http://localhost:9090"

# STEP 10: Demo Commands
echo ""
echo "========================================="
echo "Deployment Complete!"
echo "========================================="
echo ""
echo "📊 DEMO COMMANDS:"
echo ""
echo "1. View Service Mesh Topology:"
echo "   Open Kiali at http://localhost:20001"
echo "   Go to Graph -> Namespace: ecommerce -> Display: Traffic Animation"
echo ""
echo "2. Test Canary Deployment (10% traffic to v2):"
echo "   for i in {1..20}; do curl http://$GATEWAY_URL/api/products | grep version; done"
echo ""
echo "3. Test with specific version:"
echo "   curl -H 'x-version: v2' http://$GATEWAY_URL/api/products"
echo ""
echo "4. Inject Delay Fault (50% of requests delayed by 5s):"
echo "   kubectl apply -f - <<EOF"
echo "   apiVersion: networking.istio.io/v1beta1"
echo "   kind: VirtualService"
echo "   metadata:"
echo "     name: payment-service"
echo "     namespace: ecommerce"
echo "   spec:"
echo "     hosts:"
echo "     - payment-service"
echo "     http:"
echo "     - fault:"
echo "         delay:"
echo "           percentage:"
echo "             value: 50.0"
echo "           fixedDelay: 5s"
echo "       route:"
echo "       - destination:"
echo "           host: payment-service"
echo "   EOF"
echo ""
echo "5. Test Order Creation (will trigger payment with retries):"
echo "   curl -X POST http://$GATEWAY_URL/api/orders \\"
echo "     -H 'Content-Type: application/json' \\"
echo "     -d '{\"userId\":\"1\",\"items\":[{\"productId\":\"1\",\"price\":999.99,\"quantity\":1}]}'"
echo ""
echo "6. View Circuit Breaker Stats:"
echo "   kubectl exec -n ecommerce deployment/product-service-v1 -c istio-proxy -- \\"
echo "     pilot-agent request GET stats | grep product-service | grep outlier"
echo ""
echo "7. Monitor mTLS Status:"
echo "   istioctl authn tls-check -n ecommerce"
echo ""
echo "8. View Service Logs:"
echo "   kubectl logs -n ecommerce -l app=order-service --tail=50 -f"
echo ""
echo "9. Gradual Rollout to v2 (increase to 50%):"
echo "   kubectl patch virtualservice product-canary -n ecommerce --type merge -p '"
echo "   {\"spec\":{\"http\":[{\"route\":[{\"destination\":{\"host\":\"product-service\",\"subset\":\"v1\"},\"weight\":50},{\"destination\":{\"host\":\"product-service\",\"subset\":\"v2\"},\"weight\":50}]}]}}'"
echo ""
echo "10. Rollback to v1 (100% traffic):"
echo "    kubectl patch virtualservice product-canary -n ecommerce --type merge -p '"
echo "    {\"spec\":{\"http\":[{\"route\":[{\"destination\":{\"host\":\"product-service\",\"subset\":\"v1\"},\"weight\":100}]}]}}'"
echo ""
echo "========================================="
echo "Key Features Demonstrated:"
echo "========================================="
echo "✓ 8 Microservices (Product, Cart, Order, Payment, User, Inventory, Shipping, Notification)"
echo "✓ Istio Service Mesh with sidecar injection"
echo "✓ mTLS encryption (STRICT mode)"
echo "✓ Canary Deployment (10% traffic split)"
echo "✓ Circuit Breaker (outlier detection)"
echo "✓ Automatic Retries (3 attempts, 2s timeout)"
echo "✓ Fault Injection (delays & aborts)"
echo "✓ Traffic Management & Load Balancing"
echo "✓ Observability (Kiali, Grafana, Jaeger, Prometheus)"
echo "========================================="
echo ""
echo "To cleanup:"
echo "  kubectl delete namespace ecommerce"
echo "  istioctl uninstall --purge -y"
echo ""
























To remove a Docker image from your system, you can use the following command:

```bash
docker rmi <image_name_or_id>
```

### 🔧 Example Usage
```bash
docker rmi ubuntu:latest
```
This command removes the `ubuntu:latest` image from your local Docker repository.

### 🛑 Notes
- If the image is being used by a container (even stopped), you’ll need to remove the container first using `docker rm <container_id>`.
- To force removal, use the `-f` flag:
  ```bash
  docker rmi -f <image_name_or_id>
  ```

Want help listing all images or containers before removing one? I can show you how.
To list images stored in an **Azure Container Registry (ACR)**, you can use the Azure CLI with the following command:

```bash
az acr repository list --name <ACR_NAME> --output table
```

### 📦 This command shows:
- All repositories (image names) in your ACR.
- Use `--output table` for a clean, readable format.

### 🔍 To list tags (versions) of a specific image:
```bash
az acr repository show-tags --name <ACR_NAME> --repository <repository_name> --output table
```

### ✅ Example:
```bash
az acr repository show-tags --name myregistry --repository myapp --output table
```
This lists all tags for the `myapp` image in the `myregistry` ACR.

I can also show you how to filter by date or size if you're cleaning up old images.

















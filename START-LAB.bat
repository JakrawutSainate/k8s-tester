@echo off
setlocal

echo 🚀 Starting Kubernetes Beginner Lab...

REM 1. Check/Create Kind Cluster
kind.exe get clusters | findstr "k8s-lab" >nul
if %errorlevel% equ 0 (
    echo ✅ Cluster 'k8s-lab' already exists.
) else (
    echo 📦 Creating Kind cluster 'k8s-lab'...
    kind.exe create cluster --name k8s-lab --config k8s-lab/kind-config.yaml
)

REM 2. Install Metrics Server
echo 📊 Installing Metrics Server...
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
REM Patching Metrics Server for Insecure TLS (Kind requirement)
kubectl patch deployment metrics-server -n kube-system --type="json" -p="[{\"op\": \"add\", \"path\": \"/spec/template/spec/containers/0/args/-\", \"value\": \"--kubelet-insecure-tls\"}]"

REM 3. Apply Lab Manifests
echo 🛠️ Applying Deployment Manifests...
kubectl apply -f k8s-lab/dashboard-setup.yaml
kubectl apply -f k8s-lab/target-app-deploy.yaml
kubectl apply -f k8s-lab/locust-deploy.yaml

REM 4. Wait for Pods
echo ⏳ Waiting for all pods to be ready...
echo    (This may take 1-2 minutes. Please be patient!)
kubectl wait --for=condition=ready pod --all --all-namespaces --timeout=300s

REM 5. Get Admin Token
echo.
echo 🔑 Getting Admin Token...
for /f "tokens=*" %%i in ('kubectl -n kubernetes-dashboard create token admin-user') do set ADMIN_TOKEN=%%i

echo ---------------------------------------------------------------------------------
echo %ADMIN_TOKEN%
echo ---------------------------------------------------------------------------------
echo 📋 COPY the token above. You will need it to log in to the Dashboard!

REM 6. Start Port Forwarding & Open Browser
echo.
echo 🌐 Starting UI Port-Forwarding...

REM Kill existing port-forwards (best effort)
taskkill /F /IM kubectl.exe >nul 2>&1

REM Forward Dashboard (8001 -> 443)
start /b kubectl port-forward -n kubernetes-dashboard svc/kubernetes-dashboard 8001:443 >nul 2>&1
echo Started Dashboard PF...

REM Forward Locust (8654 -> 8654)
start /b kubectl port-forward svc/locust-ui-svc 8654:8654 >nul 2>&1
echo Started Locust PF...

echo ✅ Port-forwarding started.
echo    Opening Default Browser...

timeout /t 5 >nul
start https://localhost:8001
start http://localhost:8654

echo.
echo 🎉 LAB IS READY!
echo    - K8s Dashboard: https://localhost:8001 (Paste the Token to login)
echo    - Locust Load Test: http://localhost:8654
echo.
echo ⚠️  Keep this terminal OPEN to keep the connection alive.
echo    Press Ctrl+C to stop (and manually close kubectl processes if needed).

pause

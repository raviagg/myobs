# Create shared namespace
GROUP=myobs
NS_OBS=ns-${GROUP}
kubectl create ns ${NS_OBS}
echo "**** Namespace ${NS_OBS} created"

#########################
# Utility Functions
#########################

wait_for_argo_app() {
    local APP_NAME=$1
    local NS=$2
    local MAX_RETRIES=${3:-30} # Default to 30 retries if not provided
    local SLEEP_TIME=10

    echo "--- Waiting for Argo App: $APP_NAME in $NS ---"

    for ((i=1; i<=$MAX_RETRIES; i++)); do
        # Get statuses
        local STATUS=$(kubectl get app "$APP_NAME" -n "$NS" -o jsonpath='{.status.sync.status} {.status.health.status}' 2>/dev/null)
        local SYNC=$(echo $STATUS | cut -d' ' -f1)
        local HEALTH=$(echo $STATUS | cut -d' ' -f2)

        if [[ "$SYNC" == "Synced" && "$HEALTH" == "Healthy" ]]; then
            echo "✅ $APP_NAME is Synced and Healthy!"
            return 0
        fi

        if [[ "$HEALTH" == "Degraded" ]]; then
            echo "❌ $APP_NAME is Degraded! Check logs."
            return 1
        fi

        echo "Retry $i/$MAX_RETRIES: Sync=$SYNC, Health=$HEALTH..."
        sleep $SLEEP_TIME
    done

    echo "⌛ Timeout waiting for $APP_NAME"
    return 1
}

#########################
# Prometheus Setup
#########################
cd prometheus
kubectl apply -f application.yaml
echo "**** Deployed prometheus in K8, waiting for app to be synced and ready"

APP_NAME=app-${GROUP}-prometheus
wait_for_argo_app ${APP_NAME} argocd 50

cd ..
kubectl port-forward svc/svc-${GROUP}-prometheus -n ${NS_OBS} 8100:9090 &
echo "**** Connect to prometheus on localhost:8100"

#########################
# Grafana Setup
#########################
cd grafana
kubectl apply -f application.yaml
echo "**** Deployed grafana in K8, waiting for app to be synced and ready"

APP_NAME=app-${GROUP}-grafana
wait_for_argo_app ${APP_NAME} argocd 50

cd ..
kubectl port-forward svc/svc-${GROUP}-grafana -n ${NS_OBS} 8101:3000 &
echo "**** Connect to grafana on localhost:8101"

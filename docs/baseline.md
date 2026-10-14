# Online Boutique Resource Baseline

| Service | Idle CPU | Idle Memory | Load CPU | Load Memory | Requests (CPU/Mem) | Limits (CPU/Mem) |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| frontend | 1m | 45Mi | 38m | 17Mi | 100m / 64Mi | 200m / 128Mi |
| cartservice | 2m | 65Mi | 14m | 66Mi | 200m / 64Mi | 300m / 128Mi |
| productcatalogservice | 1m | 25Mi | 17m | 12Mi | 100m / 64Mi | 200m / 128Mi |
| currencyservice | 1m | 20Mi | 14m | 36Mi | 100m / 64Mi | 200m / 128Mi |
| paymentservice | 1m | 35Mi | 4m | 35Mi | 100m / 64Mi | 200m / 128Mi |
| shippingservice | 1m | 25Mi | 4m | 9Mi | 100m / 64Mi | 200m / 128Mi |
| emailservice | 1m | 20Mi | 6m | 37Mi | 100m / 64Mi | 200m / 128Mi |
| checkoutservice | 1m | 30Mi | 2m | 13Mi | 100m / 64Mi | 200m / 128Mi |
| recommendationservice | 3m | 150Mi | 21m | 32Mi | 200m / 200Mi | 500m / 512Mi |
| adservice | 3m | 100Mi | 3m | 98Mi | 200m / 180Mi | 300m / 300Mi |
| redis-cart | 1m | 10Mi | 4m | 10Mi | 100m / 64Mi | 200m / 128Mi |
| loadgenerator | 0m | 0Mi | 13m | 60Mi | 300m / 300Mi | 500m / 500Mi |
# Online Boutique Architecture Documentation

This document outlines the architecture, service interactions, communication protocols, and runtime dependencies for the **Online Boutique** microservices application. 

## 1. High-Level Architecture Diagram

The architecture consists of a public-facing entry point (**frontend**), a collection of backend business logic microservices interacting exclusively via **gRPC** over protocol buffers, and a stateful data store (**Redis**).

```mermaid
graph TD
    %% Entry Point
    Client((User / Browser)) -->|HTTP / Port 8080| Frontend[frontend <br/> Go]

    %% Frontend calls downstream gRPC services
    Frontend -->|gRPC| ProductCatalog[productcatalogservice <br/> Go]
    Frontend -->|gRPC| Cart[cartservice <br/> C#]
    Frontend -->|gRPC| Currency[currencyservice <br/> Node.js]
    Frontend -->|gRPC| Recommendation[recommendationservice <br/> Python]
    Frontend -->|gRPC| Shipping[shippingservice <br/> Go]
    Frontend -->|gRPC| Ad[adservice <br/> Java]
    Frontend -->|gRPC| Checkout[checkoutservice <br/> Go]

    %% Checkout service orchestration
    Checkout -->|gRPC| Cart
    Checkout -->|gRPC| ProductCatalog
    Checkout -->|gRPC| Currency
    Checkout -->|gRPC| Shipping
    Checkout -->|gRPC| Payment[paymentservice <br/> Node.js]
    Checkout -->|gRPC| Email[emailservice <br/> Python]

    %% Stateful and Support Services
    Cart -->|TCP / Redis Protocol| Redis[(redis-cart <br/> Redis Cache)]
    Frontend -->|gRPC| LoadGen[loadgenerator <br/> Python / Locust]

    subgraph Cluster Boundary
        Frontend
        ProductCatalog
        Cart
        Currency
        Recommendation
        Shipping
        Ad
        Checkout
        Payment
        Email
        Redis
        LoadGen
    k8sConfig[adservice / emailservice / etc. <br/> Configured via env vars]
    end
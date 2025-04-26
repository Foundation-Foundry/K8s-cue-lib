package examples

import (
	"k8s"
)

// Example of a backend web service
backendApi: k8s.WebServer & {
	name:      "backend-api"
	namespace: "backend"
	image:     "company/backend-api:v1.2.3"
	port:      8080
	replicas:  3
	cpu:       "200m"
	memory:    "512Mi"
	
	// Custom health check paths
	livenessPath:  "/health"
	readinessPath: "/readiness"
	
	// Environment variables
	envVars: [
		{
			name:  "LOG_LEVEL"
			value: "info"
		},
		{
			name: "DB_PASSWORD"
			valueFrom: {
				secretKeyRef: {
					name: "backend-db-credentials"
					key:  "password"
				}
			}
		},
	]
}

// Example of a frontend application with CDN and TLS
frontendApp: k8s.FrontendApp & {
	name:       "frontend"
	namespace:  "frontend"
	image:      "company/frontend:v2.0.1"
	port:       80
	replicas:   2
	
	// Ingress configuration
	ingressHost:    "app.example.com"
	tlsEnabled:     true
	tlsSecretName:  "app-example-tls"
	cdnEnabled:     true
	
	// Custom cache settings
	cacheConfig: {
		"/*.js":         "public, max-age=31536000, immutable"
		"/*.css":        "public, max-age=31536000, immutable"
		"/assets/*":     "public, max-age=31536000, immutable"
		"/index.html":   "no-cache"
		"/api/*":        "no-store"
	}
	
	// Environment variables
	envVars: [
		{
			name:  "API_URL"
			value: "https://api.example.com"
		},
		{
			name:  "ENVIRONMENT"
			value: "production"
		},
	]
}
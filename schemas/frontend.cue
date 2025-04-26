// k8s/frontend.cue
package k8s

import (
	"encoding/yaml"
)

// FrontendApp defines an abstraction for front-end web applications with CDN integration
FrontendApp :: WebServer & {
	// Frontend-specific defaults
	cpu:           *"50m" | string
	memory:        *"128Mi" | string
	livenessPath:  *"/health" | string
	readinessPath: *"/health" | string
	startupPath:   *"/health" | string
	
	// CDN and Ingress configuration
	ingressEnabled:       *true | bool
	ingressClass:         *"nginx" | string
	ingressPath:          *"/" | string
	ingressPathType:      *"Prefix" | "Exact" | "ImplementationSpecific"
	ingressHost:          string | *""
	tlsEnabled:           *false | bool
	tlsSecretName:        *"\(name)-tls" | string
	cdnEnabled:           *false | bool
	cdnAnnotations:       *{} | {...}
	securityHeaders:      *true | bool
	cacheConfig:          *{} | {...}
	
	// Default cache configurations for different asset types
	_defaultCacheConfig: {
		"/*.js":     "public, max-age=31536000, immutable"
		"/*.css":    "public, max-age=31536000, immutable"
		"/*.png":    "public, max-age=31536000, immutable"
		"/*.jpg":    "public, max-age=31536000, immutable"
		"/*.svg":    "public, max-age=31536000, immutable"
		"/*.woff2":  "public, max-age=31536000, immutable"
		"/index.html": "public, no-cache"
		"/":         "public, no-cache"
	}
	
	// Default security headers
	_defaultSecurityHeaders: {
		"X-Content-Type-Options":   "nosniff"
		"X-Frame-Options":          "DENY"
		"X-XSS-Protection":         "1; mode=block"
		"Referrer-Policy":          "strict-origin-when-cross-origin"
		"Content-Security-Policy":  "default-src 'self'; img-src 'self' data:; style-src 'self' 'unsafe-inline'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; connect-src 'self' https://*; font-src 'self' data:;"
		"Strict-Transport-Security": "max-age=31536000; includeSubDomains; preload"
	}
	
	// Override deployment template for frontend-specific optimizations
	deployment: {
		apiVersion: "apps/v1"
		kind:       "Deployment"
		metadata: {
			name:        name
			namespace:   namespace
			labels:      labels
			annotations: annotations
		}
		spec: {
			replicas: replicas
			selector: {
				matchLabels: labels
			}
			template: {
				metadata: {
					labels:      labels
					annotations: annotations
				}
				spec: {
					containers: [{
						name:            name
						image:           image
						imagePullPolicy: "IfNotPresent"
						ports: [{
							containerPort: port
							name:          "http"
						}]
						resources:       resources
						securityContext: securityContext
						livenessProbe: {
							httpGet: {
								path: livenessPath
								port: "http"
							}
							initialDelaySeconds: 3  // Shorter for frontends
							periodSeconds:       10
							timeoutSeconds:      2  // Shorter timeout
							failureThreshold:    3
						}
						readinessProbe: {
							httpGet: {
								path: readinessPath
								port: "http"
							}
							initialDelaySeconds: 3  // Shorter for frontends
							periodSeconds:       10
							timeoutSeconds:      2  // Shorter timeout
							failureThreshold:    3
						}
						startupProbe: {
							httpGet: {
								path: startupPath
								port: "http"
							}
							initialDelaySeconds: 3   // Shorter for frontends
							periodSeconds:       5
							timeoutSeconds:      2   // Shorter timeout
							failureThreshold:    10  // Lower for faster startup
						}
						if len(envVars) > 0 {
							env: envVars
						}
						if len(volumeMounts) > 0 {
							volumeMounts: volumeMounts
						}
					}]
					if len(volumes) > 0 {
						volumes: volumes
					}
					if len(nodeSelector) > 0 {
						nodeSelector: nodeSelector
					}
					if len(tolerations) > 0 {
						tolerations: tolerations
					}
				}
			}
		}
	}

	// Conditionally create Ingress resource if enabled
	ingress: ingressEnabled && {
		apiVersion: "networking.k8s.io/v1"
		kind:       "Ingress"
		metadata: {
			name:      name
			namespace: namespace
			labels:    labels
			annotations: {
				"kubernetes.io/ingress.class": ingressClass
				
				// Add cache configuration if enabled
				if len(cacheConfig) > 0 {
					"nginx.ingress.kubernetes.io/configuration-snippet": """
						# Cache configuration
						location ~* \\.(?:css|js|jpg|jpeg|gif|png|ico|cur|gz|svg|svgz|mp4|ogg|ogv|webm|htc|woff2|woff)$ {
						  expires max;
						  add_header Cache-Control "public, max-age=31536000, immutable";
						}
						"""
				}
				
				// Add CDN-specific annotations if enabled
				if cdnEnabled {
					for k, v in cdnAnnotations {
						"\(k)": v
					}
				}
				
				// Add security headers if enabled
				if securityHeaders {
					for k, v in _defaultSecurityHeaders {
						"nginx.ingress.kubernetes.io/configuration-snippet": """
							add_header \(k) "\(v)" always;
							"""
					}
				}
			}
		}
		spec: {
			ingressClassName: ingressClass
			rules: [
				{
					if ingressHost != "" {
						host: ingressHost
					}
					http: {
						paths: [
							{
								path:     ingressPath
								pathType: ingressPathType
								backend: {
									service: {
										name: name
										port: {
											name: "http"
										}
									}
								}
							},
						]
					}
				},
			]
			if tlsEnabled {
				tls: [
					{
						if ingressHost != "" {
							hosts: [ingressHost]
						}
						secretName: tlsSecretName
					},
				]
			}
		}
	}

	// Utility function to output all resources as YAML
	resources: [
		deployment, 
		service, 
		hpa,
		if ingressEnabled {ingress},
	]
	asYAML: yaml.MarshalStream(resources)
}
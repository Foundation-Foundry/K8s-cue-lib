package k8s

import (
	"encoding/yaml"
)

// WebServer defines a common abstraction for stateless web applications
WebServer :: BaseWorkload & {
	// Required port for the web server
	port: int & >0 & <65536
	
	// Optional fields with sensible defaults
	replicas:        *2 | int & >=1
	maxReplicas:     *10 | int & >=replicas
	minReplicas:     *replicas | int & >=1 & <=maxReplicas
	targetCPU:       *80 | int & >=1 & <=100
	livenessPath:    *"/health/live" | string
	readinessPath:   *"/health/ready" | string
	startupPath:     *"/health/startup" | string
	
	// Generated Kubernetes manifests
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
							initialDelaySeconds: 10
							periodSeconds:       10
							timeoutSeconds:      5
							failureThreshold:    3
						}
						readinessProbe: {
							httpGet: {
								path: readinessPath
								port: "http"
							}
							initialDelaySeconds: 5
							periodSeconds:       10
							timeoutSeconds:      5
							failureThreshold:    3
						}
						startupProbe: {
							httpGet: {
								path: startupPath
								port: "http"
							}
							initialDelaySeconds: 5
							periodSeconds:       10
							timeoutSeconds:      5
							failureThreshold:    30
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

	service: {
		apiVersion: "v1"
		kind:       "Service"
		metadata: {
			name:      name
			namespace: namespace
			labels:    labels
		}
		spec: {
			selector: labels
			ports: [{
				port:       80
				targetPort: port
				name:       "http"
			}]
			type: "ClusterIP"
		}
	}

	hpa: {
		apiVersion: "autoscaling/v2"
		kind:       "HorizontalPodAutoscaler"
		metadata: {
			name:      name
			namespace: namespace
			labels:    labels
		}
		spec: {
			scaleTargetRef: {
				apiVersion: "apps/v1"
				kind:       "Deployment"
				name:       name
			}
			minReplicas: minReplicas
			maxReplicas: maxReplicas
			metrics: [{
				type: "Resource"
				resource: {
					name: "cpu"
					target: {
						type:               "Utilization"
						averageUtilization: targetCPU
					}
				}
			}]
		}
	}

	// Utility function to output all resources as YAML
	resources: [deployment, service, hpa]
	asYAML:    yaml.MarshalStream(resources)
}
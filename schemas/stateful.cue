// k8s/stateful.cue
package k8s

import (
	"encoding/yaml"
)

// StatefulApp defines an abstraction for stateful applications
StatefulApp :: BaseWorkload & {
	// Required port for the stateful app
	port: int & >0 & <65536
	
	// Optional fields with sensible defaults
	replicas:        *1 | int & >=1  // Default to 1 for stateful apps
	serviceType:     *"ClusterIP" | "NodePort" | "LoadBalancer" | "ExternalName"
	livenessPath:    *"/health/live" | string
	readinessPath:   *"/health/ready" | string
	startupPath:     *"/health/startup" | string
	podManagementPolicy: *"OrderedReady" | "Parallel"
	updateStrategy:     *"RollingUpdate" | "OnDelete"
	persistentVolumeEnabled: *true | bool
	volumeSize:        *"10Gi" | string
	storageClassName:  *"standard" | string
	volumeMode:        *"Filesystem" | "Block"
	accessModes:       *["ReadWriteOnce"] | [...string]
	
	// Override security context for stateful apps
	securityContext: *{
		runAsNonRoot:             true
		runAsUser:                1000
		allowPrivilegeEscalation: false
		capabilities: {
			drop: ["ALL"]
		}
		readOnlyRootFilesystem: false  // Often stateful apps need to write to disk
		seccompProfile: {
			type: "RuntimeDefault"
		}
	} | {...}
	
	// Generated StatefulSet resource
	statefulSet: {
		apiVersion: "apps/v1"
		kind:       "StatefulSet"
		metadata: {
			name:        name
			namespace:   namespace
			labels:      labels
			annotations: annotations
		}
		spec: {
			serviceName:         name
			replicas:            replicas
			podManagementPolicy: podManagementPolicy
			updateStrategy: {
				type: updateStrategy
			}
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
							initialDelaySeconds: 30  // Longer for stateful apps
							periodSeconds:       10
							timeoutSeconds:      5
							failureThreshold:    3
						}
						readinessProbe: {
							httpGet: {
								path: readinessPath
								port: "http"
							}
							initialDelaySeconds: 10
							periodSeconds:       10
							timeoutSeconds:      5
							failureThreshold:    3
						}
						startupProbe: {
							httpGet: {
								path: startupPath
								port: "http"
							}
							initialDelaySeconds: 30  // Longer for stateful apps
							periodSeconds:       10
							timeoutSeconds:      5
							failureThreshold:    30
						}
						if len(envVars) > 0 {
							env: envVars
						}
						volumeMounts: persistentVolumeEnabled && [
							{
								name:      "data"
								mountPath: "/data"
							},
						] + volumeMounts
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
			if persistentVolumeEnabled {
				volumeClaimTemplates: [
					{
						metadata: {
							name: "data"
						}
						spec: {
							accessModes: accessModes
							volumeMode:  volumeMode
							resources: {
								requests: {
									storage: volumeSize
								}
							}
							storageClassName: storageClassName
						}
					},
				]
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
				port:       port
				targetPort: port
				name:       "http"
			}]
			type: serviceType
			// For StatefulSets, headless service is often useful
			if serviceType == "ClusterIP" {
				clusterIP: "None"
			}
		}
	}

	// Utility function to output all resources as YAML
	resources: [statefulSet, service]
	asYAML:    yaml.MarshalStream(resources)
}
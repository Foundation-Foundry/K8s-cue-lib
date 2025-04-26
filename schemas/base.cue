package k8s

import (
	"encoding/yaml"
	"strings"
)

// BaseResource provides common fields for all Kubernetes resources
BaseResource :: {
	// Required fields
	name:      string & !=""
	namespace: string & !=""
	
	// Optional fields with sensible defaults
	labels: *{
		app: name
	} | {...}
	annotations: *{} | {...}
}

// BaseWorkload extends BaseResource with common workload configurations
BaseWorkload :: BaseResource & {
	// Required fields
	image: string & !=""
	
	// Common optional fields with sensible defaults
	cpu:          *"100m" | string
	memory:       *"256Mi" | string
	envVars:      *[] | [...{name: string, value?: string, valueFrom?: {...}}]
	volumes:      *[] | [...]
	volumeMounts: *[] | [...]
	nodeSelector: *{} | {...}
	tolerations:  *[] | [...]
	
	// Security defaults
	securityContext: *_defaultSecurityContext | {...}
	
	// Resource configuration
	resources: *{
		limits: {
			cpu:    *cpu | string
			memory: *memory | string
		}
		requests: {
			cpu:    *"\(strings.Split(cpu, "m")[0])/2m" | string
			memory: *"\(strings.Split(memory, "Mi")[0])/2Mi" | string
		}
	} | {...}
	
	// Default security context with best practices
	_defaultSecurityContext: {
		runAsNonRoot:             true
		runAsUser:                1000
		allowPrivilegeEscalation: false
		capabilities: {
			drop: ["ALL"]
		}
		readOnlyRootFilesystem: true
		seccompProfile: {
			type: "RuntimeDefault"
		}
	}
}

// BaseContainerSpec defines common container configurations
BaseContainerSpec :: {
	name:            string
	image:           string
	imagePullPolicy: *"IfNotPresent" | "Always" | "Never"
	resources:       {...}
	securityContext: {...}
	if len(_envVars) > 0 {
		env: _envVars
	}
	if len(_volumeMounts) > 0 {
		volumeMounts: _volumeMounts
	}
	_envVars:      [...{...}]
	_volumeMounts: [...{...}]
}

// Generates a service for the given selector and port
ServiceFor :: {
	name:      string
	namespace: string
	selector:  {...}
	port:      int
	targetPort: *port | int
	serviceType: *"ClusterIP" | "NodePort" | "LoadBalancer" | "ExternalName"
	
	// Generated service
	service: {
		apiVersion: "v1"
		kind:       "Service"
		metadata: {
			name:      name
			namespace: namespace
			labels: {
				app: name
			}
		}
		spec: {
			selector: selector
			ports: [{
				port:       port
				targetPort: targetPort
				name:       "http"
			}]
			type: serviceType
		}
	}
}

// Utility function to combine multiple Kubernetes resources into a single YAML stream
CombineResources :: {
	resources: [...]
	asYAML: yaml.MarshalStream(resources)
}
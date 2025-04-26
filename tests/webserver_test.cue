package tests

import (
	"github.com/foundation-foundry/k8s-cue-lib/schemas"
)

// Test suite for the WebServer abstraction
webServerTests: TestSuite & {
	name: "WebServer Tests"
	tests: [
		// Test default configuration generates valid resources
		{
			name: "Default WebServer Configuration"
			resource: schemas.WebServer & {
				name:      "test-webserver"
				namespace: "default"
				image:     "nginx:latest"
				port:      80
			}
			assertions: [
				// Verify Deployment
				assertions.hasApiVersion(version: "apps/v1"),
				assertions.hasKind(kind: "Deployment"),
				assertions.fieldExists(fieldPath: "metadata.name"),
				assertions.fieldEquals(fieldPath: "metadata.name", value: "test-webserver"),
				assertions.fieldEquals(fieldPath: "metadata.namespace", value: "default"),
				assertions.fieldEquals(fieldPath: "spec.replicas", value: 2),  // Default replicas
				assertions.hasContainerImage(image: "nginx:latest"),
				assertions.hasSecureContainerContext,
				assertions.fieldExists(fieldPath: "spec.template.spec.containers.0.livenessProbe"),
				assertions.fieldExists(fieldPath: "spec.template.spec.containers.0.readinessProbe"),
				assertions.fieldExists(fieldPath: "spec.template.spec.containers.0.startupProbe"),
			]
		},
		
		// Test custom configuration is applied correctly
		{
			name: "Custom WebServer Configuration"
			resource: schemas.WebServer & {
				name:          "custom-webserver"
				namespace:     "production"
				image:         "myapp:v1.2.3"
				port:          8080
				replicas:      5
				cpu:           "500m"
				memory:        "1Gi"
				livenessPath:  "/healthz"
				readinessPath: "/ready"
				startupPath:   "/startup"
				envVars: [
					{
						name:  "ENV"
						value: "production"
					},
				]
			}
			assertions: [
				// Verify custom values are applied
				assertions.fieldEquals(fieldPath: "metadata.name", value: "custom-webserver"),
				assertions.fieldEquals(fieldPath: "metadata.namespace", value: "production"),
				assertions.fieldEquals(fieldPath: "spec.replicas", value: 5),
				assertions.hasContainerImage(image: "myapp:v1.2.3"),
				assertions.fieldEquals(fieldPath: "spec.template.spec.containers.0.resources.limits.cpu", value: "500m"),
				assertions.fieldEquals(fieldPath: "spec.template.spec.containers.0.resources.limits.memory", value: "1Gi"),
				assertions.fieldEquals(fieldPath: "spec.template.spec.containers.0.livenessProbe.httpGet.path", value: "/healthz"),
				assertions.fieldEquals(fieldPath: "spec.template.spec.containers.0.readinessProbe.httpGet.path", value: "/ready"),
				assertions.fieldEquals(fieldPath: "spec.template.spec.containers.0.startupProbe.httpGet.path", value: "/startup"),
				assertions.fieldExists(fieldPath: "spec.template.spec.containers.0.env"),
				assertions.fieldEquals(fieldPath: "spec.template.spec.containers.0.env.0.name", value: "ENV"),
				assertions.fieldEquals(fieldPath: "spec.template.spec.containers.0.env.0.value", value: "production"),
			]
		},
		
		// Test Service configuration
		{
			name: "WebServer Service Configuration"
			resource: (schemas.WebServer & {
				name:      "test-webserver"
				namespace: "default"
				image:     "nginx:latest"
				port:      80
			}).service
			assertions: [
				assertions.hasApiVersion(version: "v1"),
				assertions.hasKind(kind: "Service"),
				assertions.fieldEquals(fieldPath: "metadata.name", value: "test-webserver"),
				assertions.fieldEquals(fieldPath: "metadata.namespace", value: "default"),
				assertions.serviceSelectsApp(appName: "test-webserver"),
				assertions.fieldEquals(fieldPath: "spec.ports.0.port", value: 80),
				assertions.fieldEquals(fieldPath: "spec.ports.0.targetPort", value: 80),
				assertions.fieldEquals(fieldPath: "spec.type", value: "ClusterIP"),
			]
		},
		
		// Test HPA configuration
		{
			name: "WebServer HPA Configuration"
			resource: (schemas.WebServer & {
				name:      "test-webserver"
				namespace: "default"
				image:     "nginx:latest"
				port:      80
				maxReplicas: 5
				minReplicas: 2
				targetCPU:   70
			}).hpa
			assertions: [
				assertions.hasApiVersion(version: "autoscaling/v2"),
				assertions.hasKind(kind: "HorizontalPodAutoscaler"),
				assertions.fieldEquals(fieldPath: "metadata.name", value: "test-webserver"),
				assertions.fieldEquals(fieldPath: "metadata.namespace", value: "default"),
				assertions.hpaReferencesDeployment(deploymentName: "test-webserver"),
				assertions.fieldEquals(fieldPath: "spec.minReplicas", value: 2),
				assertions.fieldEquals(fieldPath: "spec.maxReplicas", value: 5),
				assertions.fieldEquals(fieldPath: "spec.metrics.0.resource.target.averageUtilization", value: 70),
			]
		},
	]
}

// Run tests and print results
webServerTestResults: webServerTests.run
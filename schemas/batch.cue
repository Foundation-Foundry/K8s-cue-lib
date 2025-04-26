// k8s/batch.cue
package k8s

import (
	"encoding/yaml"
)

// BatchJob defines an abstraction for one-time batch jobs
BatchJob :: BaseWorkload & {
	// Required command to run
	command: [...string] & !=[...]
	
	// Optional fields with sensible defaults
	backoffLimit:            *3 | int & >=0
	activeDeadlineSeconds:   *3600 | int & >=0  // 1 hour default timeout
	restartPolicy:           *"OnFailure" | "Never"
	ttlSecondsAfterFinished: *3600 | int & >=0  // Clean up after 1 hour
	completions:             *1 | int & >=1
	parallelism:             *1 | int & >=1
	
	// Generated Job resource
	job: {
		apiVersion: "batch/v1"
		kind:       "Job"
		metadata: {
			name:        name
			namespace:   namespace
			labels:      labels
			annotations: annotations
		}
		spec: {
			ttlSecondsAfterFinished: ttlSecondsAfterFinished
			backoffLimit:            backoffLimit
			activeDeadlineSeconds:   activeDeadlineSeconds
			completions:             completions
			parallelism:             parallelism
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
						command:         command
						resources:       resources
						securityContext: securityContext
						if len(envVars) > 0 {
							env: envVars
						}
						if len(volumeMounts) > 0 {
							volumeMounts: volumeMounts
						}
					}]
					restartPolicy: restartPolicy
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

	// Utility function to output all resources as YAML
	resources: [job]
	asYAML:    yaml.MarshalStream(resources)
}
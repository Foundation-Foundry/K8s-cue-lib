package k8s

import (
	"encoding/yaml"
)

// CronJob defines an abstraction for scheduled batch jobs
CronJob :: BaseWorkload & {
	// Required schedule in cron format
	schedule: string & !=""
	
	// Required command to run
	command: [...string] & !=[...]
	
	// Optional fields with sensible defaults
	concurrencyPolicy:    *"Forbid" | "Allow" | "Replace"
	failedJobsHistoryLimit:    *3 | int & >=0
	successfulJobsHistoryLimit: *3 | int & >=0
	startingDeadlineSeconds:   *60 | int & >=0
	backoffLimit:              *3 | int & >=0
	activeDeadlineSeconds:     *3600 | int & >=0  // 1 hour default timeout
	restartPolicy:             *"OnFailure" | "Never"
	ttlSecondsAfterFinished:   *3600 | int & >=0  // Clean up after 1 hour
	completions:               *1 | int & >=1
	parallelism:               *1 | int & >=1
	suspend:                   *false | bool
	
	// Generated CronJob resource
	cronJob: {
		apiVersion: "batch/v1"
		kind:       "CronJob"
		metadata: {
			name:        name
			namespace:   namespace
			labels:      labels
			annotations: annotations
		}
		spec: {
			schedule:                   schedule
			concurrencyPolicy:          concurrencyPolicy
			failedJobsHistoryLimit:     failedJobsHistoryLimit
			successfulJobsHistoryLimit: successfulJobsHistoryLimit
			startingDeadlineSeconds:    startingDeadlineSeconds
			suspend:                    suspend
			jobTemplate: {
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
		}
	}

	// Utility function to output all resources as YAML
	resources: [cronJob]
	asYAML:    yaml.MarshalStream(resources)
}
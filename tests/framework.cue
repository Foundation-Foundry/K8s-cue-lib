package tests

import (
	"list"
	"strings"
	"encoding/yaml"
)

// TestSuite represents a collection of tests
TestSuite :: {
	name:  string
	tests: [TestCase, ...TestCase]
	
	// Run all tests in the suite and collect results
	run: {
		results: [ for t in tests {t.run} ]
		passed:  list.Count(results, true)
		failed:  list.Count(results, false)
		success: failed == 0
		
		// Summary information
		summary: "\(name): \(passed)/\(passed + failed) tests passed"
		details: strings.Join([ for i, t in tests {
			if t.run {
				"✅ PASS: \(t.name)"
			} else {
				"❌ FAIL: \(t.name) - \(t.failReason)"
			}
		}], "\n") 
	}
}

// TestCase represents a single test
TestCase :: {
	name:       string
	resource:   _  // The resource to test
	assertions: [Assertion, ...Assertion]
	
	// Run the test and check all assertions
	run: list.Contains(assertionResults, false) == false
	
	// Track assertion results
	assertionResults: [ for a in assertions {a.check(resource)} ]
	
	// Collect failure reasons
	_failureIndexes: [ for i, result in assertionResults if result == false {i} ]
	_failureReasons: [ for i in _failureIndexes {assertions[i].failureReason(resource)} ]
	failReason:      strings.Join(_failureReasons, "; ")
	
	// Optional: Generate YAML for debugging
	yaml: yaml.Marshal(resource)
}

// Assertion represents a test assertion
Assertion :: {
	name:  string
	check: resource: _ => bool
	failureReason: resource: _ => string
}

// Common assertions
assertions: {
	// Check if a field exists and is not empty
	fieldExists: fieldPath: string => {
		name: "Field \(fieldPath) exists"
		check: resource: {
			parts: strings.Split(fieldPath, ".")
			
			// This is a recursive function to check nested fields
			_checkField: {
				obj: _
				path: [...string]
				index: int
				
				// Base case: we've reached the end of the path
				if index >= len(path) {
					result: true
				}
				
				// Check if current field exists
				if index < len(path) {
					currentField: path[index]
					if obj[currentField] != _|_ {
						// Field exists, recurse to next level if needed
						if (index + 1) < len(path) {
							// More path to traverse, and current field is an object
							if (type(obj[currentField]) == "struct") {
								child: _checkField & {
									obj:   obj[currentField]
									path:  path
									index: index + 1
								}
								result: child.result
							} else {
								// Field exists but isn't an object and we need to go deeper
								result: false
							}
						} else {
							// End of path and field exists
							result: true
						}
					} else {
						// Field doesn't exist
						result: false
					}
				}
			}
			
			// Start recursion at the root object
			check: _checkField & {
				obj:   resource
				path:  parts
				index: 0
			}
			
			check.result
		}
		failureReason: resource: "Field \(fieldPath) is missing"
	}
	
	// Check if a field has a specific value
	fieldEquals: {
		fieldPath: string
		value:     _
	} => {
		name: "Field \(fieldPath) equals \(value)"
		check: resource: {
			parts: strings.Split(fieldPath, ".")
			
			// This is a recursive function to check nested fields
			_checkField: {
				obj: _
				path: [...string]
				index: int
				
				// Base case: we've reached the end of the path
				if index >= len(path) {
					result: obj == value
				}
				
				// Check if current field exists
				if index < len(path) {
					currentField: path[index]
					if obj[currentField] != _|_ {
						// Field exists, recurse to next level if needed
						if (index + 1) < len(path) {
							// More path to traverse, and current field is an object
							if (type(obj[currentField]) == "struct") {
								child: _checkField & {
									obj:   obj[currentField]
									path:  path
									index: index + 1
								}
								result: child.result
							} else {
								// Field exists but isn't an object and we need to go deeper
								result: false
							}
						} else {
							// End of path, check value
							result: obj[currentField] == value
						}
					} else {
						// Field doesn't exist
						result: false
					}
				}
			}
			
			// Start recursion at the root object
			check: _checkField & {
				obj:   resource
				path:  parts
				index: 0
			}
			
			check.result
		}
		failureReason: resource: "Field \(fieldPath) does not equal \(value)"
	}
	
	// Check if the resource has the correct API version
	hasApiVersion: version: string => {
		name: "Has API version \(version)"
		check: resource: resource.apiVersion == version
		failureReason: resource: "Expected apiVersion \(version), got \(resource.apiVersion)"
	}
	
	// Check if the resource has the correct kind
	hasKind: kind: string => {
		name: "Has kind \(kind)"
		check: resource: resource.kind == kind
		failureReason: resource: "Expected kind \(kind), got \(resource.kind)"
	}
	
	// Check if the resource has a container with given image
	hasContainerImage: image: string => {
		name: "Has container with image \(image)"
		check: resource: {
			// Different resource kinds store containers in different paths
			if resource.kind == "Deployment" {
				containers: resource.spec.template.spec.containers
			}
			if resource.kind == "StatefulSet" {
				containers: resource.spec.template.spec.containers
			}
			if resource.kind == "Pod" {
				containers: resource.spec.containers
			}
			if resource.kind == "CronJob" {
				containers: resource.spec.jobTemplate.spec.template.spec.containers
			}
			if resource.kind == "Job" {
				containers: resource.spec.template.spec.containers
			}
			
			hasImage: false
			for c in containers {
				if c.image == image {
					hasImage: true
				}
			}
			hasImage
		}
		failureReason: resource: "No container with image \(image) found"
	}
	
	// Check if the resource has security context with required settings
	hasSecureContainerContext: {
		name: "Has secure container security context"
		check: resource: {
			// Different resource kinds store containers in different paths
			if resource.kind == "Deployment" {
				containers: resource.spec.template.spec.containers
			}
			if resource.kind == "StatefulSet" {
				containers: resource.spec.template.spec.containers
			}
			if resource.kind == "Pod" {
				containers: resource.spec.containers
			}
			if resource.kind == "CronJob" {
				containers: resource.spec.jobTemplate.spec.template.spec.containers
			}
			if resource.kind == "Job" {
				containers: resource.spec.template.spec.containers
			}
			
			isSecure: true
			for c in containers {
				if c.securityContext == _|_ {
					isSecure: false
				}
				if c.securityContext.runAsNonRoot == _|_ || !c.securityContext.runAsNonRoot {
					isSecure: false
				}
				if c.securityContext.allowPrivilegeEscalation == _|_ || c.securityContext.allowPrivilegeEscalation {
					isSecure: false
				}
				if c.securityContext.capabilities == _|_ || c.securityContext.capabilities.drop == _|_ || !list.Contains(c.securityContext.capabilities.drop, "ALL") {
					isSecure: false
				}
			}
			isSecure
		}
		failureReason: resource: "Container security context is not secure"
	}
	
	// Check if service has correct selector
	serviceSelectsApp: appName: string => {
		name: "Service selects app \(appName)"
		check: resource: {
			if resource.kind != "Service" {
				false
			} else {
				resource.spec.selector.app == appName
			}
		}
		failureReason: resource: "Service does not select app \(appName)"
	}
	
	// Check if HPA references correct resource
	hpaReferencesDeployment: deploymentName: string => {
		name: "HPA references deployment \(deploymentName)"
		check: resource: {
			if resource.kind != "HorizontalPodAutoscaler" {
				false
			} else {
				resource.spec.scaleTargetRef.name == deploymentName &&
				resource.spec.scaleTargetRef.kind == "Deployment"
			}
		}
		failureReason: resource: "HPA does not reference deployment \(deploymentName)"
	}
}
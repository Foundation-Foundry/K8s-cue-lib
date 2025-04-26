package k8s

// Re-export all schemas from the library
import (
    "github.com/foundation-foundry/k8s-cue-lib/schemas"
)

// Re-export all public types
BaseResource: schemas.BaseResource
BaseWorkload: schemas.BaseWorkload
WebServer: schemas.WebServer
FrontendApp: schemas.FrontendApp
CronJob: schemas.CronJob
BatchJob: schemas.BatchJob
StatefulApp: schemas.StatefulApp
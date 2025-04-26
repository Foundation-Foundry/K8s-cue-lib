package example
// Example of a daily backup cron job
backupJob: schemas.CronJob & {
	name:      "daily-backup"
	namespace: "backup"
	image:     "company/backup-tool:v1.0.0"
	schedule:  "0 2 * * *"  // Run at 2 AM daily
	command:   ["/bin/sh", "-c", "/backup.sh"]
	
	// Resource requirements
	cpu:    "100m"
	memory: "256Mi"
}
# Steps to disable java dynamic attachment

#### Remove on-host integration file
Remove the configuration found at:
`/etc/newrelic-infra/integrations.d/java-dynamic-attach.yml`

This will stop any new java (currently only Tomcat) processes from being

#### Restart any Tomcat processes that have been instrumented
After removing the on-host integration file, you must restart any existing Tomcat processes that have been instrumented dynamically to stop data from being sent to New Relic.

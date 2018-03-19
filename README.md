# Overview
This repo contains the policies and scripts for deploying [Cloud Custodian](https://developer.capitalone.com/opensource-projects/cloud-custodian)

# Deploy
To deploy the policies as lambda functions and configure the mailer (for notifications) as a lambda function, run `make deploy`

# Policies
All yaml files in the `policies/` directory will be automatically applied.  Currently, all are configured to have a 24 hour grace period with notifications happening every morning at 12:30AM UTC and deletions happening every evening at 11:30PM UTC.

To validate all policies, run: `make`

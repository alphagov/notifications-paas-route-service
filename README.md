# Notify PaaS Route Service

This is a Nginx application which is a proxy for all apps that run on the PaaS and restricts access to them by IP address.

If a user's IP address is not in our allowed list then we can instead allow access using a username and password.

We currently use this in preview and staging to make sure only our team can access our preview and staging environments.

## Requirements

* Cloud Foundry CLI (https://docs.cloudfoundry.org/cf-cli/install-go-cli.html)
* Jinja CLI. You can install this using `pip install jinja2-cli`.

## Deployment

The default application name is "route-service". If you want to change this (or you want to deploy multiple route services), set the PAAS_APP_NAME environment variable for the make commands.

The default domain name is "cloudapps.digital". If you want to change this (or you want to bind to different domains), set the PAAS_DOMAIN environment variable for the make commands.

The secret values are read from the notifications-credentials repository using pass, so you have to set the NOTIFY_CREDENTIALS environment variable to your local credentials repository path. The values are read from `credentials/http_auth/notify/password`.

The instance count can be set with the PAAS_INSTANCES environment variable (1 by default).

## Deploying the route service application

If you're deploying the very first time, simply run:

```
make <PaaS space> cf-push
```

For zero-downtime deployments use the following command:

```
make <PaaS space> cf-deploy
```

If the zero-downtime deployment couldn't finish you can rollback to the previous version:

```
make <PaaS space> cf-rollback
```

## Registering the application as a user-provided service

You only need to do this once per PaaS space.

```
make <PaaS space> cf-create-route-service
```

## Register the application as a route-service for a route

You only need to do this once per PaaS space and for all routes.

```
make <PaaS space> <app_name> cf-bind-route-service
```

Where `app_name` either `admin` or `api` which will bind the `www.` or `api.` subdomain respectively.

## Complete installation example

In this example we are deploying the route service to preview and binding two applications to it, which are accessible on app-01.cloudapps.digital and app-02.cloudapps.digital.

```
# First installation:
make preview paas-push
make preview paas-create-route-service

# Run this for every applicaton once
make preview paas-bind-route-service PAAS_ROUTE=app-01
make preview paas-bind-route-service PAAS_ROUTE=app-02

# For any future deployments only run:
make preview paas-deploy
```

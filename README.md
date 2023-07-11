# Red Hat Single Sign-On

This excerpt covers the installation process of the **Red Hat Single SignOn 7.6** product and its necessary configurations.
The RH-SSO instance will be connected to an external Oracle 19C Database. For that reason we need to install and configure the proper oracle driver.


--------------------------------------
# Prerequisites

- Import the base image of RH-SSO 7.6
```
$ oc import-image rh-sso-7/sso76-openshift-rhel8:7.6-24 --from=registry.redhat.io/rh-sso-7/sso76-openshift-rhel8:7.6-24 --confirm
```

If we need to have the base image available for all projects it is necesary to add '-n openshift'


# Install a customized RH-SSO 7.6 from scratch.

1) Login in the cluster and set environments vars:

```
$ oc login --token=$CLUSTER_TOKEN --server=https://$OCP_CLUSTER_URL:6443
```
```
$ export SSO_PROJECT=rhsso-dev   (<= NAMESPACE)
$ oc new-project $SSO_PROJECT
```

2) Go to downloaded folder and run a build:
cd /$REPO_GIT

3) Create a Configmap to customize Database URL 'sso-database-cm':
```
$ oc create -f ./artifacts/database/sso-database-cm.yaml
```

3) Create a Secret to set the Database credentials 'sso-database-secret':
```
$ oc create -f ./artifacts/database/sso-database-secret.yaml
```

4) Create the BuildConfig:
```
$ oc new-build --name rhsso --binary --strategy docker
```

5) We build the custom image with previuos BC and the content of current folder:
```
$ oc start-build rhsso --from-dir . --follow
```

### NOTA: 
When build process is launched (with previuos command), configuration defined on ./extensions/actions.cli will be included.
With this component all directives needed to customize our RHSSO instance (through 'jboss-cli' tool) will be applied. 
Custom values will be inyected using the ConfigMap(DB_JDBC_URL) and Secret(DB_USERNAME and DB_PASSWORD) created previously.



### JBOSS-CLI commands:
```
/subsystem=datasources/jdbc-driver=$DB_DRIVER_NAME:add( \
    driver-name=$DB_DRIVER_NAME, \
    driver-module-name=$DB_EAP_MODULE, \
    driver-xa-datasource-class-name=$DB_XA_DRIVER \
)

/subsystem=datasources/data-source=KeycloakDS:remove()
 
/subsystem=datasources/data-source=KeycloakDS:add( \
    jndi-name=java:jboss/datasources/KeycloakDS, \
    enabled=true, \
    use-java-context=true, \
    connection-url=$DB_JDBC_URL, \
    driver-name=$DB_DRIVER_NAME, \
    user-name=$DB_USERNAME, \
    password=$DB_PASSWORD \
)
```

6) Import the RH-SSO 7.6 (if not present on cluster):
https://github.com/jboss-container-images/redhat-sso-7-openshift-image/blob/sso76-dev/docs/templates/reencrypt/ocp-4.x/sso76-ocp4-x509-https.adoc
```
$ oc create -f ./artifacts/ocp/sso76-ocp4-x509-https.json -n openshift
```


7) Create a SSO DeploymentConfig with the previous template. We should define User admin (and Password) to manage the RH-SSO instance.
```
$ oc new-app --template=sso76-ocp4-x509-https \
        --param=SSO_ADMIN_USERNAME=admin \
        --param=SSO_ADMIN_PASSWORD="redhat01"
```

8) --PENDING-- Mount the Configmap as a volume:
```
$ oc set volume dc/sso --add --name=mtls-endpoints-aliases-cm --mount-path /opt/eap/extensions/mtls_custom.json --sub-path mtls_custom.json --source='{"configMap":{"name":"mtls-endpoints-aliases-cm","items":[{"key":"mtls_custom.json","path":"mtls_custom.json"}]}}' -n $SSO_PROJECT
```

9) --NOT NECESARY-- Actualizo el 'initialDelaySeconds' del livenessProbe para que tenga mas tiempo el primer deploy: lo paso de 60 a 600 segundos.
```
$ oc patch dc/sso -p '{"spec":{"template": {"spec": {"containers":[{"name": "sso","livenessProbe": {"initialDelaySeconds":'600'}}]}}}}' -n ${SSO_PROJECT}
```

10) --PENDING-- Actualizo la IMAGEN BASE a utilizar durante el despliegue.
The original template shows "namespace": "openshift" and ImageStreamTag "name": "sso76-openshift-rhel8:7.6-24".
```
$ oc patch dc/sso -p '{"spec": {
    "triggers": [
      {
        "type": "ImageChange",
        "imageChangeParams": {
          "automatic": true,
          "containerNames": [
            "sso"
          ],
          "from": {
            "kind": "ImageStreamTag",
            "namespace": "rhn-gps-splatas-dev",
            "name": "rhsso:latest"
          }
        }
      }
    ]
  }
  }' -n $SSO_PROJECT
```

11) --PENDING-- Si no se desplegó automáticamente, lanzo el despliegue del DC:
```
$ oc rollout latest dc/sso
```

--------------------
POST CONFIGURACIONES
--------------------
A) ------>    HECHO EN EL PASO 10.   <------

  Hacer un override del deployment para agregar la imagen nueva:
  OJO EL NAMESPACE: dice 'openshift' pero puede estar en el NAMESPACE de la instalación.
  ----------------
  - type: ImageChange
    imageChangeParams:
      automatic: true
      containerNames:
        - sso
      from:
        kind: ImageStreamTag
        namespace: openshift  <== $SSO_PROJECT
        name: 'rhsso:latest'
      lastTriggeredImage: >-
     image-registry.openshift-image-registry.svc:5000/rh-sso/rhsso@sha256:3bd57de93a781e1633919dc26e189a665ca28dad20912136851df3fd0f87f156
  - type: ConfigChange


B)  ------>    HECHO EN EL PASO 9.   <------ 
Actualizar los healthchecks
SI ERROR EN PRIMER DEPLOY (TIMEOUT): Actualizar el DC livenessProbe / initialDelaySeconds: 60 => 600 

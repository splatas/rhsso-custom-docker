# Red Hat Single Sign-On in Openshift 

This excerpt covers the installation process of the **Red Hat Single SignOn 7.6 in an Openshift platform** and its necessary configurations.
The RH-SSO instance will be connected to an external Oracle 19C Database. For that reason we need to install and configure the proper oracle driver.


--------------------------------------
# Prerequisites

- Import the base image of RH-SSO 7.6 (if not present in the installation Cluster)
```
$ oc import-image rh-sso-7/sso76-openshift-rhel8:7.6-24 --from=registry.redhat.io/rh-sso-7/sso76-openshift-rhel8:7.6-24 --confirm
```

If we need to have the base image available for all projects it is necesary to add '-n openshift'


# Install a customized RH-SSO 7.6 from scratch.

## 1. Login in the cluster and set environments vars

```
$ oc login --token=$CLUSTER_TOKEN --server=https://$OCP_CLUSTER_URL:6443
```

```
$ export SSO_PROJECT=rhsso-dev   (<= CHANGE NAMESPACE)
$ oc new-project $SSO_PROJECT
```

## 2. Go to repository folder
```
$ cd rhsso-custom-docker
```

## 3. Import the Custom RH-SSO 7.6 Template
  This template has the following changes:
    - DeploymentConfig: 
        - Reference to ConfigMap 'sso-database-cm'
        - Reference to Secret 'sso-database-secret'
        - Reference to ConfigMap 'actions-cli-cm'
        - Mount volume (ConfigMap 'actions-cli-cm')
        - Reference to custom Image: 'rhsso:latest'

```
$ oc create -f ./artifacts/ocp/sso76-ocp4-x509-https-custom.json \
    -n openshift
```

  ##### NEXT COMMAND IS NOT NECESARY: Original RH-SSO 7.6  Template (only for reference) 
  https://github.com/jboss-container-images/redhat-sso-7-openshift-image/blob/sso76-dev/docs/templates/reencrypt/ocp-4.x/sso76-ocp4-x509-https.adoc
      
  ```
  $ oc create -f ./artifacts/ocp/sso76-ocp4-x509-https.json -n openshift
  ```

## 4. Create the BuildConfig
```
$ oc new-build --name rhsso --binary --strategy docker
```

## 5. Build the custom image with previuos BC and the content of current folder
```
$ oc start-build rhsso --from-dir . --follow
```

### NOTES 
When build process is launched (with previuos command), configuration defined on ./extensions/actions.cli will be included.
With this component all directives needed to customize our RHSSO instance (through 'jboss-cli' tool) will be applied. 
Custom values will be inyected using the ConfigMap(DB_JDBC_URL) and Secret(DB_USERNAME and DB_PASSWORD) created previously.


#### Detailed JBOSS-CLI commands applied
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

## 6. Create a SSO instance with the previous template. We should define User admin (and Password) to manage the RH-SSO instance.

Params:
  IMAGE_STREAM_NAMESPACE = Namespace where custom image will be persisted (current namespace?)

  ```
  $ oc new-app --template=sso76-ocp4-x509-https-custom \
          --param=SSO_ADMIN_USERNAME=admin \
          --param=SSO_ADMIN_PASSWORD="redhat01" \
          --param=IMAGE_STREAM_NAMESPACE=rhn-gps-splatas-dev
  ```


---

# Appendix

There are several single commands that are not necessary to run, due to were applied on Custom Template.
The are here only for reference.

A) Create a Configmap to customize Database URL 'sso-database-cm' and to apply actions.cli modifications:

  ##### NEXT COMMAND IS NOT NECESARY: INCLUDED IN CUSTOM TEMPLATE
  ```
  $ oc create -f ./artifacts/database/sso-database-cm.yaml
  ```

  ##### NEXT COMMAND IS NOT NECESARY: INCLUDED IN CUSTOM TEMPLATE
  ```
  $ oc create -f ./artifacts/ocp/actions-cli-cm.yaml 
  ```

B) Create a Secret to set the Database credentials 'sso-database-secret'.
   IMPORTANT!
   Values must be Base64 encoded (https://www.base64decode.org/): 
  
  ##### NEXT COMMAND IS NOT NECESARY: INCLUDED IN CUSTOM TEMPLATE
  ```
  $ oc create -f ./artifacts/database/sso-database-secret.yaml
  ```

C) Mount the Configmap 'actions-cli-cm' as a volume:

  ###  NOT NECESARY: INCLUDED IN CUSTOM TEMPLATE
  ```
  $ oc set volume dc/sso --add --name=actions-cli-cm --mount-path /opt/eap/extensions/actions.cli --sub-path actions.cli --source='{"configMap":{"name":"actions-cli-cm","items":[{"key":"actions.cli","path":"actions.cli"}]}}' -n $SSO_PROJECT
  ```


  C.1) Mount the Configmap 'logging-messages-pl-cm' as a volume:

  ###  NOT NECESARY: INCLUDED IN CUSTOM TEMPLATE

  ```
  $ oc set volume dc/sso --add --name=logging-messages-pl-cm --mount-path /opt/eap/themes/mytheme/login/messages/messages_pl.properties --sub-path messages_pl.properties --source='{"configMap":{"name":"logging-messages-pl-cm","items":[{"key":"messages_pl.properties","path":"messages_pl.properties"}]}}' -n $SSO_PROJECT
  ```

D) Update 'initialDelaySeconds' in livenessProbe in order to have more time on first deployment: from 60 to 600 seconds.

  ###  NOT NECESARY: INCLUDED IN CUSTOM TEMPLATE
  ```
  $ oc patch dc/sso -p '{"spec":{"template": {"spec": {"containers":[{"name": "sso","livenessProbe": {"initialDelaySeconds":'600'}}]}}}}' -n ${SSO_PROJECT}
  ```

E) Update the BASE IMAGE.

  ###  NOT NECESARY: INCLUDED IN CUSTOM TEMPLATE 
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

F) If deployment is not triggered automatically, launch it manually:
```
$ oc rollout latest dc/sso
```

G) Change number of replicas
```
$ oc scale --replicas=0 dc/sso
```




/subsystem=datasources/jdbc-driver=oracle:add( \
    driver-name=oracle, \
    driver-module-name=com.oracle, \
    driver-xa-datasource-class-name=oracle.jdbc.xa.client.OracleXADataSource \
)

/subsystem=datasources/data-source=KeycloakDS:remove()

 
/subsystem=datasources/data-source=KeycloakDS:add( \
    jndi-name=java:jboss/datasources/KeycloakDS, \
    enabled=true, \
    use-java-context=true, \
    connection-url=jdbc:oracle:thin:@10.170.95.243:1521/PWIPRE, \
    driver-name=oracle, \
    user-name=sys, \
    password=tstkZxSHIDpMqVSv \
)
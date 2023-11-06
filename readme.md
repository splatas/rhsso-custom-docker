# Red Hat Single Sign-On

Este extracto cubre el proceso de instalación del producto **Red Hat Single SignOn 7.5** y sus configuraciones necesarias.

--------------------------------------
# INSTALAR RH-SSO CUSTOMIZADO DESDE 0.
# Se aplicará la customización del .well-known para que muestre lo indicado en el ConfigMap: 


1) Loguearse al cluster y setear la variable del proyecto:

```
$ oc login --token=$CLUSTER_TOKEN --server=https://$MINISHIFT_CLUSTER_URL:6443
```
```
$ export SSO_PROJECT=rhsso-dev   (<= NAMESPACE)
$ oc new-project $SSO_PROJECT
```

2) Pararse en la carpeta descargada y ejecutar el build:
cd /$REPO_GIT

3) Crear Configmap para customizar 'mtls-endpoints_aliases':
```
$ oc create -f ./artifacts/ocp/mtls-endpoints-aliases-cm.yaml
```

4) Creamos el BuildConfig:
```
$ oc new-build --name rhsso --binary --strategy docker

    Para un BC diferente con tzdata actualizado:
      oc new-build --name rhsso-tz-data --binary --strategy docker
```

5) Buildeamos la imagen con el BC anterior y el contenido de la carpeta actual:
```
$ oc start-build rhsso --from-dir . --follow

    Para buildear con el package tzdata
      oc start-build rhsso-tz-data --from-dir . --follow
```

### NOTA: 
Al buildear la imagen con el comando anterior, se incluye la configuración indicada en ./extensions/actions.cli.
En este componente se han configurado las directivas para que RH-SSO (mediante la tool jboss-cli) modifique el subsistema 'well-known' referenciando al archivo 'mtls_custom.json', que es provisto por el ConfigMap creado en el paso 3 (mtls-endpoints-aliases-cm) y se inyectará posteriormente en el paso 8 (oc set volume...):

### JBOSS-CLI commands:
```
/subsystem=keycloak-server/spi=well-known:add()
/subsystem=keycloak-server/spi=well-known/provider="openid-configuration":add(enabled=true, properties={"openid-configuration-override"="${openid-configuration-override:}"})
/system-property=openid-configuration-override:add(value="/opt/eap/extensions/mtls_custom.json")
```

6) Importar el template de RHSSO 7.5 (si no existe en la carpeta descargada):
```
$ oc create -f ./artifacts/ocp/sso75-ocp4-x509-https.json -n openshift
```


7) Creamos el DeploymentConfig de SSO con el template creado en el paso anterior. Le indicamos User admin (y su Password) que se va a crear, para administrar la instancia de RH-SSO.
```
$ oc new-app --template=sso75-ocp4-x509-https \
        --param=SSO_ADMIN_USERNAME=admin \
        --param=SSO_ADMIN_PASSWORD="redhat01"
```

8) Montar el configmap del paso 3 como volumen:
```
$ oc set volume dc/sso --add --name=mtls-endpoints-aliases-cm --mount-path /opt/eap/extensions/mtls_custom.json --sub-path mtls_custom.json --source='{"configMap":{"name":"mtls-endpoints-aliases-cm","items":[{"key":"mtls_custom.json","path":"mtls_custom.json"}]}}' -n $SSO_PROJECT
```

9) Actualizo el 'initialDelaySeconds' del livenessProbe para que tenga mas tiempo el primer deploy: lo paso de 60 a 600 segundos.
```
$ oc patch dc/sso -p '{"spec":{"template": {"spec": {"containers":[{"name": "sso","livenessProbe": {"initialDelaySeconds":'600'}}]}}}}' -n ${SSO_PROJECT}
```

10) Actualizo la IMAGEN BASE a utilizar durante el despliegue.
El template indica "namespace": "openshift" y el ImageStreamTag "name": "sso75-openshift-rhel8:7.5".
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
            "namespace": "rhsso-dev",
            "name": "rhsso:latest"
          }
        }
      }
    ]
  }
  }}' -n ${SSO_PROJECT} 
```

11) Si no se desplegó automáticamente, lanzo el despliegue del DC:
```
$ oc rollout latest dc/sso
```

12) Valido que el .well-known muestre lo indicado en el ConfigMap (paso 3):
```
$ curl -v https://$SSO_ROUTE/auth/realms/master/.well-known/openid-configuration | grep mtls_endpoint_aliases
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

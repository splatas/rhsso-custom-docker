# Red Hat Single Sign-On

Este extracto cubre el proceso de instalación del producto **Red Hat Single SignOn 7.5** y sus configuraciones necesarias.

--------------------------------------
# INSTALAR RH-SSO CUSTOMIZADO DESDE 0.


1) Loguearse al cluster y setear la variable del proyecto:
oc login --token=sha256~k5i6zv-LQD-uWGPW-NOG12Iu-WMa2tQ-2LMxNg0KHdc --server=https://api.cluster-pzg7b.pzg7b.sandbox1371.opentlc.com:6443

export SSO_PROJECT=santalucia-dev   (<= NAMESPACE)
oc new-project $SSO_PROJECT

2) Pararse en la carpeta descargada y ejecutar el build:
cd /$REPO_GIT

3) Crear Configmap 
oc create -f ./artifacts/ocp/mtls-endpoints-aliases-cm.yaml

4) Hacemos backup del BC original:
oc new-build --name rhsso --binary --strategy docker


5) Buildear la imagen:
oc start-build rhsso --from-dir . --follow


6) Importar el template de RHSSO 7.5 (si no existe en la carpeta descargada):
oc create -f ./artifacts/ocp/sso75-ocp4-x509-https.json -n openshift


7) Crear un SSO generico para poder pisar la imagen
oc new-app --template=sso75-ocp4-x509-https \
        --param=SSO_ADMIN_USERNAME=admin \
        --param=SSO_ADMIN_PASSWORD="redhat01"

8) Montar el configmap como volumen
oc set volume dc/sso --add --name=mtls-endpoints-aliases-cm --mount-path /opt/eap/extensions/mtls_custom.json --sub-path mtls_custom.json --source='{"configMap":{"name":"mtls-endpoints-aliases-cm","items":[{"key":"mtls_custom.json","path":"mtls_custom.json"}]}}' -n $SSO_PROJECT


--------------------
POST CONFIGURACIONES
--------------------
12) Hacer un override del deployment para agregar la imagen nueva:
    OJO EL NAMESPACE: dice 'openshift' pero puede estar en el NAMESPACE de la instalación.
    ----------------
    - type: ImageChange
      imageChangeParams:
        automatic: true
        containerNames:
          - sso
        from:
          kind: ImageStreamTag
          namespace: openshift
          name: 'rhsso:latest'
        lastTriggeredImage: >-
       image-registry.openshift-image-registry.svc:5000/rh-sso/rhsso@sha256:3bd57de93a781e1633919dc26e189a665ca28dad20912136851df3fd0f87f156
    - type: ConfigChange


13) Actualizar los healthchecks
SI ERROR EN PRIMER DEPLOY (TIMEOUT): Actualizar el DC livenessProbe / initialDelaySeconds: 60 => 600 



#!/bin/bash

# PRE-INSTALL
# -----------
# A. Instalación de la DB, INSTRUCCIONES:
#   https://github.com/oracle/docker-images/blob/main/OracleDatabase/SingleInstance/README.md
# 
# 1. Clonar ese repo en $CARPETA_ACTUAL
#
# 2. Descargar el binario de la versión a instalar: https://www.oracle.com/database/technologies/oracle-database-software-downloads.html
#    Copiar el binario (.zip) en la carpeta correspondiente a la versioón, Ejemplo:
#    LINUX.X64_193000_db_home.zip => $CARPETA_ACTUAL/oracle/docker-images/OracleDatabase/SingleInstance/dockerfiles/19.3.0  
#
# 3. Ejecutar el build: buildContainerImage.sh
#    ./buildContainerImage.sh -e -v 19.3.0 -o '--build-arg SLIMMING=false'   
#    
#    script: $CARPETA_ACTUAL/oracle/docker-images/OracleDatabase/SingleInstance/dockerfiles/buildContainerImage.sh   
#
# -----------

export CLUSTER=https://api.cluster-xkpnb.xkpnb.sandbox1381.opentlc.com:6443
export CLUSTER_TOKEN=sha256~nxG_t8492lj1flreBzjUsMaXpISMofJ2EP_FfFoYDXs
export IMAGE_OUTPUT=rhsso
export NAMESPACE=$1
echo "##############################################"
echo "Parámetros:"
echo "  - Cluster: " $CLUSTER
echo "  - Namespace: " $NAMESPACE

echo "------------"
echo "Me conecto al cluster: " $CLUSTER
oc login --token=$CLUSTER_TOKEN --server=$CLUSTER


# B. Importo los templates
# https://raw.githubusercontent.com/jboss-container-images/redhat-sso-7-openshift-image/sso75-cpaas-dev/templates/sso75-ocp4-x509-https.json
echo ""
echo "------------"
echo "Importo los templates "
for resource in sso75-ocp4-x509-https.json sso75-image-stream.json sso75-https.json sso75-postgresql.json sso75-postgresql-persistent.json sso75-x509-https.json sso75-x509-postgresql-persistent.json
do
 oc replace -n openshift --force -f \
 https://raw.githubusercontent.com/jboss-container-images/redhat-sso-7-openshift-image/sso75-cpaas-dev/templates/${resource}
done

# EL TEMPLATE CLAVE ES:
# oc replace -n openshift --force -f \
#  https://raw.githubusercontent.com/jboss-container-images/redhat-sso-7-openshift-image/sso75-cpaas-dev/templates/sso75-ocp4-x509-https.json


# 1. Creo proyecto
echo ""
echo "------------"
echo "Creo proyecto " $NAMESPACE
oc new-project $NAMESPACE


#2. **Configurar credenciales del repositorio Git**
echo ""
echo "------------"
echo " Creo credenciales del repositorio Git" 
oc create secret -n $NAMESPACE generic gitlab-basic-auth \
    --from-literal=username=splatas \
    --from-literal=password=glpat-ozhvqye3E6fwZDYVs1DM \
    --type=kubernetes.io/basic-auth

oc annotate -n $NAMESPACE secret/gitlab-basic-auth \
    'build.openshift.io/source-secret-match-uri-1=https://gitlab.consulting.redhat.com/*'


#3. **Generar Imagen Docker**
echo ""
echo "------------"
echo " Creo Imagen Docker" 
oc -n $NAMESPACE new-build https://gitlab.consulting.redhat.com/splatas/es-giss-docker.git --name $IMAGE_OUTPUT --context-dir=. -lapp=sso -lcustom=sgr


#4. **Instanciar y/o Deployar Red Hat Single SignOn**
echo ""
echo "------------"
echo " Despliego Red Hat Single SignOn" 
oc new-app -n $NAMESPACE --template=sso75-ocp4-x509-https-giss \ 
  --param=SSO_ADMIN_USERNAME=admin --param=SSO_ADMIN_PASSWORD="redhat01" \
  --param=IMAGE_STREAM_NAMESPACE=$NAMESPACE --param=CUSTOM_IMAGE=$IMAGE_OUTPUT


#PENDIENTES:
#    1.ACTUALIZAR EL DC
#    - type: ImageChange
#      imageChangeParams:
#        automatic: true
#        containerNames:
#          - sso
#        from:
#          kind: ImageStreamTag
#          namespace: openshift
#          name: '$IMAGE_OUTPUT:latest'
#    - type: ConfigChange
#
#    2. Actualizar DC: LivenessProbe / initialDelaySeconds: 60 => 600 (el primer deploy falla por timeout)
#
#
#    3. TAGUEAR LA VERSION PARA NO USAR 'LATEST': release-1.0.0
# 


echo ""
echo "######################################################################"
echo " Finalizó el proces de instalación! Namespace: '"$NAMESPACE"'"
echo "######################################################################"

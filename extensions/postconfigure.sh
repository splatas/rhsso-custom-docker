echo "@@@@@@@@@@@@@@@ Executing postconfigure.sh"

echo " Detalle del actions.cli:"
cat /opt/eap/extensions/actions.cli	
$JBOSS_HOME/bin/jboss-cli.sh --file=/opt/eap/extensions/actions.cli

#echo " Running kcadm..."
# Keycloak ADMIN:
# kcadm.sh config credentials --server http://localhost:8080/auth --realm $MY_REALM_NAME --user $MI_USER --password CHANGE_ME 
# kcadm.sh create components -r $REALM_NAME -s name=rsa-giss -s providerId=rsa -s providerType=org.keycloak.keys.KeyProvider -s 'config.privateKey=["/home/splatas/repo/$ALGUNA_CARPETA/segunda-implementacion/$REPOSITORIO/certs/privateKey.pem"]’ -s ‘config.certificate=["/home/splatas/repo/$UN_REPO/segunda-implementacion/$UNA_CARPETA/certs/caKey.pem"]'
## --- ##
#export REALM_NAME=giss-certificados 
#export REALM_ADMIN_USER=$ADMIN_USER
#export REALM_ADMIN_PASS=CHANGE_ME
#export PRIVATE_KEY_FILE=/opt/eap/standalone/configuration/privateRsaKey.pem
#export CERTIFICATE_FILE=/opt/eap/standalone/configuration/caRsaKey.pem
#
#$JBOSS_HOME/bin/kcadm.sh config credentials --server http://localhost:8080/auth --realm $REALM_NAME --user $REALM_ADMIN_USER --password $REALM_ADMIN_PASS
#$JBOSS_HOME/bin/kcadm.sh create components -r $REALM_NAME -s name=rsa-giss -s providerId=rsa -s providerType=org.keycloak.keys.KeyProvider -s 'config.privateKey=["$PRIVATE_KEY_FILE"]’ -s ‘config.certificate=["$CERTIFICATE_FILE"]'


#$JBOSS_HOME/bin/kcadm.sh create components -r $REALM_NAME -s name=$UN_NOMBRE -s providerId=rsa -s providerType=org.keycloak.keys.KeyProvider -s 'config.privateKey=["/opt/eap/standalone/configuration/privateRsaKey.pem"]' -s 'config.certificate=["/opt/eap/standalone/configuration/caRsaKey.pem"]'
#echo "Finished kcadm!"

echo "@@@@@@@@@@@@@@@ Finish postconfigure.sh"


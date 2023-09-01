echo "@@@@@@@@@@@@@@@ Executing postconfigure.sh"

echo " Detalle del actions.cli:"
cat /opt/eap/extensions/actions.cli	
$JBOSS_HOME/bin/jboss-cli.sh --file=/opt/eap/extensions/actions.cli

echo "@@@@@@@@@@@@@@@ Finish postconfigure.sh"


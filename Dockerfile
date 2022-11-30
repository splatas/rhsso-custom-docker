FROM registry.redhat.io/rh-sso-7/sso75-openshift-rhel8:7.5

#ARG PLUGIN_URL
#ARG PLUGIN_USER
#ARG PLUGIN_PASS
#ADD http://${PLUGIN_USER}:${PLUGIN_PASS}@${PLUGIN_URL} /opt/eap/standalone/deployments/
    
COPY extensions/* /opt/eap/extensions/

USER root
RUN chmod 774 -R /opt/eap/
USER jboss

CMD ["/opt/eap/bin/openshift-launch.sh"]



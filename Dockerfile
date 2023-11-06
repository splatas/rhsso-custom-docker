FROM registry.redhat.io/rh-sso-7/sso75-openshift-rhel8:7.5

#ARG PLUGIN_URL
#ARG PLUGIN_USER
#ARG PLUGIN_PASS
#ADD http://${PLUGIN_USER}:${PLUGIN_PASS}@${PLUGIN_URL} /opt/eap/standalone/deployments/
    
COPY extensions/* /opt/eap/extensions/

USER root
RUN chmod 774 -R /opt/eap/

##############################################################################################
# TZDATA Update
# (Pinning package versions is a best practice, even though we're using wildcard here)
##############################################################################################
ARG TZDATA_VER="202*"
#RUN dnf update --assumeyes \
#      "tzdata-${TZDATA_VER}" && \
#    dnf clean all && \
#    rm -rf /var/cache/yum

RUN rpm -Uvh /opt/eap/extensions/tzdata-2023c-1.el9.noarch.rpm 
# && rpm clean all && \
#    rm -rf /var/cache/yum
#RUN rpm -Uvh tzdata-2021e-1.el8.noarch

##############################################################################################
USER jboss

CMD ["/opt/eap/bin/openshift-launch.sh"]



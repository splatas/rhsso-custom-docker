FROM registry.redhat.io/rh-sso-7/sso76-openshift-rhel8:7.6-24
 
COPY extensions/* /opt/eap/extensions/
COPY extensions/themes/* /opt/eap/themes/mytheme

USER root
RUN chmod 774 -R /opt/eap/
USER jboss

CMD ["/opt/eap/bin/openshift-launch.sh"]



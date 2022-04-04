FROM jboss/wildfly
RUN curl -O https://open-install-library-artifacts.s3.us-west-2.amazonaws.com/linux/java/spring-boot-rest.war
ADD spring-boot-rest.war /opt/jboss/wildfly/standalone/deployments/

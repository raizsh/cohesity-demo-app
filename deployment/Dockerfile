FROM centos:centos7

WORKDIR /opt/demoapp/bin
ADD demo_app_exec /opt/demoapp/bin/
ADD wrapper.sh /opt/demoapp/bin/

CMD ["/bin/bash", "/opt/demoapp/bin/wrapper.sh", "-stderrthreshold=INFO"]

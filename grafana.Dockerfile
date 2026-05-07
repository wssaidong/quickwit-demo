FROM grafana/grafana:11.2.0

# Install Infinity plugin for REST API data source support
# Note: grafana-cli must run after grafana is started (use grafana>=10.3)
RUN grafana-cli plugins install yesoreyeram-infinity-datasource

# Copy provisioning files
COPY grafana/provisioning /etc/grafana/provisioning
COPY grafana/dashboards /var/lib/grafana/dashboards

EXPOSE 3000

sudo systemctl stop node_exporter.service
sudo systemctl stop systemd_exporter.service
sudo systemctl stop promtail.service
sudo systemctl stop pprotein-agent.service
sudo systemctl disable node_exporter.service
sudo systemctl disable systemd_exporter.service
sudo systemctl disable pprotein-agent.service
sudo systemctl disable promtail.service

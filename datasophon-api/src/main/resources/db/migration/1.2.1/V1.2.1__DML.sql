DELETE FROM `t_ddh_cluster_service_dashboard` where `id` in (11, 15);

INSERT INTO `t_ddh_cluster_service_dashboard` (SERVICE_NAME, DASHBOARD_URL ) VALUES ('MINIO','http://${grafanaHost}:3000/d/DP44u7JZk/minio-jian-kong?orgId=1&refresh=10s');
INSERT INTO `t_ddh_cluster_service_dashboard` (service_name, dashboard_url) VALUES ('REDIS','http://${grafanaHost}:3000/d/11bbfabb-8f8e-4f58-937d-4f5af170484e/redis?orgId=1&kiosk=tv')
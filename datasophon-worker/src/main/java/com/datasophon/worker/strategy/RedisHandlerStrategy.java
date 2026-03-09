package com.datasophon.worker.strategy;

import com.datasophon.common.Constants;
import com.datasophon.common.command.ServiceRoleOperateCommand;
import com.datasophon.common.enums.CommandType;
import com.datasophon.common.utils.ExecResult;
import com.datasophon.common.utils.ShellUtils;
import com.datasophon.worker.handler.ServiceHandler;

import org.apache.commons.lang3.StringUtils;

import java.sql.SQLException;
import java.util.Objects;

public class RedisHandlerStrategy extends AbstractHandlerStrategy implements ServiceRoleStrategy {
    
    private static final int REDIS_CLUSTER_INIT_MAX_RETRY = 12;
    
    private static final long REDIS_CLUSTER_INIT_RETRY_INTERVAL_MS = 5000L;
    
    public RedisHandlerStrategy(String serviceName, String serviceRoleName) {
        super(serviceName, serviceRoleName);
    }
    
    @Override
    public ExecResult handler(ServiceRoleOperateCommand command) throws SQLException, ClassNotFoundException {
        ServiceHandler serviceHandler = new ServiceHandler(command.getServiceName(), command.getServiceRoleName());
        String workPath = Constants.INSTALL_PATH + Constants.SLASH + command.getDecompressPackageName();
        ExecResult result;
        
        CommandType commandType = command.getCommandType();
        String exporterRole = resolveExporterRole(command.getServiceRoleName());
        
        switch (commandType) {
            case INSTALL_SERVICE:
                
                result = serviceHandler.start(command.getStartRunner(), command.getStatusRunner(),
                        command.getDecompressPackageName(), command.getRunAs());
                if (!result.getExecResult()) {
                    return result;
                }
                ExecResult exporterResult = startRedisExporter(workPath, exporterRole);
                if (!exporterResult.getExecResult()) {
                    return withFailureContext("redis-exporter", exporterResult);
                }
                if (shouldInitRedisCluster(command)) {
                    ExecResult clusterResult = initRedisClusterWithRetry(workPath);
                    if (!clusterResult.getExecResult()) {
                        return withFailureContext("redis-cluster.sh", clusterResult);
                    }
                }
                break;
            
            case START_SERVICE:
            case START_WITH_CONFIG:
                
                result = serviceHandler.start(command.getStartRunner(), command.getStatusRunner(),
                        command.getDecompressPackageName(), command.getRunAs());
                if (!result.getExecResult()) {
                    return result;
                }
                ExecResult startExporterResult = startRedisExporter(workPath, exporterRole);
                if (!startExporterResult.getExecResult()) {
                    return withFailureContext("redis-exporter", startExporterResult);
                }
                break;
            
            case STOP_SERVICE:
                
                result = serviceHandler.stop(command.getStopRunner(), command.getStatusRunner(),
                        command.getDecompressPackageName(), command.getRunAs());
                if (!result.getExecResult()) {
                    return result;
                }
                ExecResult stopExporterResult = stopRedisExporter(workPath, exporterRole);
                if (!stopExporterResult.getExecResult()) {
                    return withFailureContext("redis-exporter", stopExporterResult);
                }
                break;
            
            case RESTART_SERVICE:
            case RESTART_WITH_CONFIG:
                
                result = serviceHandler.reStart(command.getRestartRunner(), command.getDecompressPackageName());
                if (!result.getExecResult()) {
                    return result;
                }
                ExecResult restartExporterResult = restartRedisExporter(workPath, exporterRole);
                if (!restartExporterResult.getExecResult()) {
                    return withFailureContext("redis-exporter", restartExporterResult);
                }
                break;
            
            default:
                result = new ExecResult();
                result.setExecResult(false);
                result.setExecOut("Unsupported command type: " + commandType);
        }
        
        return result;
    }
    
    private ExecResult startRedisExporter(String workPath, String exporterRole) {
        return execRedisExporter(workPath, "start", exporterRole);
    }
    
    private ExecResult stopRedisExporter(String workPath, String exporterRole) {
        return execRedisExporter(workPath, "stop", exporterRole);
    }
    
    private ExecResult restartRedisExporter(String workPath, String exporterRole) {
        return execRedisExporter(workPath, "restart", exporterRole);
    }
    
    private boolean shouldInitRedisCluster(ServiceRoleOperateCommand command) {
        return "RedisWorker".equals(command.getServiceRoleName());
    }
    
    private ExecResult initRedisClusterWithRetry(String workPath) {
        ExecResult lastResult = null;
        for (int i = 0; i < REDIS_CLUSTER_INIT_MAX_RETRY; i++) {
            lastResult = ShellUtils.exceShell("bash " + workPath + "/redis-cluster.sh");
            if (lastResult.getExecResult()) {
                return lastResult;
            }
            if (!isNodeNotReady(lastResult)) {
                return lastResult;
            }
            try {
                Thread.sleep(REDIS_CLUSTER_INIT_RETRY_INTERVAL_MS);
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
                ExecResult result = new ExecResult();
                result.setExecResult(false);
                result.setExecOut("redis-cluster init interrupted: " + e.getMessage());
                return result;
            }
        }
        return Objects.nonNull(lastResult) ? lastResult : withFailureContext("redis-cluster.sh", null);
    }
    
    private boolean isNodeNotReady(ExecResult result) {
        String execOut = StringUtils.defaultString(result.getExecOut()).toLowerCase();
        return execOut.contains("not all redis nodes are running")
                || execOut.contains("cluster creation aborted")
                || execOut.contains("failed to create redis cluster");
    }
    
    private ExecResult execRedisExporter(String workPath, String action, String exporterRole) {
        if (!StringUtils.isNotBlank(exporterRole)) {
            ExecResult result = new ExecResult();
            result.setExecResult(false);
            result.setExecOut("redis-exporter role is empty, action: " + action);
            return result;
        }
        try {
            String command = "bash " + workPath + "/bin/redis-exporter-control.sh " + action + " " + exporterRole;
            ExecResult result = ShellUtils.exceShell(command);
            if (!result.getExecResult()) {
                logger.warn("Failed to {} redis_exporter({}): {}", action, exporterRole, result.getExecOut());
            }
            return result;
        } catch (Exception e) {
            logger.warn("Failed to {} redis_exporter({}): {}", action, exporterRole, e.getMessage());
            ExecResult result = new ExecResult();
            result.setExecResult(false);
            result.setExecOut(e.getMessage());
            return result;
        }
    }
    
    private String resolveExporterRole(String serviceRoleName) {
        if (!StringUtils.isNotBlank(serviceRoleName)) {
            return null;
        }
        if ("RedisMaster".equals(serviceRoleName)) {
            return "master";
        }
        if ("RedisWorker".equals(serviceRoleName)) {
            return "slave";
        }
        return null;
    }
    
    private ExecResult withFailureContext(String stepName, ExecResult result) {
        ExecResult finalResult = Objects.nonNull(result) ? result : new ExecResult();
        finalResult.setExecResult(false);
        String execOut = finalResult.getExecOut();
        if (Objects.nonNull(execOut) && !execOut.isEmpty()) {
            finalResult.setExecOut(stepName + " failed: " + execOut);
        } else {
            finalResult.setExecOut(stepName + " failed");
        }
        return finalResult;
    }
}

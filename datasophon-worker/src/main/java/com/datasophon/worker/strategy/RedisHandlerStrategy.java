package com.datasophon.worker.strategy;

import com.datasophon.common.Constants;
import com.datasophon.common.command.ServiceRoleOperateCommand;
import com.datasophon.common.enums.CommandType;
import com.datasophon.common.utils.ExecResult;
import com.datasophon.common.utils.ShellUtils;
import com.datasophon.worker.handler.ServiceHandler;

import java.sql.SQLException;
import java.util.Objects;

public class RedisHandlerStrategy extends AbstractHandlerStrategy implements ServiceRoleStrategy {
    
    public RedisHandlerStrategy(String serviceName, String serviceRoleName) {
        super(serviceName, serviceRoleName);
    }
    
    @Override
    public ExecResult handler(ServiceRoleOperateCommand command) throws SQLException, ClassNotFoundException {
        ServiceHandler serviceHandler = new ServiceHandler(command.getServiceName(), command.getServiceRoleName());
        String workPath = Constants.INSTALL_PATH + Constants.SLASH + command.getDecompressPackageName();
        ExecResult result;
        
        CommandType commandType = command.getCommandType();
        
        switch (commandType) {
            case INSTALL_SERVICE:

                result = serviceHandler.start(command.getStartRunner(), command.getStatusRunner(),
                        command.getDecompressPackageName(), command.getRunAs());
                if (!result.getExecResult()) {
                    return result;
                }
                ExecResult clusterResult = ShellUtils.exceShell("bash " + workPath + "/redis-cluster.sh");
                if (!clusterResult.getExecResult()) {
                    return withFailureContext("redis-cluster.sh", clusterResult);
                }
                ExecResult exporterResult = startRedisExporter(workPath);
                if (!exporterResult.getExecResult()) {
                    return withFailureContext("redis-exporter", exporterResult);
                }
                break;
            
            case START_SERVICE:
            case START_WITH_CONFIG:

                result = serviceHandler.start(command.getStartRunner(), command.getStatusRunner(),
                        command.getDecompressPackageName(), command.getRunAs());
                if (!result.getExecResult()) {
                    return result;
                }
                ExecResult startExporterResult = startRedisExporter(workPath);
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
                ExecResult stopExporterResult = stopRedisExporter(workPath);
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
                ExecResult restartExporterResult = restartRedisExporter(workPath);
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
    
    private ExecResult startRedisExporter(String workPath) {
        try {
            ExecResult result = ShellUtils.exceShell("bash " + workPath + "/bin/redis-exporter-control.sh start");
            if (!result.getExecResult()) {
                logger.warn("Failed to start redis_exporter: {}", result.getExecOut());
            }
            return result;
        } catch (Exception e) {
            logger.warn("Failed to start redis_exporter: {}", e.getMessage());
            ExecResult result = new ExecResult();
            result.setExecResult(false);
            result.setExecOut(e.getMessage());
            return result;
        }
    }
    
    private ExecResult stopRedisExporter(String workPath) {
        try {
            ExecResult result = ShellUtils.exceShell("bash " + workPath + "/bin/redis-exporter-control.sh stop");
            if (!result.getExecResult()) {
                logger.warn("Failed to stop redis_exporter: {}", result.getExecOut());
            }
            return result;
        } catch (Exception e) {
            logger.warn("Failed to stop redis_exporter: {}", e.getMessage());
            ExecResult result = new ExecResult();
            result.setExecResult(false);
            result.setExecOut(e.getMessage());
            return result;
        }
    }
    
    private ExecResult restartRedisExporter(String workPath) {
        try {
            ExecResult result = ShellUtils.exceShell("bash " + workPath + "/bin/redis-exporter-control.sh restart");
            if (!result.getExecResult()) {
                logger.warn("Failed to restart redis_exporter: {}", result.getExecOut());
            }
            return result;
        } catch (Exception e) {
            logger.warn("Failed to restart redis_exporter: {}", e.getMessage());
            ExecResult result = new ExecResult();
            result.setExecResult(false);
            result.setExecOut(e.getMessage());
            return result;
        }
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

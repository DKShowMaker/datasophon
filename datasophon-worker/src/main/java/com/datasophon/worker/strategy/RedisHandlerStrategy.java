package com.datasophon.worker.strategy;

import com.datasophon.common.Constants;
import com.datasophon.common.command.ServiceRoleOperateCommand;
import com.datasophon.common.enums.CommandType;
import com.datasophon.common.utils.ExecResult;
import com.datasophon.common.utils.ShellUtils;
import com.datasophon.worker.handler.ServiceHandler;

import java.sql.SQLException;

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
                ShellUtils.exceShell("bash " + workPath + "/redis-cluster.sh");
                startRedisExporter(workPath);
                break;
            
            case START_SERVICE:
            case START_WITH_CONFIG:
                result = serviceHandler.start(command.getStartRunner(), command.getStatusRunner(),
                        command.getDecompressPackageName(), command.getRunAs());
                startRedisExporter(workPath);
                break;
            
            case STOP_SERVICE:
                result = serviceHandler.stop(command.getStopRunner(), command.getStatusRunner(),
                        command.getDecompressPackageName(), command.getRunAs());
                stopRedisExporter(workPath);
                break;
            
            case RESTART_SERVICE:
            case RESTART_WITH_CONFIG:
                result = serviceHandler.reStart(command.getRestartRunner(), command.getDecompressPackageName());
                restartRedisExporter(workPath);
                break;
            
            default:
                result = new ExecResult();
                result.setExecResult(false);
                result.setExecOut("Unsupported command type: " + commandType);
        }
        
        return result;
    }
    
    private void startRedisExporter(String workPath) {
        try {
            ShellUtils.exceShell("bash " + workPath + "/bin/redis-exporter-control.sh start");
        } catch (Exception e) {
            logger.warn("Failed to start redis_exporter: {}", e.getMessage());
        }
    }
    
    private void stopRedisExporter(String workPath) {
        try {
            ShellUtils.exceShell("bash " + workPath + "/bin/redis-exporter-control.sh stop");
        } catch (Exception e) {
            logger.warn("Failed to stop redis_exporter: {}", e.getMessage());
        }
    }
    
    private void restartRedisExporter(String workPath) {
        try {
            ShellUtils.exceShell("bash " + workPath + "/bin/redis-exporter-control.sh restart");
        } catch (Exception e) {
            logger.warn("Failed to restart redis_exporter: {}", e.getMessage());
        }
    }
}
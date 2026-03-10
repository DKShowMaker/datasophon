package com.datasophon.api.master;

import com.datasophon.api.load.GlobalVariables;
import com.datasophon.api.service.ClusterInfoService;
import com.datasophon.api.utils.RedisClusterInstallUtils;
import com.datasophon.api.utils.SpringTool;
import com.datasophon.common.Constants;
import com.datasophon.common.cache.CacheUtils;
import com.datasophon.common.command.ExecuteCmdCommand;
import com.datasophon.common.command.OlapSqlExecCommand;
import com.datasophon.common.command.RedisClusterNotifyCommand;
import com.datasophon.common.utils.ExecResult;
import com.datasophon.common.utils.OlapUtils;
import com.datasophon.dao.entity.ClusterInfoEntity;

import org.apache.commons.lang3.StringUtils;

import scala.concurrent.Await;
import scala.concurrent.Future;
import scala.concurrent.duration.Duration;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.concurrent.TimeUnit;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import akka.actor.ActorRef;
import akka.actor.UntypedActor;
import akka.pattern.Patterns;
import akka.util.Timeout;
import cn.hutool.json.JSONUtil;

public class MasterNodeProcessingActor extends UntypedActor {
    
    private static final Logger logger = LoggerFactory.getLogger(MasterNodeProcessingActor.class);
    
    private static final String REDIS_SERVICE_NAME = "REDIS";
    
    private static final String REDIS_MASTER_ROLE_NAME = "RedisMaster";
    
    private static final String REDIS_WORKER_ROLE_NAME = "RedisWorker";
    
    private static final int REDIS_CLUSTER_INIT_MAX_RETRY = 12;
    
    private static final long REDIS_CLUSTER_INIT_RETRY_INTERVAL_SECONDS = 5L;
    
    private static final int REDIS_CLUSTER_NODE_CHECK_MAX_RETRY = 6;
    
    private static final long REDIS_CLUSTER_NODE_CHECK_RETRY_INTERVAL_SECONDS = 10L;
    
    @Override
    public void onReceive(Object message) throws Throwable {
        logger.info("MasterNodeProcessingActor receive message: " + JSONUtil.toJsonStr(message));
        if (message instanceof OlapSqlExecCommand) {
            handleOlapSqlExecCommand((OlapSqlExecCommand) message);
        } else if (message instanceof RedisClusterNotifyCommand) {
            handleRedisClusterNotifyCommand((RedisClusterNotifyCommand) message);
        } else {
            unhandled(message);
        }
    }
    
    private void handleOlapSqlExecCommand(OlapSqlExecCommand command) {
        ExecResult execResult = new ExecResult();
        String tip = command.getOpsType().getDesc();
        switch (command.getOpsType()) {
            case ADD_BE:
                execResult = OlapUtils.addBackend(command.getFeMaster(), command.getHostName());
                break;
            case ADD_FE_FOLLOWER:
                execResult = OlapUtils.addFollower(command.getFeMaster(), command.getHostName());
                break;
            case ADD_FE_OBSERVER:
                execResult = OlapUtils.addObserver(command.getFeMaster(), command.getHostName());
                break;
            default:
                break;
        }
        if (execResult.getExecResult()) {
            logger.info(command.getHostName() + " " + tip + " added success");
        } else {
            logger.info(command.getHostName() + " " + tip + " added failed");
        }
        int tryTimes = 0;
        while (!execResult.getExecResult() && tryTimes < 3) {
            try {
                TimeUnit.SECONDS.sleep(10L);
                switch (command.getOpsType()) {
                    case ADD_BE:
                        execResult = OlapUtils.addBackendBySqlClient(command.getFeMaster(), command.getHostName());
                        break;
                    case ADD_FE_FOLLOWER:
                        execResult = OlapUtils.addFollowerBySqlClient(command.getFeMaster(), command.getHostName());
                        break;
                    case ADD_FE_OBSERVER:
                        execResult = OlapUtils.addObserverBySqlClient(command.getFeMaster(), command.getHostName());
                        break;
                    default:
                        break;
                }
                if (execResult.getExecResult()) {
                    logger.info(command.getHostName() + " " + tip + " added success");
                    break;
                } else {
                    logger.info(command.getHostName() + " " + tip + " added failed");
                }
                tryTimes++;
            } catch (InterruptedException e) {
                logger.info("The SR operate be sleep operation failed");
                Thread.currentThread().interrupt();
            }
        }
    }
    
    private void handleRedisClusterNotifyCommand(RedisClusterNotifyCommand command) {
        if (Objects.isNull(command.getClusterId())) {
            logger.warn("Redis cluster notify skipped because clusterId is null");
            return;
        }
        if (!REDIS_SERVICE_NAME.equalsIgnoreCase(command.getServiceName())) {
            logger.info("skip non-redis notify command, serviceName: {}", command.getServiceName());
            return;
        }
        if (!REDIS_WORKER_ROLE_NAME.equals(command.getServiceRoleName())) {
            logger.info("skip redis notify from non-worker role, roleName: {}", command.getServiceRoleName());
            return;
        }
        if (!isRedisClusterReady(command.getClusterId())) {
            return;
        }
        
        String leaderHost = resolveRedisClusterLeaderHost(command.getClusterId());
        if (StringUtils.isBlank(leaderHost)) {
            logger.warn("Redis cluster init skipped because leader host is empty, clusterId: {}", command.getClusterId());
            return;
        }
        
        if (StringUtils.isBlank(command.getDecompressPackageName())) {
            logger.warn("Redis cluster init skipped because decompressPackageName is empty, clusterId: {}",
                    command.getClusterId());
            return;
        }
        
        ExecResult initResult = initRedisClusterWithRetry(leaderHost, command.getDecompressPackageName());
        if (Objects.nonNull(initResult) && initResult.getExecResult()) {
            logger.info("Redis cluster initialized success, clusterId: {}, leaderHost: {}", command.getClusterId(),
                    leaderHost);
        } else {
            logger.warn("Redis cluster initialized failed, clusterId: {}, leaderHost: {}, error: {}",
                    command.getClusterId(), leaderHost, Objects.nonNull(initResult) ? initResult.getExecOut() : "");
        }
    }
    
    private boolean isRedisClusterReady(Integer clusterId) {
        RedisClusterInstallUtils.RedisWorkerInstallProgress installProgress =
                RedisClusterInstallUtils.getRedisWorkerInstallProgress(clusterId);
        if (!installProgress.isExpectedWorkerCountValid()) {
            logger.warn("Redis cluster expected worker count is invalid, clusterId: {}", clusterId);
            return false;
        }
        logger.info("Redis worker install progress, clusterId: {}, installed: {}, expected: {}", clusterId,
                installProgress.getInstalledWorkerCount(), installProgress.getExpectedWorkerCount());
        return installProgress.isReady();
    }
    
    private String resolveRedisClusterLeaderHost(Integer clusterId) {
        ClusterInfoService clusterInfoService = SpringTool.getApplicationContext().getBean(ClusterInfoService.class);
        ClusterInfoEntity clusterInfo = clusterInfoService.getById(clusterId);
        if (Objects.nonNull(clusterInfo)) {
            String hostMapKey = clusterInfo.getClusterCode() + Constants.UNDERLINE + Constants.SERVICE_ROLE_HOST_MAPPING;
            HashMap<String, List<String>> hostMap = (HashMap<String, List<String>>) CacheUtils.get(hostMapKey);
            if (Objects.nonNull(hostMap)) {
                List<String> workerHosts = hostMap.get(REDIS_WORKER_ROLE_NAME);
                if (Objects.nonNull(workerHosts) && !workerHosts.isEmpty()) {
                    return workerHosts.get(0);
                }
                List<String> masterHosts = hostMap.get(REDIS_MASTER_ROLE_NAME);
                if (Objects.nonNull(masterHosts) && !masterHosts.isEmpty()) {
                    return masterHosts.get(0);
                }
            }
        }
        
        Map<String, String> globalVariables = GlobalVariables.get(clusterId);
        if (Objects.isNull(globalVariables)) {
            return null;
        }
        String workerHost = extractHost(globalVariables.get("${RedisSlaveAddr}"));
        if (StringUtils.isNotBlank(workerHost)) {
            return workerHost;
        }
        return extractHost(globalVariables.get("${RedisMasterAddr}"));
    }
    
    private String extractHost(String addresses) {
        if (StringUtils.isBlank(addresses)) {
            return null;
        }
        String[] split = addresses.trim().split("\\s+");
        if (split.length == 0 || StringUtils.isBlank(split[0])) {
            return null;
        }
        return split[0].split(":")[0];
    }
    
    private ExecResult initRedisClusterWithRetry(String leaderHost, String decompressPackageName) {
        ExecResult execResult = null;
        int tryTimes = 0;
        while (tryTimes < REDIS_CLUSTER_INIT_MAX_RETRY) {
            if (!waitForRedisClusterReady(leaderHost, decompressPackageName)) {
                logger.warn("Redis cluster init skipped because nodes are not ready, tryTimes: {}", tryTimes);
            } else {
                execResult = initRedisCluster(leaderHost, decompressPackageName);
                if (Objects.nonNull(execResult) && execResult.getExecResult()) {
                    return execResult;
                }
            }
            try {
                TimeUnit.SECONDS.sleep(REDIS_CLUSTER_INIT_RETRY_INTERVAL_SECONDS);
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
                return buildFailedResult("redis-cluster init interrupted: " + e.getMessage());
            }
            tryTimes++;
        }
        if (Objects.nonNull(execResult)) {
            return execResult;
        }
        return buildFailedResult("redis-cluster init failed");
    }
    
    private boolean waitForRedisClusterReady(String leaderHost, String decompressPackageName) {
        int tryTimes = 0;
        while (tryTimes < REDIS_CLUSTER_NODE_CHECK_MAX_RETRY) {
            ExecResult checkResult = runRedisClusterScript(leaderHost, decompressPackageName, "check");
            if (Objects.nonNull(checkResult) && checkResult.getExecResult()) {
                return true;
            }
            try {
                TimeUnit.SECONDS.sleep(REDIS_CLUSTER_NODE_CHECK_RETRY_INTERVAL_SECONDS);
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
                return false;
            }
            tryTimes++;
        }
        return false;
    }
    
    private ExecResult initRedisCluster(String leaderHost, String decompressPackageName) {
        return runRedisClusterScript(leaderHost, decompressPackageName, "create");
    }
    
    private ExecResult runRedisClusterScript(String leaderHost, String decompressPackageName, String mode) {
        try {
            ActorRef execCmdActor = ActorUtils.getRemoteActor(leaderHost, "executeCmdActor");
            if (Objects.isNull(execCmdActor)) {
                return buildFailedResult("executeCmdActor not found on host " + leaderHost);
            }
            ExecuteCmdCommand command = new ExecuteCmdCommand();
            List<String> commands = new ArrayList<>();
            commands.add("bash");
            commands.add(Constants.INSTALL_PATH + Constants.SLASH + decompressPackageName + Constants.SLASH
                    + "redis-cluster.sh");
            if (StringUtils.isNotBlank(mode)) {
                commands.add(mode);
            }
            command.setCommands(commands);
            Timeout timeout = new Timeout(Duration.create(120, TimeUnit.SECONDS));
            Future<Object> future = Patterns.ask(execCmdActor, command, timeout);
            return (ExecResult) Await.result(future, timeout.duration());
        } catch (Exception e) {
            return buildFailedResult(e.getMessage());
        }
    }
    
    private ExecResult buildFailedResult(String message) {
        ExecResult execResult = new ExecResult();
        execResult.setExecResult(false);
        execResult.setExecOut(message);
        return execResult;
    }
}

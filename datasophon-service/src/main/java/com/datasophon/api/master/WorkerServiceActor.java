/*
 *  Licensed to the Apache Software Foundation (ASF) under one or more
 *  contributor license agreements.  See the NOTICE file distributed with
 *  this work for additional information regarding copyright ownership.
 *  The ASF licenses this file to You under the Apache License, Version 2.0
 *  (the "License"); you may not use this file except in compliance with
 *  the License.  You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 *  Unless required by applicable law or agreed to in writing, software
 *  distributed under the License is distributed on an "AS IS" BASIS,
 *  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 *  See the License for the specific language governing permissions and
 *  limitations under the License.
 */

package com.datasophon.api.master;

import com.datasophon.api.load.GlobalVariables;
import com.datasophon.api.master.handler.service.ServiceHandler;
import com.datasophon.api.master.handler.service.ServiceStopHandler;
import com.datasophon.api.service.ClusterInfoService;
import com.datasophon.api.service.ClusterServiceRoleGroupConfigService;
import com.datasophon.api.service.ClusterServiceRoleInstanceService;
import com.datasophon.api.utils.ProcessUtils;
import com.datasophon.api.utils.SpringTool;
import com.datasophon.common.Constants;
import com.datasophon.common.cache.CacheUtils;
import com.datasophon.common.command.ExecuteServiceRoleCommand;
import com.datasophon.common.command.RedisClusterNotifyCommand;
import com.datasophon.common.enums.CommandType;
import com.datasophon.common.model.Generators;
import com.datasophon.common.model.ServiceConfig;
import com.datasophon.common.model.ServiceRoleInfo;
import com.datasophon.common.utils.ExecResult;
import com.datasophon.dao.entity.ClusterInfoEntity;
import com.datasophon.dao.entity.ClusterServiceRoleGroupConfig;
import com.datasophon.dao.entity.ClusterServiceRoleInstanceEntity;
import com.datasophon.dao.enums.NeedRestart;
import com.datasophon.dao.enums.ServiceRoleState;

import org.apache.commons.lang3.StringUtils;

import java.util.Arrays;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import akka.actor.ActorRef;
import akka.actor.UntypedActor;

public class WorkerServiceActor extends UntypedActor {
    
    private static final Logger logger = LoggerFactory.getLogger(WorkerServiceActor.class);
    
    private static final String REDIS_SERVICE_NAME = "REDIS";
    
    private static final String REDIS_WORKER_ROLE_NAME = "RedisWorker";
    
    @Override
    public void onReceive(Object message) throws Throwable {
        if (message instanceof ExecuteServiceRoleCommand) {
            ExecuteServiceRoleCommand executeServiceRoleCommand = (ExecuteServiceRoleCommand) message;
            
            ClusterServiceRoleGroupConfigService roleGroupConfigService =
                    SpringTool.getApplicationContext().getBean(ClusterServiceRoleGroupConfigService.class);
            ClusterServiceRoleInstanceService roleInstanceService =
                    SpringTool.getApplicationContext().getBean(ClusterServiceRoleInstanceService.class);
            
            ServiceRoleInfo serviceRoleInfo = executeServiceRoleCommand.getWorkerRole();
            ExecResult execResult = new ExecResult();
            Integer serviceInstanceId = serviceRoleInfo.getServiceInstanceId();
            ClusterServiceRoleInstanceEntity serviceRoleInstance = roleInstanceService.getOneServiceRole(
                    serviceRoleInfo.getName(),
                    serviceRoleInfo.getHostname(),
                    serviceRoleInfo.getClusterId());
            Map<Generators, List<ServiceConfig>> configFileMap = new HashMap<>();
            boolean needReConfig = false;
            if (executeServiceRoleCommand.getCommandType() == CommandType.INSTALL_SERVICE) {
                Integer roleGroupId = (Integer) CacheUtils.get("UseRoleGroup_" + serviceInstanceId);
                ClusterServiceRoleGroupConfig config = roleGroupConfigService.getConfigByRoleGroupId(roleGroupId);
                ProcessUtils.generateConfigFileMap(configFileMap, config, serviceRoleInfo.getClusterId());
            } else if (serviceRoleInstance.getNeedRestart() == NeedRestart.YES) {
                ClusterServiceRoleGroupConfig config =
                        roleGroupConfigService.getConfigByRoleGroupId(serviceRoleInstance.getRoleGroupId());
                ProcessUtils.generateConfigFileMap(configFileMap, config, serviceRoleInfo.getClusterId());
                needReConfig = true;
            }
            serviceRoleInfo.setConfigFileMap(configFileMap);
            serviceRoleInfo.setEnableRangerPlugin(false);
            switch (executeServiceRoleCommand.getCommandType()) {
                case INSTALL_SERVICE:
                    try {
                        logger.info("start to install {} int host {}", serviceRoleInfo.getName(),
                                serviceRoleInfo.getHostname());
                        execResult = ProcessUtils.startInstallService(serviceRoleInfo);
                        if (Objects.nonNull(execResult) && execResult.getExecResult()) {
                            // install success
                            ProcessUtils.saveServiceInstallInfo(serviceRoleInfo);
                            notifyRedisClusterInit(serviceRoleInfo);
                            logger.info("{} install success in {}", serviceRoleInfo.getName(),
                                    serviceRoleInfo.getHostname());
                        }
                    } catch (Exception e) {
                        logger.info("{} install failed in {}", serviceRoleInfo.getName(),
                                serviceRoleInfo.getHostname());
                        logger.error(ProcessUtils.getExceptionMessage(e));
                    }
                    break;
                case START_SERVICE:
                    try {
                        logger.info("start  {} in host {}", serviceRoleInfo.getName(), serviceRoleInfo.getHostname());
                        execResult = ProcessUtils.startService(serviceRoleInfo, needReConfig);
                        if (Objects.nonNull(execResult) && execResult.getExecResult()) {
                            // 更新角色实例状态为正在运行
                            ProcessUtils.updateServiceRoleState(CommandType.START_SERVICE,
                                    serviceRoleInfo.getName(),
                                    serviceRoleInfo.getHostname(),
                                    executeServiceRoleCommand.getClusterId(),
                                    ServiceRoleState.RUNNING);
                        }
                    } catch (Exception e) {
                        logger.error(ProcessUtils.getExceptionMessage(e));
                    }
                    break;
                case STOP_SERVICE:
                    try {
                        logger.info("stop {} in host {}", serviceRoleInfo.getName(), serviceRoleInfo.getHostname());
                        ServiceHandler serviceStopHandler = new ServiceStopHandler();
                        execResult = serviceStopHandler.handlerRequest(serviceRoleInfo);
                        if (Objects.nonNull(execResult) && execResult.getExecResult()) {// 执行成功
                            // 更新角色实例状态为停止
                            ProcessUtils.updateServiceRoleState(CommandType.STOP_SERVICE,
                                    serviceRoleInfo.getName(),
                                    serviceRoleInfo.getHostname(),
                                    executeServiceRoleCommand.getClusterId(),
                                    ServiceRoleState.STOP);
                        }
                    } catch (Exception e) {
                        logger.error(ProcessUtils.getExceptionMessage(e));
                    }
                    break;
                case RESTART_SERVICE:
                    try {
                        logger.info("restart {} in host {}", serviceRoleInfo.getName(), serviceRoleInfo.getHostname());
                        execResult = ProcessUtils.restartService(serviceRoleInfo, needReConfig);
                        if (Objects.nonNull(execResult) && execResult.getExecResult()) {
                            // 更新角色实例状态为正在运行
                            ProcessUtils.updateServiceRoleState(CommandType.RESTART_SERVICE, serviceRoleInfo.getName(),
                                    serviceRoleInfo.getHostname(), executeServiceRoleCommand.getClusterId(),
                                    ServiceRoleState.RUNNING);
                        }
                    } catch (Exception e) {
                        logger.error(ProcessUtils.getExceptionMessage(e));
                    }
                    break;
                default:
                    break;
            }
            ProcessUtils.handleCommandResult(serviceRoleInfo.getHostCommandId(), execResult.getExecResult(),
                    execResult.getExecOut());
        } else {
            unhandled(message);
        }
    }
    
    private void notifyRedisClusterInit(ServiceRoleInfo serviceRoleInfo) {
        if (!"REDIS".equalsIgnoreCase(serviceRoleInfo.getParentName())) {
            return;
        }
        if (!REDIS_WORKER_ROLE_NAME.equals(serviceRoleInfo.getName())) {
            return;
        }
        if (!isAllRedisWorkerInstalled(serviceRoleInfo.getClusterId())) {
            return;
        }
        ActorRef masterNodeProcessingActor = ActorUtils.getLocalActor(MasterNodeProcessingActor.class,
                ActorUtils.getActorRefName(MasterNodeProcessingActor.class));
        RedisClusterNotifyCommand notifyCommand = new RedisClusterNotifyCommand();
        notifyCommand.setClusterId(serviceRoleInfo.getClusterId());
        notifyCommand.setServiceName(serviceRoleInfo.getParentName());
        notifyCommand.setServiceRoleName(serviceRoleInfo.getName());
        notifyCommand.setHostname(serviceRoleInfo.getHostname());
        notifyCommand.setDecompressPackageName(serviceRoleInfo.getDecompressPackageName());
        masterNodeProcessingActor.tell(notifyCommand, getSelf());
        logger.info("all redis workers installed, notify manager to init cluster, clusterId: {}",
                serviceRoleInfo.getClusterId());
    }
    
    private boolean isAllRedisWorkerInstalled(Integer clusterId) {
        int expectedWorkerCount = getExpectedRedisWorkerCount(clusterId);
        if (expectedWorkerCount <= 0) {
            logger.warn("skip redis cluster notify because expected worker count is invalid, clusterId: {}", clusterId);
            return false;
        }
        int installedWorkerCount = getInstalledRedisWorkerCount(clusterId);
        logger.info("redis worker install progress, clusterId: {}, installed: {}, expected: {}", clusterId,
                installedWorkerCount, expectedWorkerCount);
        return installedWorkerCount >= expectedWorkerCount;
    }
    
    private int getExpectedRedisWorkerCount(Integer clusterId) {
        ClusterInfoService clusterInfoService = SpringTool.getApplicationContext().getBean(ClusterInfoService.class);
        ClusterInfoEntity clusterInfo = clusterInfoService.getById(clusterId);
        if (Objects.isNull(clusterInfo)) {
            return 0;
        }
        
        String hostMapKey = clusterInfo.getClusterCode() + Constants.UNDERLINE + Constants.SERVICE_ROLE_HOST_MAPPING;
        HashMap<String, List<String>> hostMap = (HashMap<String, List<String>>) CacheUtils.get(hostMapKey);
        if (Objects.nonNull(hostMap) && Objects.nonNull(hostMap.get(REDIS_WORKER_ROLE_NAME))) {
            return hostMap.get(REDIS_WORKER_ROLE_NAME).size();
        }
        
        Map<String, String> globalVariables = GlobalVariables.get(clusterId);
        if (Objects.isNull(globalVariables)) {
            return 0;
        }
        String workerAddress = globalVariables.get("${RedisSlaveAddr}");
        if (!StringUtils.isNotBlank(workerAddress)) {
            return 0;
        }
        return (int) Arrays.stream(workerAddress.trim().split("\\s+"))
                .filter(StringUtils::isNotBlank)
                .count();
    }
    
    private int getInstalledRedisWorkerCount(Integer clusterId) {
        ClusterServiceRoleInstanceService roleInstanceService =
                SpringTool.getApplicationContext().getBean(ClusterServiceRoleInstanceService.class);
        return roleInstanceService.lambdaQuery()
                .eq(ClusterServiceRoleInstanceEntity::getClusterId, clusterId)
                .eq(ClusterServiceRoleInstanceEntity::getServiceName, REDIS_SERVICE_NAME)
                .eq(ClusterServiceRoleInstanceEntity::getServiceRoleName, REDIS_WORKER_ROLE_NAME)
                .eq(ClusterServiceRoleInstanceEntity::getServiceRoleState, ServiceRoleState.RUNNING)
                .list()
                .size();
    }
    
}

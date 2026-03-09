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

package com.datasophon.api.utils;

import com.datasophon.api.load.GlobalVariables;
import com.datasophon.api.service.ClusterInfoService;
import com.datasophon.api.service.ClusterServiceRoleInstanceService;
import com.datasophon.common.Constants;
import com.datasophon.common.cache.CacheUtils;
import com.datasophon.dao.entity.ClusterInfoEntity;
import com.datasophon.dao.entity.ClusterServiceRoleInstanceEntity;
import com.datasophon.dao.enums.ServiceRoleState;

import org.apache.commons.lang3.StringUtils;

import java.util.Arrays;
import java.util.List;
import java.util.Map;
import java.util.Objects;

public final class RedisClusterInstallUtils {
    
    public static final String REDIS_SERVICE_NAME = "REDIS";
    
    public static final String REDIS_WORKER_ROLE_NAME = "RedisWorker";
    
    private static final String REDIS_SLAVE_ADDR_KEY = "${RedisSlaveAddr}";
    
    private RedisClusterInstallUtils() {
    }
    
    public static RedisWorkerInstallProgress getRedisWorkerInstallProgress(Integer clusterId) {
        int expectedWorkerCount = getExpectedRedisWorkerCount(clusterId);
        int installedWorkerCount = getInstalledRedisWorkerCount(clusterId);
        return new RedisWorkerInstallProgress(expectedWorkerCount, installedWorkerCount);
    }
    
    private static int getExpectedRedisWorkerCount(Integer clusterId) {
        ClusterInfoService clusterInfoService = SpringTool.getApplicationContext().getBean(ClusterInfoService.class);
        ClusterInfoEntity clusterInfo = clusterInfoService.getById(clusterId);
        if (Objects.isNull(clusterInfo)) {
            return 0;
        }
        
        String hostMapKey = clusterInfo.getClusterCode() + Constants.UNDERLINE + Constants.SERVICE_ROLE_HOST_MAPPING;
        Map<String, List<String>> hostMap = (Map<String, List<String>>) CacheUtils.get(hostMapKey);
        if (Objects.nonNull(hostMap) && Objects.nonNull(hostMap.get(REDIS_WORKER_ROLE_NAME))) {
            return hostMap.get(REDIS_WORKER_ROLE_NAME).size();
        }
        
        Map<String, String> globalVariables = GlobalVariables.get(clusterId);
        if (Objects.isNull(globalVariables)) {
            return 0;
        }
        return countAddressNodes(globalVariables.get(REDIS_SLAVE_ADDR_KEY));
    }
    
    private static int getInstalledRedisWorkerCount(Integer clusterId) {
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
    
    private static int countAddressNodes(String addresses) {
        if (StringUtils.isBlank(addresses)) {
            return 0;
        }
        return (int) Arrays.stream(addresses.trim().split("\\s+"))
                .filter(StringUtils::isNotBlank)
                .count();
    }
    
    public static final class RedisWorkerInstallProgress {
        
        private final int expectedWorkerCount;
        
        private final int installedWorkerCount;
        
        public RedisWorkerInstallProgress(int expectedWorkerCount, int installedWorkerCount) {
            this.expectedWorkerCount = expectedWorkerCount;
            this.installedWorkerCount = installedWorkerCount;
        }
        
        public int getExpectedWorkerCount() {
            return expectedWorkerCount;
        }
        
        public int getInstalledWorkerCount() {
            return installedWorkerCount;
        }
        
        public boolean isExpectedWorkerCountValid() {
            return expectedWorkerCount > 0;
        }
        
        public boolean isReady() {
            return isExpectedWorkerCountValid() && installedWorkerCount >= expectedWorkerCount;
        }
    }
}

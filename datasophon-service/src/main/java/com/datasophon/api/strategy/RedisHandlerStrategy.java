package com.datasophon.api.strategy;

import com.datasophon.api.load.GlobalVariables;
import com.datasophon.api.utils.ProcessUtils;
import com.datasophon.common.Constants;
import com.datasophon.common.cache.CacheUtils;
import com.datasophon.common.model.ServiceConfig;
import com.datasophon.common.model.ServiceRoleInfo;
import com.datasophon.common.utils.CollectionUtils;
import com.datasophon.dao.entity.ClusterInfoEntity;
import com.datasophon.dao.entity.ClusterServiceRoleInstanceEntity;

import org.apache.commons.lang3.StringUtils;

import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.stream.Collectors;

public class RedisHandlerStrategy extends ServiceHandlerAbstract implements ServiceRoleStrategy {
    
    @Override
    public void handler(Integer clusterId, List<String> hosts, String serviceName) {
        
    }
    
    @Override
    public void handlerConfig(Integer clusterId, List<ServiceConfig> list, String serviceName) {
        
    }
    
    @Override
    public void getConfig(Integer clusterId, List<ServiceConfig> list) {
        Map<String, String> globalVariables = GlobalVariables.get(clusterId);
        String masterPort = resolvePort(list, globalVariables, "redisMasterPort");
        String slavePort = resolvePort(list, globalVariables, "redisSlavePort");
        
        ClusterInfoEntity clusterInfo = ProcessUtils.getClusterInfo(clusterId);
        String hostMapKey =
                clusterInfo.getClusterCode()
                        + Constants.UNDERLINE
                        + Constants.SERVICE_ROLE_HOST_MAPPING;
        HashMap<String, List<String>> map = (HashMap<String, List<String>>) CacheUtils.get(hostMapKey);
        List<String> masterHostList = Objects.nonNull(map) ? map.get("RedisMaster") : null;
        List<String> workerHostList = Objects.nonNull(map) ? map.get("RedisWorker") : null;
        
        for (ServiceConfig serviceConfig : list) {
            if ("RedisMasterAddr".equals(serviceConfig.getName())) {
                String masterAddr = buildHostAddr(masterHostList, masterPort);
                serviceConfig.setRequired(true);
                serviceConfig.setValue(masterAddr);
            } else if ("RedisSlaveAddr".equals(serviceConfig.getName())) {
                String workerAddr = buildHostAddr(workerHostList, slavePort);
                serviceConfig.setRequired(true);
                serviceConfig.setValue(workerAddr);
            }
        }
    }
    
    private String resolvePort(List<ServiceConfig> list, Map<String, String> globalVariables, String configName) {
        String variableName = "${" + configName + "}";
        String value = Objects.nonNull(globalVariables) ? globalVariables.get(variableName) : null;
        if (StringUtils.isNotBlank(value)) {
            return value;
        }
        if (Objects.isNull(list)) {
            return null;
        }
        String fallback = list.stream()
                .filter(config -> configName.equals(config.getName()))
                .map(config -> Objects.nonNull(config.getValue()) ? String.valueOf(config.getValue()) : null)
                .filter(StringUtils::isNotBlank)
                .findFirst()
                .orElse(null);
        if (StringUtils.isNotBlank(fallback) && Objects.nonNull(globalVariables)) {
            globalVariables.put(variableName, fallback);
        }
        return fallback;
    }
    
    private String buildHostAddr(List<String> hosts, String port) {
        if (CollectionUtils.isEmpty(hosts) || StringUtils.isBlank(port)) {
            return "";
        }
        return hosts.stream()
                .map(host -> host + ":" + port)
                .collect(Collectors.joining(" "));
    }
    
    @Override
    public void handlerServiceRoleInfo(ServiceRoleInfo serviceRoleInfo, String hostname) {
        
    }
    
    @Override
    public void handlerServiceRoleCheck(ClusterServiceRoleInstanceEntity roleInstanceEntity, Map<String, ClusterServiceRoleInstanceEntity> map) {
        
    }
}

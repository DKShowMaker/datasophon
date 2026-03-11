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

package com.datasophon.api.strategy;

import com.datasophon.api.utils.ProcessUtils;
import com.datasophon.common.Constants;
import com.datasophon.common.cache.CacheUtils;
import com.datasophon.common.model.ServiceConfig;
import com.datasophon.common.model.ServiceRoleInfo;
import com.datasophon.common.utils.CollectionUtils;
import com.datasophon.dao.entity.ClusterInfoEntity;
import com.datasophon.dao.entity.ClusterServiceRoleInstanceEntity;

import org.apache.commons.lang3.StringUtils;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;

import com.alibaba.fastjson.JSONArray;

public class MinioHandlerStrategy extends ServiceHandlerAbstract implements ServiceRoleStrategy {
    
    private static final String ROLE_NAME = "MinioService";
    private static final String DATA_PATHS = "dataPaths";
    private static final String API_PORT = "apiPort";
    private static final String DEFAULT_TEMPLATE = "http://{host}:{apiPort}/data/minio/data";
    
    @Override
    public void handler(Integer clusterId, List<String> hosts, String serviceName) {
        
    }
    
    @Override
    public void handlerConfig(Integer clusterId, List<ServiceConfig> list, String serviceName) {
        applyDataPaths(clusterId, list);
    }
    
    @Override
    public void getConfig(Integer clusterId, List<ServiceConfig> list) {
        applyDataPaths(clusterId, list);
    }
    
    @Override
    public void handlerServiceRoleInfo(ServiceRoleInfo serviceRoleInfo, String hostname) {
        
    }
    
    @Override
    public void handlerServiceRoleCheck(ClusterServiceRoleInstanceEntity roleInstanceEntity,
                                        Map<String, ClusterServiceRoleInstanceEntity> map) {
        
    }
    
    private void applyDataPaths(Integer clusterId, List<ServiceConfig> list) {
        if (CollectionUtils.isEmpty(list)) {
            return;
        }
        ServiceConfig dataPathsConfig = null;
        ServiceConfig apiPortConfig = null;
        for (ServiceConfig config : list) {
            if (DATA_PATHS.equals(config.getName())) {
                dataPathsConfig = config;
            } else if (API_PORT.equals(config.getName())) {
                apiPortConfig = config;
            }
        }
        if (Objects.isNull(dataPathsConfig)) {
            return;
        }
        
        List<String> templates = normalizeToList(dataPathsConfig.getValue());
        if (CollectionUtils.isEmpty(templates)) {
            templates = new ArrayList<>();
            templates.add(DEFAULT_TEMPLATE);
        }
        
        String apiPort = resolvePort(apiPortConfig, list);
        List<String> hosts = resolveHosts(clusterId);
        
        if (CollectionUtils.isEmpty(hosts)) {
            dataPathsConfig.setValue(replacePortOnly(templates, apiPort));
            dataPathsConfig.setRequired(true);
            return;
        }
        
        boolean hasHostPlaceholder = false;
        for (String template : templates) {
            if (containsHostPlaceholder(template)) {
                hasHostPlaceholder = true;
                break;
            }
        }
        
        if (!hasHostPlaceholder) {
            dataPathsConfig.setValue(replacePortOnly(templates, apiPort));
            dataPathsConfig.setRequired(true);
            return;
        }
        
        List<String> expanded = new ArrayList<>();
        for (String template : templates) {
            if (!containsHostPlaceholder(template)) {
                expanded.add(replacePort(template, apiPort));
                continue;
            }
            for (String host : hosts) {
                expanded.add(replaceHostAndPort(template, host, apiPort));
            }
        }
        dataPathsConfig.setValue(expanded);
        dataPathsConfig.setRequired(true);
    }
    
    private List<String> normalizeToList(Object value) {
        if (Objects.isNull(value)) {
            return new ArrayList<>();
        }
        if (value instanceof JSONArray) {
            return ((JSONArray) value).toJavaList(String.class);
        }
        if (value instanceof List) {
            List<?> raw = (List<?>) value;
            List<String> list = new ArrayList<>(raw.size());
            for (Object item : raw) {
                if (Objects.nonNull(item)) {
                    list.add(String.valueOf(item));
                }
            }
            return list;
        }
        if (value instanceof String) {
            String str = (String) value;
            if (StringUtils.isBlank(str)) {
                return new ArrayList<>();
            }
            String[] parts = StringUtils.split(str);
            List<String> list = new ArrayList<>();
            if (Objects.nonNull(parts)) {
                for (String part : parts) {
                    if (StringUtils.isNotBlank(part)) {
                        list.add(part);
                    }
                }
            }
            return list;
        }
        return new ArrayList<>();
    }
    
    private String resolvePort(ServiceConfig apiPortConfig, List<ServiceConfig> list) {
        if (Objects.nonNull(apiPortConfig) && Objects.nonNull(apiPortConfig.getValue())) {
            return String.valueOf(apiPortConfig.getValue());
        }
        if (CollectionUtils.isEmpty(list)) {
            return null;
        }
        for (ServiceConfig config : list) {
            if (API_PORT.equals(config.getName()) && Objects.nonNull(config.getValue())) {
                return String.valueOf(config.getValue());
            }
        }
        return null;
    }
    
    private List<String> resolveHosts(Integer clusterId) {
        ClusterInfoEntity clusterInfo = ProcessUtils.getClusterInfo(clusterId);
        if (Objects.isNull(clusterInfo)) {
            return null;
        }
        String hostMapKey = clusterInfo.getClusterCode() + Constants.UNDERLINE + Constants.SERVICE_ROLE_HOST_MAPPING;
        HashMap<String, List<String>> map = (HashMap<String, List<String>>) CacheUtils.get(hostMapKey);
        if (Objects.isNull(map)) {
            return null;
        }
        return map.get(ROLE_NAME);
    }
    
    private boolean containsHostPlaceholder(String value) {
        if (StringUtils.isBlank(value)) {
            return false;
        }
        return value.contains("{host}") || value.contains("${host}");
    }
    
    private List<String> replacePortOnly(List<String> templates, String apiPort) {
        List<String> replaced = new ArrayList<>();
        for (String template : templates) {
            replaced.add(replacePort(template, apiPort));
        }
        return replaced;
    }
    
    private String replaceHostAndPort(String template, String host, String apiPort) {
        String value = replaceHost(template, host);
        return replacePort(value, apiPort);
    }
    
    private String replaceHost(String value, String host) {
        if (StringUtils.isBlank(value) || StringUtils.isBlank(host)) {
            return value;
        }
        return value.replace("{host}", host).replace("${host}", host);
    }
    
    private String replacePort(String value, String apiPort) {
        if (StringUtils.isBlank(value) || StringUtils.isBlank(apiPort)) {
            return value;
        }
        return value.replace("{apiPort}", apiPort)
                .replace("${apiPort}", apiPort)
                .replace("{port}", apiPort)
                .replace("${port}", apiPort);
    }
}

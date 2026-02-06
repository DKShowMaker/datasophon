# AGENTS.md

This file contains guidelines for agentic coding tools working in this repository.

## Build, Lint, and Test Commands

### Java/Maven (Backend)
```bash
# Build entire project
./mvnw clean install

# Package (create JARs)
./mvnw clean package

# Run tests (currently skipped by default in pom.xml)
./mvnw test

# Run a single test
./mvnw test -Dtest=ClassName#methodName

# Run all tests without skipping
./mvnw test -DskipTests=false

# Check code style with Checkstyle
./mvnw checkstyle:check

# Auto-format code with Spotless (also runs in pre-commit)
./mvnw spotless:apply

# Check formatting without applying changes
./mvnw spotless:check
```

### Vue.js (Frontend - datasophon-ui)
```bash
cd datasophon-ui

# Development server
npm run serve

# Production build
npm run build

# Lint code
npm run lint
```

### Pre-commit Hooks
Pre-commit hooks automatically run `./mvnw spotless:apply` on commit.

## Code Style Guidelines

### Java Backend Code

#### Imports
Order: com.datasophon, org.apache, java, javax, org, com, akka
Static imports from Guava Preconditions should use static import.

#### Naming Conventions
- Packages: `com.datasophon.module.submodule` (lowercase, dot-separated)
- Classes: `PascalCase` (e.g., `ProcessUtils`, `ClusterService`)
- Methods: `camelCase` (e.g., `saveServiceInstallInfo`, `getClusterInfo`)
- Constants (public/package/protected): `UPPER_SNAKE_CASE` (e.g., `CLUSTER_ID`)
- Private constants: Not required to be UPPER_SNAKE_CASE
- Variables: `camelCase` (e.g., `clusterId`, `hostname`)
- Parameters: `camelCase`

#### Formatting
- Indentation: 4 spaces (no tabs)
- Line length: 200 characters
- File encoding: UTF-8
- Each file must have Apache 2.0 license header at the top
- Braces required for: if, else, for, while, do blocks
- Arrays: Use Java-style declarations (`String[] args` not `String args[]`)

#### Types and Error Handling
- Java 8 compatible (source/target 1.8)
- Logger pattern: `private static final Logger logger = LoggerFactory.getLogger(ClassName.class);`
- Use `Objects.isNull()` and `Objects.nonNull()` instead of `== null` and `!= null`
- Use `StringUtils.isNotBlank()` for string checks

#### Prohibited Patterns
- Avoid `Boolean.getBoolean`, `Integer.getInteger`, `Long.getLong` - use `System.getProperties()` instead
- Avoid `org.apache.commons.lang.Validate` - use Guava Preconditions
- Avoid `org.apache.commons.lang.*` - use `org.apache.commons.lang3.*`
- Avoid `org.codehaus.jettison` - use `com.fasterxml.jackson`
- TODO comments must not contain usernames

#### Dependencies
- Use Lombok for getters/setters (`@Data` annotation)
- Use MyBatis-Plus for database operations
- Use Hutool for common utilities

### Vue Frontend Code (datasophon-ui)

#### Formatting
- Indentation: 2 spaces
- Quotes: Single quotes preferred
- Linter extends: plugin:vue/essential, eslint:recommended, @vue/prettier

#### Rules
- `console.log` and `debugger` warn in production (allowed in development)
- Space before function parentheses: disabled
- Prettier integration: partially disabled

### Python Code

#### Tools
- `isort`: Import sorting
- `black`: Code formatting
- `flake8`: Linting
- `autoflake`: Remove unused imports

## Project Structure

### Modules
- `datasophon-api`: API layer, application entry point
- `datasophon-service`: Business logic services
- `datasophon-common`: Common utilities and shared code
- `datasophon-infrastructure`: Infrastructure layer (database, networking)
- `datasophon-domain`: Domain models and business entities
- `datasophon-worker`: Worker/agent processes
- `datasophon-ui`: Vue.js frontend application

### Testing
- Use JUnit 5 (Jupiter) for Java tests
- Use Mockito for mocking
- Test files location: `src/test/java/`
- Currently, test execution is skipped by default in pom.xml

## Additional Notes

The project uses Akka for distributed actor communication. When working with actors:
- Use `ActorUtils.getLocalActor()` to get local actor references
- Use `ActorUtils.getRemoteActor()` for remote actors
- Use Patterns.ask() for request-response patterns with timeout

For database operations, use MyBatis-Plus:
- Use lambda queries: `.lambdaQuery().eq(Entity::getField, value).list()`
- Use QueryWrapper for complex queries

## 注意事项

- FreeMarker 只会接收 `configType="map"` 的参数；`configType="path"` 不会传入模板，模板里的 `${...}` 会变成 missing。
- `value` 才是运行期实际值，`defaultValue` 仅用于前端显示；`value` 为空会导致模板变量解析失败。
- `includeParams` 必须与 `parameters` 中的 `name` 完全匹配（区分大小写），且多数需要 `required=true`；否则 configs 为空会跳过 `.sh` 生成，脚本会缺失。
- 在 FTL 里：`${var}` 是 Freemarker 变量，Bash 变量请写 `$VAR`；含 `${1:-}` 之类需要转义成 `${"$"}{1:-}`，否则会触发模板语法错误。
- `INSTALL_PATH` 是datasophon的安装路径，是固有变量，不允许在`servi_ddl.json`中被重新声明或直接放入`includeParams`，但可以在`parameters`的`value`和`defaultValue`字段直接使用，一般用于该服务的默认安装路径。
- 变更 `service_ddl.json` 后需要重启 Master（或清理元数据缓存）才能重新加载；否则 `ServiceRoleJmxMap`/配置文件仍是旧数据。
- Redis 角色必须映射到 `REDIS`（`RedisMaster`/`RedisWorker`），否则服务策略/监控生成会缺失。
- 所有服务脚本通用要求：`status` 在未运行时必须 `exit 1`，否则系统会误判已启动并跳过 `start`。
- Redis Cluster 的 `cluster-config-file` 不能指向静态 conf（`redis-master.conf`/`redis-slave.conf`），必须使用 `nodes-<port>.conf`，否则会报 corrupted cluster config。
- `runAs` 为空对象会触发 `chown null:null`；要么移除 `runAs`，要么确保 user/group 非空。
- `ShellUtils.exceShell()` 内部固定用 `sh`，而 `ServiceHandler.execRunner()` 会按 shebang 选 `bash/sh`；脚本需保证 `/bin/sh` 可用或统一成 POSIX 语法。
- Prometheus 的 file_sd 配置按角色小写生成（如 `minioservice.json`/`redismaster.json`）；`prometheus.ftl` 里文件名需一致。
- MinIO 监控需设置 `metrics_path: /minio/prometheus/metrics` 且 `MINIO_PROMETHEUS_AUTH_TYPE=public`，否则 Prometheus 抓取失败。
- MinIO 用户名至少 5 字符、密码至少 8 字符且不能过于简单，否则 MinIO 无法启动。
- MinIO 数据目录必须为空且不要直接用根盘作为数据盘；必要时设置 `MINIO_CI_CD=on` 仅用于临时调试。
- 端口冲突/防火墙是 Prometheus 目标 `DOWN` 的高频原因，部署前务必检查端口占用并开放对应端口。
- Docker 部署过 Manager 后移除容器会遗留 `masterHost`，需更新 `conf/common.properties` 里的容器 ID，否则包下载会指向已删除容器。
- Redis 二进制在高版本 glibc 上构建会导致低版本机器报 `GLIBC_xxx not found`，需在低版本系统构建或使用兼容包。

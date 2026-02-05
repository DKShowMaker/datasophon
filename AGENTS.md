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

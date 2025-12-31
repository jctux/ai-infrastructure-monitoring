# GitHub Copilot Instructions · TD Workspace (Global)

**Scope**: Multi-repository workspace context  
**Última Actualización**: 2025-11-30  
**Propósito**: Instrucciones compartidas para todos los proyectos en `/Users/jc/TD/`

---

## 🌐 Workspace Overview

Este es el workspace **TD** que contiene repositorios del ecosistema StaffAI y proyectos cliente:

### StaffAI Core Platform

Repositorios que conforman la plataforma central de StaffAI:

| Repositorio | Propósito | Puerto | Stack Principal |
|-------------|-----------|--------|-----------------|
| **agent-factory** | CrewAI agent orchestration engine | 8081 | FastAPI, CrewAI, PostgreSQL, Redis, ES |
| **mcp_server** | Model Context Protocol server | 8080 | FastMCP, Elasticsearch |
| **rag** | Enterprise RAG platform with hybrid search | 8000 | FastAPI, Elasticsearch, LiteLLM |
| **staffai-api-gw** (→ rename to staffai-api-gateway) | API Gateway & authentication layer | 8003 | FastAPI, JWT, OAuth 2.0, Ollama, MCP |
| **vault** | HashiCorp Vault infrastructure | 8200 | Vault, Consul |

### Client Projects

Proyectos que utilizan la plataforma StaffAI (no forman parte del core):

| Repositorio | Propósito | Puerto | Stack Principal |
|-------------|-----------|--------|-----------------|
| **page** | StaffAI landing page & mini-CRM | 8000 | FastAPI, PostgreSQL, Jinja2 |
| **icegg-app** | School management system | 8000 | FastAPI, SQLModel, PostgreSQL, ES |

---

## 📁 Global Documentation Structure

```
/Users/jc/TD/
├── .github/                    # Global workspace context (NOT tracked by git)
│   ├── copilot-instructions.md # Este archivo
│   ├── prompts/                # Global prompts aplicables a todos los repos
│   ├── instructions/           # Cross-repository instructions
│   ├── memory-bank/            # Contexto compartido
│   └── knowledge-base/         # Conocimiento técnico compartido
├── docs/                       # Documentación consolidada del workspace
│   ├── README.md               # Índice maestro
│   ├── deployment/             # Guías de infraestructura
│   ├── reports/                # Auditorías y test reports
│   ├── planning/               # Roadmaps y specs
│   ├── scripts/                # Scripts de automatización
│   └── meta/                   # Housekeeping y metadata
│
├── STAFFAI CORE PLATFORM/      # Repositorios principales
│   ├── agent-factory/          # CrewAI orchestration
│   │   └── .github/            # Instrucciones específicas del repo
│   ├── mcp_server/             # MCP server
│   │   └── .github/            # Instrucciones específicas del repo
│   ├── rag/                    # RAG platform
│   │   └── .github/            # Instrucciones específicas del repo
│   ├── staffai-api-gw/         # API Gateway
│   │   └── .github/            # Instrucciones específicas del repo
│   └── vault/                  # Secret management
│
└── CLIENT PROJECTS/            # Proyectos cliente
    ├── page/                   # StaffAI landing (cliente)
    │   └── .github/            # Instrucciones específicas del repo
    └── icegg-app/              # School system (cliente)
        └── .github/            # Instrucciones específicas del repo
```

---

## 🎯 Global Policies

### Infrastructure Standards

**Centralized Services** (10.1.0.99):
- **PostgreSQL**: `10.1.0.99:5432` (staffai/MasterAdmin)
- **Redis**: `10.1.0.99:6379`
- **Elasticsearch**: `10.1.0.99:9200` (elastic/elasticpassword)
- **Vault**: `10.1.0.99:8200`

**Database Naming Convention**:
- `agent_factory` - agent-factory (StaffAI Core)
- `rag_db` - rag (StaffAI Core)
- `gateway_db` - staffai-api-gw (StaffAI Core)
- `aistaff_db` - page (Client Project)
- `school_db` - icegg-app (Client Project - actual)
- `icegg_db` - icegg-app (Client Project - legacy)

### Security Standards

1. **NEVER** hardcode secrets, API keys, or credentials
2. **ALWAYS** use HashiCorp Vault for secret management
3. **FALLBACK**: Environment variables only for local development
4. **ALL** services must use centralized infrastructure (10.1.0.99)

### Code Quality Standards

1. **Python**: PEP 8, type hints mandatory, async-first
2. **JavaScript**: ESLint, NO custom JS in icegg-app/page (Flowbite only)
3. **Documentation**: Spanish for UI/comments, English for code
4. **Testing**: TDD approach, pytest for all Python projects

### Documentation Standards

1. **Filenames**: 
   - Dated docs: `DESCRIPTION-YYYY-MM-DD.md`
   - Evergreen: `lowercase-with-hyphens.md`
2. **Location**: 
   - Global docs: `/Users/jc/TD/docs/`
   - Repo-specific: `{repo}/.github/` or `{repo}/docs/`
3. **Metadata**: Always include creation date and last updated timestamp
4. **Consolidation**: Document sources when merging files

---

## 🔗 Repository-Specific Instructions

Each repository has its own `.github/copilot-instructions.md` with detailed guidance:

### StaffAI Core Platform

#### agent-factory
- **Location**: `/Users/jc/TD/agent-factory/.github/copilot-instructions.md`
- **Focus**: CrewAI flows, memory, knowledge, telemetry
- **Critical Docs**: 
  - `.github/LESSONS_LEARNED.md`
  - `docs/development/lessons-learned.md`
  - `.github/CREWAI_FEATURES_FORENSIC_ANALYSIS.md`

#### mcp_server
- **Location**: `/Users/jc/TD/mcp_server/.github/copilot-instructions.md`
- **Focus**: FastMCP server, Elasticsearch search
- **Best Practices**: 
  - `docs/fastmcp-best-practices.md`
  - Lazy resource loading
  - Proper middleware stack

#### rag
- **Location**: `/Users/jc/TD/rag/.github/copilot-instructions.md`
- **Focus**: Enterprise RAG, hybrid search, LiteLLM gateway
- **Critical Features**:
  - BM25 + Dense Vectors + ELSER fusion
  - Multi-provider LLM support
  - Cross-project integration (agent-factory, page, icegg-app)
  - Document ingestion pipeline

#### staffai-api-gw
- **Location**: `/Users/jc/TD/staffai-api-gw/.github/copilot-instructions.md`
- **Focus**: API Gateway, authentication, rate limiting
- **Key Features**:
  - JWT & OAuth 2.0
  - Multi-provider routing
  - Cost tracking and quotas

#### vault
- **Location**: `/Users/jc/TD/vault/`
- **Focus**: Secret management infrastructure
- **Docs**: QUICKSTART.md, CHEATSHEET.md

### Client Projects

#### page
- **Location**: `/Users/jc/TD/page/.github/copilot-instructions.md`
- **Focus**: Landing page, mini-CRM, Cal.com integration
- **Critical Rules**: 
  - Flowbite-only UI (no custom JS)
  - Multi-language (en/es) with i18n
  - Internal CRM (no external integrations)
- **StaffAI Integration**: Uses RAG for lead enrichment and chatbot

#### icegg-app
- **Location**: `/Users/jc/TD/icegg-app/.github/copilot-instructions.md`
- **Focus**: School management, SSR-first, Flowbite
- **Critical Rules**: 
  - NO custom JavaScript
  - Post-Redirect-Get pattern
  - Vault for secrets
  - Development mode active (break freely)
- **StaffAI Integration**: Uses RAG for policy search and educational content

---

## �� Housekeeping Standards

**Frequency**: Quarterly or when >5 files accumulate in root

**Process**: Follow `/Users/jc/TD/.github/prompts/housekeep-docs.prompt.md`

**Key Principles**:
1. Preserve metadata and historical context
2. Consolidate duplicates, don't delete
3. Use consistent naming conventions
4. Update indices when moving files
5. Verify links after reorganization

---

## 🔧 Cross-Repository Tools

### Database Management
```bash
# Setup all databases
/Users/jc/TD/docs/scripts/setup-databases.sh

# Access PostgreSQL
docker run --rm -it -e PGPASSWORD=MasterAdmin postgres:16-alpine \
  psql -h 10.1.0.99 -U staffai -d [database_name]
```

### Code Cleanup
```bash
# Review before executing
/Users/jc/TD/docs/scripts/cleanup-code.sh
```

### Health Checks
```bash
# StaffAI Core Platform
curl http://localhost:8081/docs  # agent-factory
curl http://localhost:8080/health  # mcp_server
curl http://localhost:8000/api/health  # rag
curl http://localhost:8003/health  # staffai-api-gw

# Client Projects
curl http://localhost:8000/health  # page
curl http://localhost:8000/docs  # icegg-app
```

---

## 📊 Decision Matrix

### When to Use Global vs. Repo-Specific Instructions

**Use Global Instructions** (`/Users/jc/TD/.github/`) for:
- ✅ Infrastructure configuration (10.1.0.99 services)
- ✅ Security policies (Vault, secrets management)
- ✅ Documentation standards
- ✅ Naming conventions
- ✅ Cross-repository workflows

**Use Repo-Specific Instructions** (`{repo}/.github/`) for:
- ✅ Technology stack specifics (CrewAI, FastMCP, etc.)
- ✅ Architecture patterns (SSR, flows, etc.)
- ✅ Code style guides
- ✅ Testing strategies
- ✅ Deployment procedures

---

## 🚀 Quick Start for New Features

1. **Check Global Instructions**: Review this file for workspace-wide policies
2. **Check Repo Instructions**: Read repo-specific `.github/copilot-instructions.md`
3. **Review Relevant Docs**: Check `docs/` and repo-specific documentation
4. **Follow TDD**: Write tests first
5. **Use Centralized Services**: Always use 10.1.0.99 infrastructure
6. **Document Changes**: Update appropriate README or create timestamped doc

---

## 📚 Key Documentation References

### Global Documentation
- **Migration Guide**: `docs/deployment/INFRASTRUCTURE_MIGRATION_2025-11-30.md`
- **Test Report**: `docs/reports/MIGRATION_TEST_REPORT_2025-11-30.md`
- **Quick Reference**: `docs/deployment/QUICKREF_MIGRATION.md`
- **Housekeeping**: `docs/meta/housekeeping-2025-11-30.md`

### Planning & Architecture
- **Roadmap**: `docs/planning/implementation-roadmap.md`
- **Architecture**: `docs/planning/integration-architecture.md`
- **Specifications**: `docs/planning/technical-specifications.md`

---

## ⚠️ Common Pitfalls

1. **Don't** create custom JavaScript in icegg-app or page (use Flowbite)
2. **Don't** hardcode database hosts (use 10.1.0.99)
3. **Don't** skip Vault migration (no secrets in .env)
4. **Don't** ignore repo-specific instructions
5. **Don't** forget to update documentation indices

---

## 🔄 Workflow Integration

### For Multi-Repo Changes

1. **Plan**: Document in `docs/planning/`
2. **Execute**: Apply to each repo following repo-specific rules
3. **Test**: Individual repo tests + integration tests
4. **Document**: Create timestamped report in `docs/reports/`
5. **Housekeep**: Run housekeeping if >5 new files created

### For Infrastructure Changes

1. **Update Global Docs**: Modify relevant files in `docs/deployment/`
2. **Update Repo Configs**: Modify docker-compose.yml in each repo
3. **Test Each Repo**: Verify connectivity and functionality
4. **Create Report**: Document in `docs/reports/`
5. **Update Instructions**: Modify this file if policies changed

---

## 📝 Contributing to Global Context

When adding to `/Users/jc/TD/.github/`:

1. **Prompts** (`prompts/`): Reusable task automation prompts
2. **Instructions** (`instructions/`): Cross-cutting technical guidance
3. **Memory Bank** (`memory-bank/`): Project history and decisions
4. **Knowledge Base** (`knowledge-base/`): Technical patterns and solutions

**Remember**: This folder is NOT tracked by git. It's local workspace context.

---

**Last Updated**: 2025-11-30  
**Maintained By**: AI-assisted development workflow  
**Status**: Active and evolving

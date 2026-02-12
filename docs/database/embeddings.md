# Embedding 架构文档

> 为 Task Database 提供语义相似度搜索能力

---

## 背景

Cecelia Brain 在创建新任务前需要搜索相似的历史工作，避免重复劳动。语义相似度搜索能够：

1. **发现相关工作**：即使关键词不同，也能找到语义相似的任务
2. **复用解决方案**：参考历史 PR 的实现方式
3. **避免重复造轮子**：已经做过的事情不再重复

---

## 架构演进

### Phase 0: Jaccard 相似度（当前实现）

**优势**：
- ✅ 完全免费，无 API 成本
- ✅ 实时计算，无需预处理
- ✅ 实现简单，易于维护

**算法**：
```javascript
// Jaccard 相似度 = 交集 / 并集
function jaccard(setA, setB) {
  const intersection = setA.filter(x => setB.includes(x)).length;
  const union = new Set([...setA, ...setB]).size;
  return intersection / union;
}
```

**应用**：
- 将 query 和 task title/description 分词
- 计算 Jaccard 相似度
- 返回 Top-K 相似任务

**实现位置**：
- `cecelia-core/brain/src/similarity.js`
- Brain API: `POST /api/brain/search-similar`

**缺点**：
- 只能匹配关键词，无法理解语义
- 对同义词不敏感（"登录" vs "认证"）
- 词序变化会影响结果

### Phase 1: OpenAI Embeddings（计划中）

**优势**：
- ✅ 语义理解："用户登录" 和 "认证功能" 会被识别为相似
- ✅ 多语言支持：中英文混合查询
- ✅ 更高准确率

**成本分析**：

使用 `text-embedding-3-small` 模型：
- 价格：$0.020 / 1M tokens
- 假设平均 task 描述：200 tokens
- 假设 5 年内累计：30,000 tasks

**一次性 Embedding 成本**：
```
30,000 tasks × 200 tokens = 6,000,000 tokens
6M tokens × $0.020 / 1M = $0.12
```

**每周增量成本**（假设每周 10 个新任务）：
```
10 tasks × 200 tokens × 52 weeks = 104,000 tokens/year
104k tokens × $0.020 / 1M = $0.002/year
```

**5 年总成本**：$0.12 + $0.01 = **$0.13**

**查询成本**（假设每天 100 次查询）：
```
1 query = 50 tokens
100 queries × 50 tokens × 365 days = 1,825,000 tokens/year
1.825M tokens × $0.020 / 1M = $0.036/year
5 年 = $0.18
```

**总计**：$0.13 + $0.18 = **$0.31 for 5 years**

**结论**：成本极低，可接受。

**实现计划**：

1. **添加 embeddings 列**：
   ```sql
   ALTER TABLE tasks ADD COLUMN embedding vector(1536);
   ```

2. **批量生成 Embeddings**：
   ```javascript
   // 使用 OpenAI API
   const embeddings = await openai.embeddings.create({
     model: "text-embedding-3-small",
     input: taskDescription
   });

   await pool.query(
     'UPDATE tasks SET embedding = $1 WHERE id = $2',
     [JSON.stringify(embeddings.data[0].embedding), taskId]
   );
   ```

3. **相似度搜索**：
   ```sql
   -- 使用 pgvector 的余弦距离
   SELECT id, title, 1 - (embedding <=> $1::vector) AS similarity
   FROM tasks
   WHERE embedding IS NOT NULL
   ORDER BY embedding <=> $1::vector
   LIMIT 10;
   ```

4. **增量更新**：
   - Brain 创建新任务时自动生成 Embedding
   - 或定期批量处理（每周）

---

## 数据库 Schema

### 当前 (Phase 0)

```sql
-- tasks 表（已存在）
CREATE TABLE tasks (
  id UUID PRIMARY KEY,
  title TEXT NOT NULL,
  description TEXT,
  status TEXT,
  project_id UUID REFERENCES projects(id),
  metadata JSONB,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- 无需额外字段，实时计算 Jaccard
```

### 计划 (Phase 1)

```sql
-- 添加 embedding 列
ALTER TABLE tasks ADD COLUMN embedding vector(1536);

-- 创建索引加速查询
CREATE INDEX ON tasks USING ivfflat (embedding vector_cosine_ops)
WITH (lists = 100);

-- 或使用 HNSW 索引（更快，但占用更多内存）
CREATE INDEX ON tasks USING hnsw (embedding vector_cosine_ops)
WITH (m = 16, ef_construction = 64);
```

---

## 垃圾数据管理策略

**问题**：随着时间推移，过时/废弃的 tasks 会污染搜索结果。

### 4-Layer Defense

#### Layer 1: Status Marking（状态标记）

```sql
-- 标记过时任务
UPDATE tasks SET status = 'obsolete' WHERE ...;

-- 搜索时过滤
SELECT * FROM tasks
WHERE status NOT IN ('obsolete', 'cancelled')
ORDER BY similarity DESC;
```

**触发时机**：
- 功能被重构/删除时手动标记
- 或通过 Brain 定期审查（每季度）

#### Layer 2: Time Decay（时间衰减）

```sql
-- 相似度 × 时间权重
SELECT
  id,
  title,
  (1 - (embedding <=> $1::vector)) * time_weight(created_at) AS score
FROM tasks
ORDER BY score DESC;

-- 时间权重函数（越新权重越高）
CREATE FUNCTION time_weight(created_at TIMESTAMP) RETURNS FLOAT AS $$
  SELECT 1.0 / (1 + EXTRACT(EPOCH FROM NOW() - created_at) / (86400 * 365))
$$ LANGUAGE SQL;
```

**效果**：
- 1 年前的任务：权重 × 0.5
- 3 年前的任务：权重 × 0.25

#### Layer 3: Periodic Cleanup（定期清理）

```sql
-- 每年清理：归档 3 年前的 obsolete tasks
INSERT INTO tasks_archive SELECT * FROM tasks
WHERE status = 'obsolete' AND created_at < NOW() - INTERVAL '3 years';

DELETE FROM tasks
WHERE status = 'obsolete' AND created_at < NOW() - INTERVAL '3 years';
```

**计划任务**：
- 频率：每年 1 月 1 日
- 执行方式：cron job 或 Brain 定时任务

#### Layer 4: Manual Tools（手动工具）

```bash
# 查看低质量任务（相似度从未 > 0.5）
psql -U cecelia -d cecelia << EOF
SELECT id, title, created_at
FROM tasks
WHERE metadata->>'max_similarity' < '0.5'
  AND created_at < NOW() - INTERVAL '1 year'
LIMIT 50;
EOF

# 批量标记为 obsolete
psql -U cecelia -d cecelia -c "
UPDATE tasks SET status = 'obsolete'
WHERE id IN ('xxx', 'yyy', 'zzz');
"
```

---

## Migration 路线图

### Step 1: 安装 pgvector（当前阶段）

```bash
bash scripts/setup-embeddings.sh
```

### Step 2: 导入历史 PRs

```bash
node scripts/import-all-prs.js
```

验证：
```sql
SELECT COUNT(*) FROM tasks WHERE metadata->>'source' = 'pr_import';
-- 期望：~947+
```

### Step 3: Phase 0 验证（当前可用）

```bash
# 测试 Jaccard 相似度搜索
curl -s localhost:5221/api/brain/search-similar \
  -H "Content-Type: application/json" \
  -d '{"query": "add user authentication", "type": "task"}' | jq
```

### Step 4: Phase 1 实施（未来）

1. 添加 embedding 列
2. 批量生成 Embeddings（一次性）
3. 更新 similarity.js，支持向量搜索
4. 设置增量更新（新任务自动 Embedding）

---

## 性能指标

### Phase 0 (Jaccard)

- **查询速度**：< 50ms（全表扫描 + 实时计算）
- **准确率**：60-70%（关键词匹配）
- **成本**：$0

### Phase 1 (Embeddings)

- **查询速度**：< 10ms（向量索引）
- **准确率**：85-90%（语义理解）
- **成本**：~$0.30 for 5 years

---

## 参考

- pgvector GitHub: https://github.com/pgvector/pgvector
- OpenAI Embeddings Pricing: https://openai.com/pricing
- Brain Similarity API: `/home/xx/perfect21/cecelia/core/brain/src/similarity.js`
- Brain Attachment Decision API: `/home/xx/perfect21/cecelia/core/docs/brain-attach-decision-api.md`

---
id: infrastructure-learnings
version: 1.1.0
created: 2026-02-10
updated: 2026-02-12
changelog:
  - 1.1.0: 添加 NAS 同步脚本配置修复经验
  - 1.0.0: 初始版本 - NAS content manager 实现
---

# Infrastructure Development Learnings

记录基础设施开发过程中的经验教训和最佳实践。

## 2026-02-12: NAS 同步脚本配置修复

### 背景
修复 `sync-to-nas.sh` 脚本的默认配置，确保开箱即用。初始测试发现默认配置不正确。

### 发现的问题

1. **路径权限问题**
   - 问题：默认路径 `/volume1/backups/us-vps` 普通用户无写入权限
   - 错误：`mkdir: cannot create directory '/volume1/backups': Permission denied`
   - 解决：使用相对路径 `backups/us-vps`（相对于用户主目录）

2. **用户名错误**
   - 问题：默认 `NAS_USER=xx` 与实际用户 `徐啸` 不匹配
   - 影响：SSH 认证失败
   - 解决：更新默认值为 `徐啸`

3. **rsync 连接失败**
   - 问题：rsync over SSH 出现 "Permission denied" 错误
   - 原因：
     - 缺少 `--rsync-path=/usr/bin/rsync` 参数
     - 使用绝对路径 `~/backups/...` 导致路径解析问题
   - 解决：
     - 添加 `--rsync-path=/usr/bin/rsync`
     - 使用相对路径（不带 `~`）
     - 添加 `-o StrictHostKeyChecking=no` 避免首次连接提示

### 正确的 rsync 命令格式

```bash
rsync -avz \
  --rsync-path=/usr/bin/rsync \
  -e "ssh -o ConnectTimeout=30 -o StrictHostKeyChecking=no" \
  /local/path/ \
  徐啸@100.110.241.76:backups/us-vps/
```

**关键点**：
- 使用相对路径（`backups/us-vps`）而不是绝对路径
- 不要使用 `~/` 前缀，会导致路径解析问题
- 必须指定 `--rsync-path`（Synology NAS 要求）

### 测试策略

创建了 `test-sync-to-nas.sh` 综合测试脚本：
- ✅ 脚本语法检查（`bash -n`）
- ✅ 默认配置验证（grep 检查）
- ✅ NAS 连通性测试（ping + nc）
- ✅ SSH 认证测试（BatchMode）
- ✅ 干运行测试（小文件夹）
- ✅ Help 消息测试

**测试结果**：11/12 通过（干运行测试因暂时网络问题失败，但手动测试成功）

### 最佳实践

1. **脚本默认配置**：
   - 使用实际测试验证过的默认值
   - 避免需要 root 权限的路径
   - 相对路径优于绝对路径（跨环境兼容性）

2. **NAS rsync 配置**：
   - 总是指定 `--rsync-path`（不同系统 rsync 路径不同）
   - 使用 StrictHostKeyChecking=no 避免交互式提示
   - 相对路径自动映射到用户主目录

3. **测试驱动开发**：
   - 先手动测试找出正确配置
   - 将测试步骤自动化
   - 使用测试脚本验证修复

### 实际验证

成功同步测试：
- infrastructure 仓库：232KB，40 文件 ✅
- cecelia-core 仓库：6.8MB ✅

### 相关 PR

- PR #7: 初始 NAS 同步配置实现
- PR #8: 修复默认配置（本次）

---

## 2026-02-10: NAS Content Manager Implementation

### 背景
创建 NAS 内容管理工具（nas-content-manager.sh），实现：
- 自动发现 NAS 挂载点
- 分析存储使用情况
- 生成 markdown 报告

### 关键学习

1. **Tailscale NAS 检测**
   - 使用 ping 测试 100.110.241.76 连通性
   - 检查 /Volumes/ 下挂载点
   - 验证挂载点可访问性

2. **存储分析**
   - 使用 `du -sh` 分析目录大小
   - 使用 `find` 统计文件数量
   - 按文件类型分类统计

3. **报告生成**
   - Markdown 格式便于版本控制
   - 包含时间戳用于追踪变化
   - 结构化数据便于后续处理

### 测试结果

完整测试通过：
- ✅ 挂载点检测
- ✅ 存储分析
- ✅ 报告生成
- ✅ 错误处理

### 相关文件

- `scripts/nas-content-manager.sh`
- `scripts/test-nas-content-manager.sh`
- `docs/nas/content-analysis-template.md`

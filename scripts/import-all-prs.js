#!/usr/bin/env node
import { execSync } from 'child_process';
import pg from 'pg';
const { Pool } = pg;

// 数据库连接（直接连接，不依赖 cecelia-core）
const pool = new Pool({
  host: 'localhost',
  port: 5432,
  database: 'cecelia',
  user: 'cecelia',
  password: 'cecelia'
});

// 所有需要导入的 repositories
const REPOS = [
  // Cecelia 系列
  { path: '/home/xx/perfect21/cecelia/core', name: 'cecelia-core', owner: 'perfectuser21' },
  { path: '/home/xx/perfect21/cecelia/engine', name: 'cecelia-engine', owner: 'perfectuser21' },
  { path: '/home/xx/perfect21/cecelia/workspace', name: 'cecelia-workspace', owner: 'perfectuser21' },
  { path: '/home/xx/perfect21/cecelia/workflows', name: 'cecelia-workflows', owner: 'perfectuser21' },
  { path: '/home/xx/perfect21/cecelia/quality', name: 'cecelia-quality', owner: 'perfectuser21' },

  // ZenithJoy 系列
  { path: '/home/xx/perfect21/zenithjoy/workspace', name: 'zenithjoy-workspace', owner: 'perfectuser21' },
  { path: '/home/xx/perfect21/zenithjoy/creator', name: 'creator', owner: 'zenjoymedia' },
  { path: '/home/xx/perfect21/zenithjoy/geoai', name: 'geoai', owner: 'zenjoymedia' },
  { path: '/home/xx/perfect21/zenithjoy/JNSY-Label', name: 'JNSY-Label', owner: 'zenjoymedia' },

  // 其他项目
  { path: '/home/xx/perfect21/infrastructure', name: 'infrastructure', owner: 'perfectuser21' },
  { path: '/home/xx/perfect21/investment/trading-system', name: 'trading-system', owner: 'perfectuser21' },
  { path: '/home/xx/perfect21/toutiao-publisher-system', name: 'toutiao-publisher-system', owner: 'perfectuser21' },
  { path: '/home/xx/perfect21/platform/infra', name: 'platform-infra', owner: 'perfectuser21' },
];

async function main() {
  console.log('🚀 导入所有 Repository 的 PR 到 Task Database\n');

  let totalPRs = 0;
  let totalImported = 0;
  const summary = [];

  for (const repo of REPOS) {
    console.log(`📦 ${repo.name} (${repo.owner}/${repo.name})`);

    try {
      // 检查路径是否存在
      try {
        execSync(`test -d "${repo.path}"`, { encoding: 'utf-8' });
      } catch {
        console.log(`   ⚠️  路径不存在，跳过\n`);
        summary.push({ repo: repo.name, prs: 0, imported: 0, skipped: true });
        continue;
      }

      // 获取或创建 project
      let projectId;
      const existing = await pool.query('SELECT id FROM projects WHERE repo_path = $1', [repo.path]);
      if (existing.rows.length > 0) {
        projectId = existing.rows[0].id;
      } else {
        const result = await pool.query(
          'INSERT INTO projects (name, repo_path, metadata) VALUES ($1, $2, $3) RETURNING id',
          [repo.name, repo.path, JSON.stringify({ auto_created: 'true', created_by: 'import-all-prs' })]
        );
        projectId = result.rows[0].id;
        console.log(`   ➕ Created project (ID: ${projectId})`);
      }

      // 获取所有 merged PRs（limit 500）
      const stdout = execSync(
        `gh pr list --repo ${repo.owner}/${repo.name} --state merged --limit 500 --json number,title,body,mergedAt,author,files 2>&1 || echo "[]"`,
        { cwd: repo.path, encoding: 'utf-8', timeout: 60000 }
      );

      const prs = JSON.parse(stdout);
      console.log(`   Found ${prs.length} merged PRs`);
      totalPRs += prs.length;

      // 导入每个 PR
      let imported = 0;
      for (const pr of prs) {
        // 检查是否已存在（幂等性）
        const existing = await pool.query(
          'SELECT id FROM tasks WHERE metadata->>\'pr_number\' = $1 AND project_id = $2',
          [pr.number.toString(), projectId]
        );
        if (existing.rows.length > 0) continue;

        // 提取 PR 作者和文件列表
        const prAuthor = pr.author?.login || 'unknown';
        const prFiles = pr.files ? pr.files.map(f => f.path || f) : [];

        // 插入 task
        await pool.query(
          `INSERT INTO tasks (
            title, description, status, project_id,
            completed_at, created_at, updated_at, metadata
          ) VALUES ($1, $2, 'completed', $3, $4, $4, $4, $5)`,
          [
            pr.title,
            pr.body || '',
            projectId,
            new Date(pr.mergedAt),
            JSON.stringify({
              pr_number: pr.number,
              pr_author: prAuthor,
              pr_files: prFiles,
              source: 'pr_import',
              repo: repo.name
            })
          ]
        );
        imported++;
      }

      console.log(`   ✅ Imported ${imported} new tasks\n`);
      totalImported += imported;
      summary.push({ repo: repo.name, prs: prs.length, imported });

    } catch (err) {
      console.error(`   ❌ Error: ${err.message}\n`);
      summary.push({ repo: repo.name, error: err.message });
    }
  }

  // 打印汇总
  console.log('\n📊 导入总结');
  console.log('─'.repeat(60));
  for (const s of summary) {
    if (s.skipped) {
      console.log(`   ${s.repo.padEnd(30)} (路径不存在)`);
    } else if (s.error) {
      console.log(`   ${s.repo.padEnd(30)} ❌ ${s.error}`);
    } else {
      console.log(`   ${s.repo.padEnd(30)} ${s.prs} PRs (${s.imported} new)`);
    }
  }
  console.log('─'.repeat(60));
  console.log(`   ✅ 总计: ${totalPRs} PRs, 新导入 ${totalImported} tasks\n`);

  await pool.end();
}

main().catch(err => {
  console.error('Fatal error:', err);
  process.exit(1);
});

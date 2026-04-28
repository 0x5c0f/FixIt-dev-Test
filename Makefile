# Hugo 博客管理 Makefile
# 用于自动化构建、提交和发布流程

# ============================================================================
# 变量定义
# ============================================================================
COMMITINFO := $(msg)
PUBLICGITDIR := $(shell pwd)/public
DEVOPSGITDIR := $(shell pwd)/devops
NOTESGITDIR := $(shell pwd)
CREATEF := $(file)
DATE := $(shell date +'%y%m%d%H%M%S')
DATE_SHORT := $(shell date +'%m.%d')
DATE_PREFIX := $(shell date +'%y%m%d')
THEMES_VERSION := $(shell (cd themes/FixIt && git describe --tags --always --dirty 2>/dev/null || echo "unknown"))
HUGO_VERSION := $(shell hugo version 2>/dev/null | awk '{print $$2}' || echo "unknown")
PAGEFIND_VERSION := $(shell pagefind -V 2>/dev/null |awk '{print $$2}' || echo "unknown")

# 默认目标
.DEFAULT_GOAL := help

# ============================================================================
# 主要工作流
# ============================================================================

all: pro ## 本地运行测试(生产模式)

commit: build commit-pub commit-dev commit-notes ## 打包并提交所有内容(不创建tag)

push: push-pub push-dev push-notes ## 推送所有内容到Github仓库(自动处理tag)

release: commit push ## 完整发布流程

# ============================================================================
# 帮助信息
# ============================================================================

.PHONY: help
help: ## 显示所有可用命令
	@echo "=========================================="
	@echo "Hugo 博客管理工具"
	@echo "作者: 0x5c0f"
	@echo "版本: 0.1.2"
	@echo "=========================================="
	@echo ""
	@echo "可用命令："
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'
	@echo ""
	@echo "使用示例："
	@echo "  make commit msg='更新文章'"
	@echo "  make push"
	@echo "  make create file='linux/example.md'"
	@echo ""

# ============================================================================
# 测试和调试
# ============================================================================

.PHONY: test
test: ## 显示当前状态信息
	@echo "=========================================="
	@echo "当前配置信息"
	@echo "=========================================="
	@echo "提交信息: $(COMMITINFO)"
	@echo "Public目录: $(PUBLICGITDIR)"
	@echo "DevOps目录: $(DEVOPSGITDIR)"
	@echo "Notes目录: $(NOTESGITDIR)"
	@echo "Hugo版本: $(HUGO_VERSION)"
	@echo "PageFind版本: $(PAGEFIND_VERSION)"
	@echo "主题版本: $(THEMES_VERSION)"
	@echo "日期标识: $(DATE)"
	@echo ""

# ============================================================================
# 构建相关
# ============================================================================

.PHONY: check-lastmod
check-lastmod: ## 检查并更新修改文章的lastmod字段
	@echo ">> 检查文章修改状态"
	@CURRENT_TIME=$$(date +"%Y-%m-%d"); \
	MODIFIED_FILES=$$(git status --porcelain content/ 2>/dev/null | grep -E '\.md"?$$' | awk '{print $$NF}' | sed 's/"//g' || true); \
	if [ -n "$$MODIFIED_FILES" ]; then \
		echo "发现修改的文章，更新 lastmod:"; \
		echo "$$MODIFIED_FILES" | while read -r file; do \
			if [ -f "$$file" ]; then \
				echo "  → 处理文件: $$file"; \
				if grep -q "^lastmod:" "$$file"; then \
					sed -i "s|^lastmod:.*|lastmod: $$CURRENT_TIME|" "$$file"; \
					echo "    ✓ 已更新"; \
				else \
					echo "    ✗ 未找到 lastmod 字段"; \
				fi; \
			fi; \
		done; \
		echo "✓ lastmod 更新完成"; \
	else \
		echo "○ 没有修改的文章"; \
	fi

.PHONY: build
build: check-hugo check-lastmod ## 构建生产版本
	@echo ">> 创建版本文件"
	@echo '{"Author": "0x5c0f","Title": "一个曾经的小码农...","UpdateTime": "$(DATE)","ThemesVersion": "$(THEMES_VERSION)","HugoVersion": "$(HUGO_VERSION)","PageFindVersion": "$(PAGEFIND_VERSION)","Description": "task: update https://blog.0x5c0f.cc at Github $(COMMITINFO)"}' > $(NOTESGITDIR)/static/version.json
	@echo ">> 生成正式发布内容"
	@hugo --minify
	@echo ">> 构建 pagefind 文件索引"
	@pagefind --site public

.PHONY: clean
clean: ## 清理生成的文件
	@echo ">> 清理生成的文件"
	@find $(NOTESGITDIR)/public -mindepth 1 -name ".git" -prune -o -exec rm -rf {} +
	@rm -rf $(NOTESGITDIR)/resources
	@rm -f $(NOTESGITDIR)/static/version.json
	@echo "清理完成"

# ============================================================================
# Public 仓库操作
# ============================================================================

.PHONY: commit-pub
commit-pub: ## 提交发布内容
	@echo "=========================================="
	@echo ">> 提交 Public 仓库"
	@echo "=========================================="
	@cd $(PUBLICGITDIR) && \
		if ! git rev-parse --git-dir >/dev/null 2>&1; then \
			echo "错误: $(PUBLICGITDIR) 不是有效的git仓库"; \
			exit 1; \
		fi && \
		git add . && \
		if ! git diff --cached --quiet 2>/dev/null; then \
			git commit -m "task: update https://blog.0x5c0f.cc at Github $(COMMITINFO)"; \
			echo "✓ Public 仓库已提交"; \
		else \
			echo "○ Public 仓库无变更"; \
		fi

.PHONY: push-pub
push-pub: ## 推送发布内容到GitHub
	@echo ">> 推送 Public 到 GitHub"
	@cd $(PUBLICGITDIR) && \
		if ! git rev-parse --git-dir >/dev/null 2>&1; then \
			echo "错误: $(PUBLICGITDIR) 不是有效的git仓库"; \
			exit 1; \
		fi && \
		git push --all
	@echo "✓ Public 推送完成"

# ============================================================================
# DevOps 仓库操作
# ============================================================================

.PHONY: commit-dev
commit-dev: ## 提交 DevOps 内容
	@echo "=========================================="
	@echo ">> 提交 DevOps 仓库"
	@echo "=========================================="
	@cd $(DEVOPSGITDIR) && \
		if ! git rev-parse --git-dir >/dev/null 2>&1; then \
			echo "错误: $(DEVOPSGITDIR) 不是有效的git仓库"; \
			exit 1; \
		fi && \
		git add . && \
		if ! git diff --cached --quiet 2>/dev/null; then \
			git commit -m "task: update 0x5c0f/devops at Github $(COMMITINFO)"; \
			echo "✓ DevOps 仓库已提交"; \
		else \
			echo "○ DevOps 仓库无变更"; \
		fi

.PHONY: push-dev
push-dev: ## 推送 DevOps 内容到GitHub
	@echo ">> 推送 DevOps 到 GitHub"
	@cd $(DEVOPSGITDIR) && \
		if ! git rev-parse --git-dir >/dev/null 2>&1; then \
			echo "错误: $(DEVOPSGITDIR) 不是有效的git仓库"; \
			exit 1; \
		fi && \
		git push --all
	@echo "✓ DevOps 推送完成"

# ============================================================================
# Notes 仓库操作
# ============================================================================

.PHONY: commit-notes
commit-notes: ## 提交笔记系统内容
	@echo "=========================================="
	@echo ">> 提交 Notes 仓库"
	@echo "=========================================="
	@cd $(NOTESGITDIR) && \
		git add . && \
		if ! git diff --cached --quiet 2>/dev/null; then \
			git commit -m "task: update 0x5c0f/notes at Github on $(DATE_SHORT) $(COMMITINFO)"; \
			echo "✓ Notes 仓库已提交"; \
		else \
			echo "○ Notes 仓库无变更"; \
		fi

.PHONY: tag-daily
tag-daily: ## 为当天创建/更新唯一tag
	@echo ">> 处理当天标签"
	@OLD_TAG=$$(git tag -l "v$(DATE_PREFIX)*" | head -n 1); \
	if [ -n "$$OLD_TAG" ]; then \
		echo "删除旧标签: $$OLD_TAG"; \
		git tag -d $$OLD_TAG 2>/dev/null || true; \
		if git ls-remote --tags origin 2>/dev/null | grep -q "refs/tags/$$OLD_TAG"; then \
			echo "删除远程旧标签: $$OLD_TAG"; \
			git push origin :refs/tags/$$OLD_TAG 2>/dev/null || true; \
		fi; \
	fi; \
	echo "创建新标签: v$(DATE)"; \
	git tag -a v$(DATE) -m "task: update 0x5c0f/notes at Github $(COMMITINFO)"; \
	echo "✓ 标签已更新"

.PHONY: push-notes
push-notes: tag-daily ## 推送笔记系统到GitHub(自动处理当天tag)
	@echo ">> 推送 Notes 到 GitHub"
	@cd $(NOTESGITDIR) && git push --all && git push --tags
	@echo "✓ Notes 推送完成"

# ============================================================================
# Tag 管理
# ============================================================================

.PHONY: list-tags
list-tags: ## 列出所有tags
	@echo ">> 本地 Tags:"
	@git tag -l | sort -r | head -20
	@echo ""
	@echo ">> 远程 Tags (最近20个):"
	@git ls-remote --tags origin | awk '{print $$2}' | sed 's|refs/tags/||' | sort -r | head -20

.PHONY: clean-old-tags
clean-old-tags: ## 清理30天前的本地和远程tags
	@echo ">> 清理旧标签(保留最近30天)"
	@CUTOFF_DATE=$$(date -d '30 days ago' +'%y%m%d' 2>/dev/null || date -v-30d +'%y%m%d'); \
	for tag in $$(git tag -l "v*"); do \
		TAG_DATE=$$(echo $$tag | sed 's/v\([0-9]\{6\}\).*/\1/'); \
		if [ "$$TAG_DATE" -lt "$$CUTOFF_DATE" ] 2>/dev/null; then \
			echo "删除本地标签: $$tag ($$TAG_DATE)"; \
			git tag -d $$tag; \
			if git ls-remote --tags origin 2>/dev/null | grep -q "refs/tags/$$tag"; then \
				echo "删除远程标签: $$tag"; \
				git push origin :refs/tags/$$tag 2>/dev/null || true; \
			fi; \
		fi; \
	done; \
	echo "✓ 旧标签清理完成"

# ============================================================================
# 本地开发
# ============================================================================

.PHONY: pro
pro: check-hugo ## 以生产模式运行
	@echo ">> 以 production 模式运行"
	@echo "访问地址: http://localhost:1313"
	@hugo serve --bind 0.0.0.0 -e production --disableFastRender

.PHONY: dev
dev: check-hugo ## 以开发模式运行
	@echo ">> 以 development 模式运行"
	@echo "访问地址: http://localhost:1313"
	@hugo server -D

.PHONY: draft
draft: check-hugo ## 只显示草稿文章
	@echo ">> 草稿预览模式"
	@hugo server -D --buildDrafts --buildFuture

# ============================================================================
# 内容管理
# ============================================================================

.PHONY: create
create: check-hugo ## 创建新文章 make create file='linux/example.md'
	@if [ -z "$(CREATEF)" ]; then \
		echo "错误: 请指定文件名"; \
		echo "用法: make create file='linux/example.md'"; \
		exit 1; \
	fi
	@echo ">> 创建文档: posts/$(CREATEF)"
	@hugo new posts/$(CREATEF)
	@echo "✓ 文档创建成功"

.PHONY: new
new: create ## create 的别名

# ============================================================================
# 工具检查
# ============================================================================

.PHONY: check-hugo
check-hugo: ## 检查 Hugo 是否安装
	@which hugo > /dev/null || (echo "错误: 未找到 hugo 命令，请先安装 Hugo" && exit 1)

.PHONY: check-git
check-git: ## 检查 Git 仓库状态
	@echo ">> 检查 Git 仓库"
	@cd $(PUBLICGITDIR) && \
		if ! git rev-parse --git-dir >/dev/null 2>&1; then \
			echo "警告: $(PUBLICGITDIR) 不是有效的git仓库"; \
		fi
	@cd $(DEVOPSGITDIR) && \
		if ! git rev-parse --git-dir >/dev/null 2>&1; then \
			echo "警告: $(DEVOPSGITDIR) 不是有效的git仓库"; \
		fi
	@cd $(NOTESGITDIR) && \
		if ! git rev-parse --git-dir >/dev/null 2>&1; then \
			echo "错误: $(NOTESGITDIR) 不是有效的git仓库"; \
			exit 1; \
		fi
	@echo "✓ Git 仓库检查完成"

.PHONY: version
version: ## 显示版本信息
	@echo "Hugo 版本: $(HUGO_VERSION)"
	@echo "主题版本: $(THEMES_VERSION)"
	@echo "Git 版本: $$(git --version)"

# ============================================================================
# 快捷命令
# ============================================================================

.PHONY: quick
quick: ## 快速提交并推送(需要 msg 参数)
	@if [ -z "$(COMMITINFO)" ]; then \
		echo "错误: 请提供提交信息"; \
		echo "用法: make quick msg='你的提交信息'"; \
		exit 1; \
	fi
	@echo ">> 快速发布模式"
	@$(MAKE) commit msg="$(COMMITINFO)"
	@$(MAKE) push

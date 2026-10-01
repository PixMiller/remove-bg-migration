# 上线检查清单

[English](../production-checklist.md) · 简体中文

remove.bg 的自助 API 将于 **2026 年 12 月 1 日**停止受理请求。下面是在此之前把线上流量从 remove.bg
安全切换到 PixMiller 的做法。

## 1. 找出所有调用点

```bash
# From the root of your codebase
bash <(curl -fsSL https://raw.githubusercontent.com/PixMiller/remove-bg-migration/main/scripts/find-removebg-usages.sh)
# or, after cloning this repo:
./scripts/find-removebg-usages.sh /path/to/your/project
```

这个脚本会列出写死的 `api.remove.bg` URL、remove.bg SDK 的引用、`X-Api-Key` 请求头，以及
`REMOVE_BG` 这类环境变量。配置文件、基础设施代码和无代码自动化（Zapier、Make、n8n）也要检查，
脚本看不到这些地方。

## 2. 把端点做成可配置

不要把一个写死的 URL 换成另一个写死的 URL。从配置中读取 base URL 和 Key，这样切换和回切都不需要重新部署：

```bash
REMOVE_BG_API_BASE=https://api.pixmiller.com     # was https://api.remove.bg
REMOVE_BG_API_KEY=<your PixMiller key>
```

## 3. 每次调用都设置 `size`

在 PixMiller 上，`size` 的默认值（`preview`，以及它的别名 `small` / `regular`）返回的是**带水印**、
最长边不超过 640 px 的图片。传 `size=auto` 可以在有点数时拿到原图，或者传固定的付费档位
（`full`、`hd`、`4k`、`medium`、`50MP`）。用 `auto` 时要检查 `X-Credits-Charged`：值为 `0`
说明余额用完了，你拿到的是预览图。

## 4. 处理差异

- [ ] **限速：每个 Key 每分钟 40 张**（remove.bg 是 500）。给批量任务加节流，收到 `429` 时按
      `Retry-After` 重试。参见
      [`examples/python/batch_remove_bg.py`](../../examples/python/batch_remove_bg.py)。
- [ ] **输入文件上限：20 MB**（remove.bg：22 MB）。更大的文件要先拒绝或缩小。
- [ ] **没有每月免费调用。** `free_calls` 始终为 `0`。预览免费，且不设额度。
- [ ] **不渲染阴影和半透明。** 如果你依赖 `add_shadow` 处理汽车照片，需要自己加阴影。
- [ ] **`X-Type` 只给粗分类**（`person`、`product`、`animal`、`car`、`other`）。
- [ ] **`402 insufficient_credits`：** 为它设置告警。同时根据 `GET /v1.0/account` 设置余额不足告警，
      避免付费任务卡住。

## 5. 不花点数完成测试

- `GET /v1.0/account` 免费，可以确认 Key 可用。
- `size=preview` 免费，可以确认整条请求链路，包括 multipart 或 JSON 编码，以及你的错误处理。
- 然后只做**一次**付费调用（`size=auto`），检查 `X-Credits-Charged: 1`、输出尺寸和透明效果。

[`scripts/verify-key.sh`](../../scripts/verify-key.sh) 执行免费检查。
[`scripts/smoke-test.sh`](../../scripts/smoke-test.sh) 在传入 `--paid` 时会加上那一次付费调用。

## 6. 灰度切换

1. 先把一小部分流量或一个队列切到 PixMiller，并排对比结果。
2. 按 `errors[0].code` 观察错误率，同时关注延迟、`X-Credits-Charged` 和余额。
3. 再切剩下的流量。remove.bg 的配置保留到 11 月 30 日，以备回滚。12 月 1 日之后就没有可回滚的对象了。

## 7. 收尾清理

- 从密钥存储中删除旧的 remove.bg Key。
- 代码改成直接调用 HTTP 端点后，删除 SDK 补丁或 monkeypatch。
- 在 12 月 1 日前用完剩余的 remove.bg 按量点数。remove.bg 表示，未用完的按量点数在关站时作废。

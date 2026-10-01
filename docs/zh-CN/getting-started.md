# 快速上手：注册账号、获取 API Key、购买点数

[English](../getting-started.md) · 简体中文

一共三步，大约五分钟。前两步免费。

## 1. 注册 PixMiller 账号

在 **[pixmiller.com/accounts/signup](https://pixmiller.com/accounts/signup/?utm_source=github&utm_medium=referral&utm_campaign=removebg-migration&utm_content=getting_started_zh)**
注册。支持邮箱、Google，中文站还支持微信扫码。用邮箱注册的话，需要点开我们发给你的邮件，确认邮箱地址。

网站和 API 共用同一个账号、同一份点数余额。

## 2. 复制 API Key

登录后打开 **[pixmiller.com/zh-hans/users/~api/](https://pixmiller.com/zh-hans/users/~api/?utm_source=github&utm_medium=referral&utm_campaign=removebg-migration&utm_content=getting_started_zh)**。
第一次打开这个页面时会自动生成 Key。同一页面上有 **Reset API Key** 按钮，重置后旧 Key 立即失效。

不要把 Key 提交到代码仓库。把它放进环境变量或密钥管理服务：

```bash
export PIXMILLER_API_KEY="paste-your-key-here"
```

然后确认 Key 可用。这个调用不收费：

```bash
curl -s "https://api.pixmiller.com/v1.0/account" -H "X-Api-Key: $PIXMILLER_API_KEY"
# {"data":{"attributes":{"credits":{"total":0,...},"api":{"free_calls":0,"sizes":"all"}}}}
```

如果返回 `403` 和 `invalid_api_key`，说明 Key 没有复制完整，或者已经被重置。

也可以运行 [`scripts/verify-key.sh`](../../scripts/verify-key.sh)。它会校验 Key，并调用一次免费的预览档，
不会花掉任何点数。

## 3. 购买点数（只有无水印原图需要）

| 档位 | 费用 | 输出 |
|---|---|---|
| `size=preview`（默认） | 免费 | 带水印，最长边不超过 640 px |
| `size=auto`、`full`、`hd`、`4k`、`medium`、`50MP` | 每张 1 点 | 原图，无水印 |

新账号的点数为 0。免费预览注册后就能用，所以可以先把集成接好、测通，再付费。

在 **[定价页](https://pixmiller.com/zh-hans/pricing/?utm_source=github&utm_medium=referral&utm_campaign=removebg-migration&utm_content=getting_started_zh)** 购买点数：

- **按量购买**：一次性点数包。这些点数**永不过期**，不会自动续费，也不需要订阅。
- **按月订阅**：每月发放点数，有效期一个月。
- 支付方式：支付宝、微信支付，以及银行卡、PayPal（由 Paddle 处理）。价格在适用时已含增值税（VAT）。

购买的点数会计入 `/v1.0/account` 返回的同一份余额。

> [!TIP]
> 需要发票、更大的用量，或者每分钟 40 张以上的限速？
> [联系我们](https://pixmiller.com/zh-hans/contact/?utm_source=github&utm_medium=referral&utm_campaign=removebg-migration&utm_content=getting_started_zh)。

## 下一步

- 修改代码：看 [migration-guide.md](migration-guide.md) 和[示例代码](../../examples/README.md)。
- 你用的是 SDK 而不是自己发 HTTP 请求：看 [client-libraries.md](client-libraries.md)。
- 切换生产流量之前：看 [production-checklist.md](production-checklist.md)。

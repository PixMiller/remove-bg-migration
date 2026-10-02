# 常见问题

[English](../faq.md) · 简体中文

### remove.bg 真的要关了吗？

是的。remove.bg 的全站横幅写明，其抠图功能将迁到 Canva，独立网站自 **2026 年 12 月 1 日 09:00（欧洲中部时间）**
起不再提供。它的 API 页面写明，从同一天起，抠图服务迁到 Leonardo.Ai（同样隶属 Canva）。
见 [remove.bg](https://www.remove.bg/) 和 [remove.bg/api](https://www.remove.bg/api)。

### 我在 remove.bg 没用完的点数怎么办？

remove.bg 表示，未用完的按量点数在关站时作废。退款只按其通用的 14 天政策处理，年度订阅按比例退款。
具体情况请查看 remove.bg 的 FAQ 和条款。

### remove.bg API 还能继续用吗？

自助 API 将于 2026 年 12 月 1 日停止受理请求。remove.bg 把这些用户指向 Leonardo.Ai，而后者自己的迁移指南写明需要改代码
（换新端点、改用 Bearer 认证、请求体只接受 JSON）。remove.bg 表示企业版 API 合同不受影响。

### 迁到 PixMiller 需要重写集成吗？

如果你用自己写的 HTTP 代码调用 API，通常只需要改 base URL 和 API Key。PixMiller 接受 `POST /v1.0/removebg`，
请求头同样是 `X-Api-Key`，`image_file` / `image_url` / `size` / `format` / `bg_color` 等字段名也相同，并返回
`200` 和图片字节。三个第三方客户端通过了我们的测试，但我们不承诺每次发版后都保持 SDK 级兼容。默认的 size
返回带水印的预览图，阴影参数不生效，限速也更低。[查看所有差异](migration-guide.md#差异汇总)。

### 能从浏览器、Figma 插件或浏览器扩展里直接调用吗？

可以。`api.pixmiller.com` 允许任意来源的跨域调用（不使用 cookie），并把 `X-Credits-Charged`、`X-Width`、
`X-Height`、`X-Type`、`X-Foreground-*`、`X-RateLimit-*` 和 `Retry-After` 响应头暴露给你的脚本，错误响应也能读到。
不要把你自己的 Key 发布在公开的前端代码里，任何人都能复制它并花掉你的点数。请经你自己的后端调用，或让每个用户填自己的
Key（Figma 插件、浏览器扩展就是这样做的）。`fetch` 示例见
[从浏览器调用](migration-guide.md#从浏览器调用)。

### 为什么我拿到的图带水印？

你没有设置 `size`，或者设成了 `preview`、`small` 或 `regular`。这几个档位在 PixMiller 上免费且带水印。
请传 `size=auto` 或付费档位，并确认账户里有点数。

### 怎么收费？

`preview` 免费。所有付费档位每张 1 点，调用失败不收费。当前价格见
[定价页](https://pixmiller.com/zh-hans/pricing/?utm_source=github&utm_medium=referral&utm_campaign=removebg-migration&utm_content=faq_zh)。

### PixMiller 的点数会过期吗？

按量购买的点数永不过期。没有每月清零，也不需要订阅：可以只买一个点数包就停。订阅点数每月发放，有效期一个月。

### 有免费的 API 额度吗？

没有每月免费的高清调用。带水印的 `preview` 档免费且不设额度，所以可以在购买点数之前把集成搭好、测通。

### 限速是多少？能提高吗？

每个 Key 每分钟 40 张。每次调用计为一张。如果需要更高限额，
[联系我们](https://pixmiller.com/zh-hans/contact/?utm_source=github&utm_medium=referral&utm_campaign=removebg-migration&utm_content=faq_zh)。

### 支持哪些图片格式和尺寸？

输入：JPG、PNG 或 WebP，最大 20 MB。输出：PNG、JPG、WebP 或 ZIP（`color.jpg` + `alpha.png`）。
PNG 输出上限为 1000 万像素；其他格式按档位的上限（最高 50 MP）。

### 我的图片存在哪里？

处理后的图片会临时存储，底层文件 3 天后自动删除。兼容端点直接返回图片字节，所以你不需要从我们的存储下载任何东西。

### 我不写代码，只用过 remove.bg 网页版。

单张图片用 [pixmiller.com/zh-hans/remove-bg-alternative](https://pixmiller.com/zh-hans/remove-bg-alternative/?utm_source=github&utm_medium=referral&utm_campaign=removebg-migration&utm_content=faq_zh)；
一次最多 50 张用[批量抠图](https://pixmiller.com/zh-hans/remove-background/batch/?utm_source=github&utm_medium=referral&utm_campaign=removebg-migration&utm_content=faq_zh)
（支持直接拖入多张图片或上传 ZIP，保留原文件名）。

### PixMiller 与 remove.bg、Canva 或 Leonardo.Ai 有关系吗？

没有。文中提及的产品名称仅用于指代。有关这些服务的信息均引自其 2026 年 9 月的公开页面。

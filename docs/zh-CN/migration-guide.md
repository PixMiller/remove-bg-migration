# remove.bg API → PixMiller：完整迁移参考

[English](../migration-guide.md) · 简体中文

本文是 PixMiller 的 remove.bg 兼容端点的完整契约。改代码之前，请先看[四个注意事项](#先读这几条)。
下面的内容与官网指南
[pixmiller.com/zh-hans/api-docs/remove-bg-migration](https://pixmiller.com/zh-hans/api-docs/remove-bg-migration/?utm_source=github&utm_medium=referral&utm_campaign=removebg-migration&utm_content=guide_zh)
保持一致；如果两者有出入，以官网为准。也请
[提一个 issue](https://github.com/PixMiller/remove-bg-migration/issues)，方便我们修正这份文档。

- [先读这几条](#先读这几条)
- [端点](#端点)
- [迁移前后对比](#迁移前后对比)
- [请求参数](#请求参数)
- [`size` 参数](#size-参数)
- [响应](#响应)
- [响应头](#响应头)
- [错误](#错误)
- [账户端点](#账户端点)
- [限速](#限速)
- [从浏览器调用](#从浏览器调用)
- [点数与计费](#点数与计费)
- [差异汇总](#差异汇总)

## 先读这几条

1. **`size` 的默认值和 remove.bg 一样是 `preview`，但我们的预览图不一样。** 这里的预览是免费、
   **带水印**、最长边不超过 640 px 的图片；remove.bg 的预览是 0.25 百万像素、不带水印。
   如果集成代码从不设置 `size`，拿到的都是带水印的预览图。要无水印结果，请传 `size=auto` 或付费档位。
2. **我们不承诺 SDK 级兼容。** 三个第三方客户端在 2026 年 9 月 22 日通过了我们的测试：PyPI 的
   `removebg` 包、官方 npm `remove.bg` 包，以及 `removebg-cli`。之后我们不会在每次发版时逐一回归测试它们。
   我们支持的方式是自己写 HTTP 客户端。详见 [client-libraries.md](client-libraries.md)。
3. **`shadow_type`、`shadow_opacity`、`add_shadow` 和 `semitransparency` 不生效。**
   我们会接收并校验这些参数，但它们不会改变输出。对于非汽车类主体，remove.bg 的行为也是这样。
   我们没有针对汽车的专用模型。
4. **每个 Key 每分钟最多 40 张**（remove.bg 是 500）。每次调用计为一张。收到 `429` 时按 `Retry-After` 处理，或者
   [联系我们](https://pixmiller.com/zh-hans/contact/?utm_source=github&utm_medium=referral&utm_campaign=removebg-migration&utm_content=rate_limit_zh)
   提高限额。

## 端点

| | remove.bg | PixMiller |
|---|---|---|
| 去背景 | `POST https://api.remove.bg/v1.0/removebg` | `POST https://api.pixmiller.com/v1.0/removebg` |
| 账户 / 余额 | `GET https://api.remove.bg/v1.0/account` | `GET https://api.pixmiller.com/v1.0/account` |
| 认证 | `X-Api-Key: <key>` | `X-Api-Key: <key>`，请求头相同 |
| 请求体 | multipart、form-urlencoded 或 JSON | multipart、form-urlencoded 或 JSON |

## 迁移前后对比

```bash
# remove.bg
curl -X POST "https://api.remove.bg/v1.0/removebg" \
  -H "X-Api-Key: REMOVEBG_KEY" \
  -F "image_file=@product.jpg" \
  -F "size=auto" \
  -o out.png
```

```bash
# PixMiller
curl -X POST "https://api.pixmiller.com/v1.0/removebg" \
  -H "X-Api-Key: PIXMILLER_KEY" \
  -F "image_file=@product.jpg" \
  -F "size=auto" \
  -o out.png
# 200 OK → image bytes, written straight to out.png
# X-Credits-Charged: 1   X-Width: 1200   X-Height: 1600   X-Type: product
```

路径、请求头名称和表单字段都不变。大多数自己写的客户端只需要改 base URL 和 Key。

## 请求参数

每个参数都按 remove.bg 自己的取值范围校验。取值不合法时返回 `400 invalid_parameter`，不会被悄悄忽略。
remove.bg 也是这样处理的。

| 参数 | 状态 | 说明 |
|---|---|---|
| `image_file` | ✅ 相同 | multipart 上传。JPG / PNG / WebP，最大 20 MB（remove.bg：22 MB）。 |
| `image_url` | ✅ 相同 | 公开的图片 URL。由我们这边抓取，同样限制 20 MB。 |
| `image_file_b64` | ✅ 相同 | 放在请求体里的 Base64 编码图片，与 remove.bg 相同。 |
| `size` | ⚠️ 不同 | 取值、默认值（`preview`）和百万像素上限都相同。但 `preview` 是免费、带水印、最长边不超过 640 px 的图片，不是 0.25 百万像素的无水印图。`medium` / `hd` / `4k` / `full` / `50MP` 每张 1 点。`auto` 在还有点数时使用付费档位。[详情](#size-参数)。 |
| `format` | ✅ 相同 | `auto` / `png` / `jpg` / `webp` / `zip`。`zip` 包含 `color.jpg` 和 `alpha.png`，与 remove.bg 相同。`Accept: application/json` 返回 base64 信封。PNG 输出上限为 1000 万像素。 |
| `type`、`type_level` | ⚠️ 不同 | 接受。`type` 会映射到我们自己的模型。`X-Type` 只给粗分类：`person`、`product`、`animal`、`car` 或 `other`。`type_level=2` 和 `latest` 返回的也是这几个粗分类。 |
| `crop`、`crop_margin` | ✅ 相同 | 裁剪到主体。边距语法相同，上限同样是 50% / 500 px。 |
| `roi` | ✅ 相同 | 感兴趣区域，用像素或百分比表示，与 remove.bg 相同。 |
| `scale`、`position` | ✅ 相同 | 主体缩放比例（10%–100% 或 `original`）和位置，与 remove.bg 相同。 |
| `channels` | ✅ 相同 | `rgba`（默认），或 `alpha` 只输出蒙版。 |
| `bg_color` | ✅ 相同 | 默认透明。3 / 4 / 6 / 8 位十六进制色值（带不带 `#` 都行），或颜色名。 |
| `bg_image_file`、`bg_image_url` | ✅ 相同 | 缩放到铺满输出并居中。不能和 `bg_color` 同时使用。 |
| `add_shadow`、`shadow_type`、`shadow_opacity` | ⛔ 不生效 | 按 remove.bg 的取值校验，但从不渲染阴影。 |
| `semitransparency` | ⛔ 不生效 | 接受。半透明区域始终自动处理。 |

## `size` 参数

| 你传的值 | 我们使用 | 你得到的结果 |
|---|---|---|
| `preview` / `small` / `regular` | preview | 带水印的预览图，最长边不超过 640 px。免费，不扣点数。这是默认值，与 remove.bg 相同。 |
| `medium` / `hd` / `4k` / `full` / `50MP` | full | 无水印原图，按档位的百万像素上限缩小（1.5 / 4 / 25 / 25 / 50 MP；PNG 输出上限 10 MP）。每张 1 点。 |
| `auto` | auto | 有点数时出原图，没有点数时出免费的带水印预览图。 |

> [!IMPORTANT]
> 在这里 `regular` 是 `preview` 的别名，而它正是 PyPI `removebg` 包的默认值。
> 如果沿用 SDK 的默认值，拿到的就是带水印的预览图。请显式设置 `size`。

## 响应

- **状态码 `200 OK`**，响应体是图片字节，与 remove.bg 相同。检查 `200` 的代码可以继续用。
- `Content-Type` 跟随输出格式（`image/png`、`image/jpeg`、`image/webp` 或 `application/zip`）。
- 发送 `Accept: application/json`（或 `format=json`）可以拿到 remove.bg 的 base64 信封：

  ```json
  {
    "data": {
      "result_b64": "iVBORw0KGgo…",
      "foreground_top": 0,
      "foreground_left": 0,
      "foreground_width": 1200,
      "foreground_height": 1600
    }
  }
  ```

> [!NOTE]
> PixMiller 还有自己的原生端点 `POST /v1/remove`，它返回 `201` 和 JSON（`{"url": "…"}`）。
> 兼容路径 `/v1.0/removebg` 特意**不**这样做。从 remove.bg 迁移时，请用 `/v1.0/removebg`。

## 响应头

| 响应头 | 含义 |
|---|---|
| `X-Credits-Charged` | 本次调用实际扣除的点数（免费预览档为 `0`）。 |
| `X-Width` / `X-Height` | 返回图片的像素尺寸。 |
| `X-Type` | 识别出的前景类别：`person`、`product`、`animal`、`car` 或 `other`（`type_level=none` 时不返回）。 |
| `X-Foreground-Top` / `-Left` / `-Width` / `-Height` | 主体在返回图片中的边界框。 |
| `X-RateLimit-Limit` / `-Remaining` / `-Reset` | 你这个 Key 的限速状态，按张计算，一次调用占一个单位。返回 `429` 时会附带 `Retry-After`。 |

## 错误

错误采用 remove.bg 的 JSON:API 结构。它是一个数组，所以 `errors[0].title` 的读法和以前一样：

```json
{"errors": [{"code": "auth_failed", "title": "Missing API Key"}]}
```

| 状态码 | `errors[0].code` | 触发条件 |
|---|---|---|
| 400 | `invalid_parameter` | size / format / crop / scale / … 的取值超出 remove.bg 的范围，或者缺少图片来源。title 中会写明是哪个参数。 |
| 400 | `file_too_large` | 输入图片超过 20 MB。 |
| 400 | `unknown_foreground` | 图片中找不到前景。 |
| 402 | `insufficient_credits` | 请求了付费档位，但余额为零。不会扣费。 |
| 403 | `auth_failed` / `invalid_api_key` | 缺少 `X-Api-Key` 请求头（`auth_failed`）或 Key 不正确（`invalid_api_key`）。返回 `403`，与 remove.bg 相同，不是 `401`。 |
| 429 | `rate_limit_exceeded` | 超出限速。按 `Retry-After` 响应头等待后重试。 |
| 502 | `result_fetch_failed` | 无法从存储中取回结果。没有扣费，请重试。 |

状态码表达错误类别，`code` 沿用 remove.bg 自己的错误码，所以按 `errors[0].code` 写的 `switch` 可以继续用。

## 账户端点

```bash
curl "https://api.pixmiller.com/v1.0/account" -H "X-Api-Key: PIXMILLER_KEY"
```

```json
{
  "data": {
    "attributes": {
      "credits": {"total": 200, "subscription": 0, "payg": 200, "enterprise": 0},
      "api": {"free_calls": 0, "sizes": "all"}
    }
  }
}
```

余额在 `data.attributes.credits` 下，所以按 remove.bg 写的余额检查代码，结构不用改。没有每月免费额度，
所以 `free_calls` 始终为 `0`。调用 `/v1.0/account` 不收费，这是验证新 Key 是否可用最稳妥的方法。

## 限速

- **每个 Key 每分钟 40 张。** remove.bg 是 500。
- 每次调用 `/v1.0/removebg` 计为一张。`X-RateLimit-Limit`、`-Remaining` 和 `-Reset` 报告的就是这个按张计算的额度。
- 收到 `429 rate_limit_exceeded` 时，等待 `Retry-After` 给出的秒数后重试。
  [`examples/python/batch_remove_bg.py`](../../examples/python/batch_remove_bg.py) 演示了一个不超限速的批量处理脚本。
- 需要更高限额？[联系我们](https://pixmiller.com/zh-hans/contact/?utm_source=github&utm_medium=referral&utm_campaign=removebg-migration&utm_content=rate_limit_zh)。

## 从浏览器调用

`https://api.pixmiller.com/v1.0/*`（以及 `/v1/*`）可以直接在网页、浏览器扩展或插件沙盒（Figma、Obsidian
等）里调用：

- **允许任意 `Origin`，不使用 cookie。** 鉴权只靠 `X-Api-Key` 请求头，所以不要带
  `credentials: "include"`。
- 预检（`OPTIONS`）放行 `GET` 和 `POST`，并允许请求头 `x-api-key`、`content-type`、`accept`。
  multipart 上传、JSON 请求体、`Accept: application/json` 信封和 `GET /v1.0/account` 都在范围内。
- 前端可以通过 `resp.headers.get(...)` 读到这些响应头：`X-Credits-Charged`、`X-Width`、`X-Height`、
  `X-Type`、`X-Foreground-Top` / `-Left` / `-Width` / `-Height`、`X-RateLimit-Limit` / `-Remaining` /
  `-Reset` 和 `Retry-After`。
- 错误响应（`400`、`402`、`403`、`429` 等）同样带 CORS 头，所以页面能读到 `errors[0].code`。

```js
// 浏览器端：`apiKey` 由用户提供（见下面的警告）；`file` 是 <input type="file"> 选出的 File。
async function removeBackground(apiKey, file) {
  const form = new FormData();
  form.append("image_file", file);
  form.append("size", "auto");

  const resp = await fetch("https://api.pixmiller.com/v1.0/removebg", {
    method: "POST",
    headers: { "X-Api-Key": apiKey }, // 不要手动设置 Content-Type：浏览器会自动补上 multipart boundary
    body: form,
  });

  if (!resp.ok) {
    const { errors } = await resp.json(); // 与 remove.bg 相同的错误信封
    const retryAfter = resp.headers.get("Retry-After"); // 429 时才有
    throw Object.assign(new Error(errors[0].title), { code: errors[0].code, retryAfter });
  }

  console.log("charged:", resp.headers.get("X-Credits-Charged")); // "0" 表示拿到的是预览图
  return URL.createObjectURL(await resp.blob()); // 可直接作为 <img src>
}
```

> [!WARNING]
> **不要把 API Key 写进公开的前端代码。** 发到浏览器里的任何东西（网页、公开仓库里的前端 bundle）
> 每个访问者都能读到，谁复制了这个 Key，谁就能花掉你的点数。请改用下面两种做法之一：
>
> - **走你自己的后端。** 浏览器调用你的服务器，由服务器用环境变量或密钥存储里的 Key 去调用
>   PixMiller。任何公开的网站或应用都应该这样做。
> - **让用户自带 Key（BYO-key）。** 用户把自己的 PixMiller Key 填进你的 Figma 插件、浏览器扩展或桌面插件，
>   你把它保存在该工具的本地存储里。每个用户花的是自己的点数，你这边没有任何东西暴露。

## 点数与计费

- `preview` 免费。所有付费档位都是**每张 1 点**。
- 只有在取回结果之后才扣点数。调用失败绝不扣点。
- **按量购买的点数永不过期。** 没有每月清零，也不需要订阅。也可以选择订阅点数。
- 在[定价页](https://pixmiller.com/zh-hans/pricing/?utm_source=github&utm_medium=referral&utm_campaign=removebg-migration&utm_content=guide_zh)购买点数。
  API 和网站共用同一份余额。
- 视地区支持银行卡、PayPal、支付宝和微信支付。

## 差异汇总

| 项目 | 与 remove.bg 相同 | 不同之处 |
|---|---|---|
| 路径、认证请求头、表单字段名 | ✅ | |
| 状态码（`200` + 图片字节） | ✅ | |
| 通过 `Accept: application/json` 返回 JSON 信封 | ✅ | |
| 错误信封和错误码 | ✅ | |
| `X-*` 响应头 | ✅ | `X-Type` 只给粗分类 |
| `size` 默认值 | ✅ `preview` | 我们的预览图带水印、最长边不超过 640 px、免费 |
| 付费档位 | ✅ 每张 1 点 | 没有 0.25 点的预览档 |
| 每月免费 API 调用 | | 没有（`free_calls` 始终为 0） |
| 阴影、半透明 | | 接受参数，但从不渲染 |
| 输入文件上限 | | 20 MB（remove.bg：22 MB） |
| 限速 | | 每个 Key 每分钟 40 张（remove.bg：500） |
| 官方 SDK / CLI | | 2026-09-22 测试过一次，不保证每次发版后仍可用 |

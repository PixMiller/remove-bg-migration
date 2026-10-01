# 用 remove.bg 客户端库调用 PixMiller

[English](../client-libraries.md) · 简体中文

**简短回答：** 如果库允许设置 base URL，就把它指向 `https://api.pixmiller.com`，并显式设置 `size`。
如果不允许，就换成 [`examples/`](../../examples/README.md) 里的直接 HTTP 调用。这段调用在任何语言里都只有
20 行左右，也是我们支持的方式。

我们在 **2026 年 9 月 22 日**用兼容端点测试了最常用的三个第三方客户端，三个的主路径都跑通了。
我们**不会**在每次发版时重新测试它们，它们自身也可能变化。请把本页当作起点，而不是保证。

| 库 | 测试版本 | 能否更换端点？ | 默认 `size` | 结果 |
|---|---|---|---|---|
| PyPI [`removebg`](https://pypi.org/project/removebg/) | 0.4（`0.04`） | 能，运行时改模块常量 | `regular`（= 带水印的预览图） | ✅ 文件 / URL / base64、`bg_color`、Key 错误时返回 `403` |
| npm [`remove.bg`](https://www.npmjs.com/package/remove.bg) | 1.3.0 | 不能，写死在 `const` 里；需要改文件 | `preview`（带水印） | ✅ 文件 / URL / base64、响应头解析正常、错误能正确 reject |
| PyPI [`removebg-cli`](https://pypi.org/project/removebg-cli/) | 1.0.0 | 不能，三处 URL 写死 | `auto` | ✅ 账户面板、预览、原图、zip、webp、URL 来源、`-b 81d4fa` |

> [!WARNING]
> 两个 SDK 在 PixMiller 上默认都走免费的**带水印**预览档。凡是需要无水印图片的调用，
> 都要传 `size="auto"`（或 `full`、`hd`、`4k`）。

## Python：`removebg`（PyPI）

这个库每次调用都会读取模块级常量 `removebg.removebg.API_ENDPOINT`，所以在启动时覆盖一次即可：

```python
import os
import removebg.removebg as _removebg_module
from removebg import RemoveBg

_removebg_module.API_ENDPOINT = "https://api.pixmiller.com/v1.0/removebg"

rmbg = RemoveBg(os.environ["PIXMILLER_API_KEY"], "removebg-errors.log")
rmbg.remove_background_from_img_file("product.jpg", size="auto")  # writes product.jpg_no_bg.png
```

注意：

- `size="regular"` 是这个库的默认值。在 PixMiller 上它对应带水印的预览图。
- 这个库在读取错误响应体之前会先调用 `raise_for_status()`，所以 `402` 或 `403` 会以
  `requests.HTTPError` 的形式抛出。对接 remove.bg 时也是这样。

可运行的版本见 [`examples/python/patch_removebg_sdk.py`](../../examples/python/patch_removebg_sdk.py)。

## Node.js：`remove.bg`（npm）

1.3.0 版把端点作为 `const` 写死在 `dist/index.js` 里，也不读取任何环境变量。你有两个选择。

**方案 A（推荐）：换掉这个库。** 它只是一层很薄的封装。
[`examples/node/remove-background.mjs`](../../examples/node/remove-background.mjs) 用 Node 18+ 内置的
`fetch` 实现了同样的功能，没有任何依赖。

**方案 B：给已安装的包打补丁**，用
[patch-package](https://www.npmjs.com/package/patch-package) 让改动在 `npm install` 之后依然保留：

```bash
sed -i.bak 's#https://api.remove.bg/v1.0/removebg#https://api.pixmiller.com/v1.0/removebg#' \
  node_modules/remove.bg/dist/index.js
npx patch-package remove.bg
```

然后把 PixMiller 的 Key 作为 `apiKey` 传入，并设置 `size: "auto"`：

```js
const { removeBackgroundFromImageFile } = require("remove.bg");

const result = await removeBackgroundFromImageFile({
  path: "product.jpg",
  apiKey: process.env.PIXMILLER_API_KEY,
  size: "auto",
  outputFile: "out.png",
});
console.log(result.creditsCharged, result.resultWidth, result.resultHeight);
```

这个库总是发送 `Accept: application/json` 并解码 `data.result_b64`，PixMiller 返回的是同样的信封。
`creditsCharged`、`detectedType`、`rateLimit*` 和 `retryAfter` 都从我们的响应头中读取。

## 命令行工具：`removebg-cli`（PyPI）

这个 CLI 从 `REMOVE_BG_API_KEY` 读取 Key，但 `removebg_cli.py` 里有三处写死了 `https://api.remove.bg/...`。
要改指向，需要编辑已安装的文件：

```bash
FILE="$(python3 -c 'import removebg_cli; print(removebg_cli.__file__)')"
sed -i.bak 's#https://api.remove.bg/v1.0/#https://api.pixmiller.com/v1.0/#g' "$FILE"
export REMOVE_BG_API_KEY="$PIXMILLER_API_KEY"
removebg product.jpg -s auto
```

重新安装这个包会让改动失效。在脚本和 CI 里，用 [curl 示例](../../examples/curl/remove-background.sh)更好维护。

## 其他库和无代码工具

其他封装我们没有测试过，比如 Ruby gem、PHP 或 Laravel 包、WordPress 插件、Go 模块等。对每一个：

1. 找找有没有 base URL、endpoint 或 host 选项。有的话，设成 `https://api.pixmiller.com`
   （路径 `/v1.0/removebg` 不变）。
2. 没有的话，换成 [`examples/`](../../examples/README.md) 里的 HTTP 调用。
3. 始终显式设置 `size`，并在第一次付费调用之前运行 [`scripts/verify-key.sh`](../../scripts/verify-key.sh)。

**Zapier、Make、n8n、Pipedream：** 它们内置的 remove.bg 应用直接调用 remove.bg，无法改指向。
请改用平台的通用 HTTP 步骤（Zapier 的 "Webhooks"、Make 的 "HTTP"、n8n 的 "HTTP Request"）：

| 字段 | 值 |
|---|---|
| Method | `POST` |
| URL | `https://api.pixmiller.com/v1.0/removebg` |
| Header | `X-Api-Key: <你的 PixMiller Key>` |
| Body | multipart 表单：`image_url`（或 `image_file`）、`size=auto` |
| Response | 二进制图片（如果发送了 `Accept: application/json`，则是带 `result_b64` 的 JSON） |

你让别的库也跑通了？欢迎提交 PR，把它加到本页。

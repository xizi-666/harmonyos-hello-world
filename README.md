# 参考文献格式检查器（鸿蒙 PC 校园应用）

对应《鸿蒙 PC 校园应用选题》**编号 054：参考文献格式检查器** —— 本地维护引用条目、检查缺字段与重复项、批量调整引用格式。

## 一、功能清单

| 功能 | 说明 |
| --- | --- |
| 引用条目维护 | 新增 / 编辑 / 删除 / 搜索条目，支持期刊论文[J]、学位论文[D]、会议论文[C]、图书专著[M]、网络资源[EB/OL] 五种文献类型，字段按类型动态切换 |
| 本地持久化 | 条目保存在应用本地（Preferences），退出重进不丢失；首次启动自动写入 8 条示例数据（含 1 条缺字段、1 组重复条目，便于演示） |
| 缺字段检查 | 按文献类型校验必填字段，左侧列表实时显示红色「缺字段」角标，右栏「检查结果」逐条列出缺了什么字段 |
| 重复项检查 | 按「归一化标题」和「归一化 DOI」双规则识别重复条目，显示橙色「疑似重复」角标并给出提示 |
| 引用格式预览 | 三种样式实时预览：GB/T 7714-2015、APA 第 7 版、MLA 第 9 版；作者姓名按中西文分别处理（GB/T 超 3 人自动「等」，西文姓名自动转 APA/MLA 缩写格式） |
| 批量格式化 | 勾选任意条目（或全选），按所选样式一次性生成带序号的参考文献列表，一键复制到剪贴板 |

界面为 PC 三栏布局：左栏条目列表与管理、中栏条目编辑表单、右栏格式预览 / 批量格式化 / 检查结果。

## 二、环境要求

- DevEco Studio 26.0.0.851（本机已安装在 `E:\DevEco Studio`）
- HarmonyOS 26.0.0 SDK（API 26，DevEco 自带，无需额外下载）
- 工程配置：`compatibleSdkVersion 5.0.0(12)`，可运行于 API 12 及以上的手机 / 平板 / PC（2in1）设备

> **重要：工程路径必须只用英文、数字、下划线等 ASCII 字符。**
> hvigor 会校验工程路径，中文路径（例如 `C:\Users\希杍\...`）会直接报错
> `00306003 Specification Limit Violation: Invalid project path`，无法构建。
> 因此本工程放在：`D:\HarmonyProjects\RefChecker`

## 三、运行步骤

> **已装机提示**：本应用已经通过离线签名 + hdc 安装到了 PC（2in1）模拟器里（包名 `com.campus.refchecker`），
> 桌面上已有「参考文献格式检查器」图标，直接点击即可运行，无需再做下面 1~5 步。
> 只有改了代码想重新部署时，才需要按下面流程走。

1. 打开 DevEco Studio → `File` → `Open`，选择目录 `D:\HarmonyProjects\RefChecker`（**不要**复制到含中文的目录下再打开）。
2. 等待右下角 Sync 完成（首次会自动同步 hvigor 与依赖）。
3. 配置签名：`File` → `Project Structure` → `Signing Configs` → 勾选 `Automatically generate signature`（需登录华为账号）。命令行方式不签名也能编译，但装到模拟器/真机必须签名。
4. 启动设备：`Device Manager` → `Local Emulator` → 选择 PC（2in1）模拟器镜像启动；或连接已开启开发者模式的鸿蒙 PC / 手机。
5. 点击工具栏 Run（`Shift + F10`）运行。

命令行编译（可选，验证代码能否通过编译）：

```bash
cd /d D:\HarmonyProjects\RefChecker
set DEVECO_SDK_HOME=E:\DevEco Studio\sdk
set PATH=E:\DevEco Studio\jbr\bin;%PATH%
"E:\DevEco Studio\tools\node\node.exe" "E:\DevEco Studio\tools\hvigor\bin\hvigorw.js" assembleHap --mode module -p product=default -p buildMode=debug --no-daemon
```

已实测：`BUILD SUCCESSFUL`，产物为 `entry/build/default/outputs/default/entry-default-unsigned.hap`（未签名）。

### 3.1 已验证可用的「离线签名 + hdc 直装」流程（无需华为账号登录）

本机模拟器（HarmonyOS 7.0.0 / API 26，`emulator 7.0.0.107`）信任 OpenHarmony 默认根证书，因此可以完全离线签名并安装：

```bash
# 0) 准备（一次性）：materials 已在本工程 signature/ 目录里
#    refchecker.p12(应用密钥, 口令123456)  app_debug.cer(应用证书链)
#    root_ca.cer / app_ca.cer(从 SDK 默认密钥库导出)  refchecker-profile.json(profile 源)

# 1) 编译未签名 HAP
set DEVECO_SDK_HOME=E:/DevEco Studio/sdk
set PATH=E:/DevEco Studio/jbr/bin;%PATH%
node "E:/DevEco Studio/tools/hvigor/bin/hvigorw.js" assembleHap --mode module -p product=default -p buildMode=debug --no-daemon

# 2) 签名（工具：E:/DevEco Studio/sdk/default/openharmony/toolchains/lib/hap-sign-tool.jar）
#    profile 签名：密钥库 OpenHarmony.p12(口令123456)，别名 "openharmony application profile debug"
#    应用签名：    密钥库 refchecker.p12(口令123456)，别名 "refchecker-key"，证书链 app_debug.cer
java -jar hap-sign-tool.jar sign-profile -mode localSign ... -outFile refchecker.p7b
java -jar hap-sign-tool.jar sign-app    -mode localSign ... -outFile refchecker-signed.hap -compatibleVersion 12

# 3) 安装到模拟器（hdc 位于 E:/DevEco Studio/sdk/default/openharmony/toolchains/）
hdc list targets                 # 模拟器地址 127.0.0.1:5555
hdc install -r refchecker-signed.hap

# 4) 启动
hdc shell aa start -a EntryAbility -b com.campus.refchecker
```

关键点（踩坑记录）：

- debug 类型的 profile 必须在 `debug-info.device-ids` 里写上**目标设备 UDID**
  （取法：`hdc shell bm get --udid`），否则安装报 profile 校验失败。
- profile 的 `bundle-name` 必须与 HAP 的 bundleName 完全一致（本应用为 `com.campus.refchecker`）。
- `development-certificate` 必须填与 `sign-app -appCertFile` 同一份证书链。
- 截图用 `hdc shell snapshot_display -f /data/local/tmp/x.jpeg`（**只接受 .jpeg 后缀**），
  再用 `hdc file recv` 拉回本地（目标路径需为 Windows 格式绝对路径）。

## 四、目录结构

```
RefChecker
├── AppScope/                     应用级配置与图标
│   ├── app.json5                 bundleName: com.campus.refchecker
│   └── resources/base/element/string.json   应用名称
├── build-profile.json5           工程构建配置（SDK 版本、产物配置）
├── hvigorfile.ts / oh-package.json5 / hvigor/
└── entry/                        主模块（entry HAP）
    ├── build-profile.json5
    └── src/main/
        ├── module.json5          模块与 Ability 声明（deviceTypes 含 2in1，即 PC）
        ├── ets/
        │   ├── entryability/EntryAbility.ets        入口 Ability，读取本地数据
        │   ├── entrybackupability/EntryBackupAbility.ets
        │   ├── model/CitationData.ets               数据模型 + 校验 + 查重 + 三种格式生成
        │   └── pages/Index.ets                       主界面（三栏布局）
        └── resources/            字符串、颜色、图标、页面路由
```

## 五、核心实现说明

- **数据模型**：`Citation` 接口（12 个字段）+ `CitationType` 五种文献类型。
- **缺字段检查**：`requiredFields(type)` 给出该类型必填字段，`missingFields(c)` 返回缺失项。
- **重复项检查**：`findDuplicateIds(list)` 用归一化标题（去空格标点、转小写）和归一化 DOI（去 `https://doi.org/` 前缀）双规则分组，组内多于 1 条即标记为重复。
- **格式生成**：`formatGBT` / `formatAPA` / `formatMLA` 三个纯函数，按文献类型分支拼接；作者字段支持中西文分别处理。
- **持久化**：条目序列化后用不可见分隔符拼接成字符串，存入 `Preferences`（`ref_store`），键名 `citations_v1`；读取在 `EntryAbility` 中完成，经 `AppStorage` 传给页面，避免首屏取 Context 的时序问题。
- **剪贴板**：`@kit.BasicServicesKit` 的 `pasteboard`，复制单条引用或整份参考文献列表。

## 六、常见问题

1. **打开工程报 `Invalid project path`**：工程路径含中文或非法字符，换到纯英文路径。
2. **运行按钮灰色 / 提示未签名**：在 `Project Structure → Signing Configs` 中勾选自动签名并登录华为账号。
3. **模拟器列表为空**：在 DevEco 的 `Device Manager` 中先下载并创建 PC 模拟器实例。
4. **安装 SDK 时报 `LOCK file could not be obtained`**：上一次 SDK 下载被中断，关闭 DevEco 后删除
   `C:\ProgramData\huawei\Sdk\.temp\` 下对应目录里的 `.op.lock` 残留文件再重试。

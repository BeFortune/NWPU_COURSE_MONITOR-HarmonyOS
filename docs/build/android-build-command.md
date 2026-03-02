## Android Release Build Command

在网络受限环境下，可使用国内 Flutter 源进行构建：

```bash
cmd /c "set FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn&& flutter build apk --release"
```

## 卡片管理提醒应用

### 应用功能




### 配置说明

前端使用 flutter，后端使用 flask。

#### flutter 说明

首先安装 flutter，设置环境变量。找到一个文件夹，用 VS Code 打开然后通过下面命令创建 `card_app` 文件夹

```bash
flutter create card_app
```

因为要显示图片因此在安装了 flutter 后，在 `card_app` 的前端路径下要首先运行

```bash
flutter pub add image_picker
```

因为要联网和格式化，需要运行

```bash
flutter pub add http intl
```

因为要支持 markdown 语法，需要添加

```bash
flutter pub add flutter_markdown
```



#### flask 说明

对于 flask，执行

```
pip install flask flask-sqlalchemy flask-cors flask-jwt-extended
```

`card_backend` 中的 `uploads` 文件夹用来存储图片等文件。


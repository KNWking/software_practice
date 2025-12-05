## 卡片管理提醒应用

### 应用功能




### 配置说明

前端使用 flutter，后端使用 flask。

因为要显示图片因此在安装了 flutter 后，在 `card_app` 的前端路径下要首先运行

```bash
flutter pub add image_picker
```

对于 flask，执行

```
pip install flask flask-sqlalchemy flask-cors
```

`card_backend` 中的 `uploads` 文件夹用来存储图片等文件。


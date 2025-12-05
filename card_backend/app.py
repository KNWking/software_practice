import os
import json
from flask import Flask, request, jsonify, send_from_directory
from flask_sqlalchemy import SQLAlchemy
from flask_cors import CORS
from werkzeug.utils import secure_filename
from datetime import datetime

app = Flask(__name__)
CORS(app)

# === 配置路径 ===
BASE_DIR = os.path.abspath(os.path.dirname(__file__))
UPLOAD_FOLDER = os.path.join(BASE_DIR, 'uploads')
if not os.path.exists(UPLOAD_FOLDER):
    os.makedirs(UPLOAD_FOLDER)

app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///' + os.path.join(BASE_DIR, 'cards.db')
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
app.config['UPLOAD_FOLDER'] = UPLOAD_FOLDER

db = SQLAlchemy(app)


# === 1. 数据模型 ===

# 存储卡片信息
class Card(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    title = db.Column(db.String(100), nullable=False)
    content = db.Column(db.Text, nullable=True)
    image_path = db.Column(db.String(200), nullable=True)  # 新增：图片文件名

    group_name = db.Column(db.String(50), default='默认清单')
    tags = db.Column(db.String(200), default='')
    is_marked = db.Column(db.Boolean, default=False)
    created_at = db.Column(db.DateTime, default=datetime.now)

    reminder_type = db.Column(db.String(20), default='none')
    reminder_value = db.Column(db.String(50), default='')
    last_reviewed = db.Column(db.DateTime, default=datetime.now)

    def to_dict(self):
        # 拼接完整的图片 URL 供前端访问
        img_url = None
        if self.image_path:
            img_url = f"{request.host_url}uploads/{self.image_path}"

        return {
            'id': self.id,
            'title': self.title,
            'content': self.content,
            'image_url': img_url,  # 返回 URL 给前端
            'group_name': self.group_name,
            'tags': self.tags,
            'is_marked': self.is_marked,
            'created_at': self.created_at.isoformat(),
            'reminder_type': self.reminder_type,
            'reminder_value': self.reminder_value,
            'last_reviewed': self.last_reviewed.isoformat() if self.last_reviewed else None
        }


# 存储“元数据” (用户定义的分组和标签列表)
class MetaData(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    groups_json = db.Column(db.Text, default='["默认清单", "工作", "生活"]')  # 存 JSON 字符串
    tags_json = db.Column(db.Text, default='["高优先级", "中优先级", "低优先级"]')


# === 2. 接口 ===

# 初始化元数据 (确保总有一条记录)
def get_or_create_meta():
    meta = MetaData.query.first()
    if not meta:
        meta = MetaData()
        db.session.add(meta)
        db.session.commit()
    return meta


# 获取所有配置 (分组列表 + 标签列表)
@app.route('/api/meta', methods=['GET'])
def get_meta():
    meta = get_or_create_meta()
    return jsonify({
        'groups': json.loads(meta.groups_json),
        'tags': json.loads(meta.tags_json)
    })


# 更新配置 (新建/删除分组或标签时调用)
@app.route('/api/meta', methods=['POST'])
def update_meta():
    meta = get_or_create_meta()
    data = request.json
    if 'groups' in data:
        meta.groups_json = json.dumps(data['groups'])
    if 'tags' in data:
        meta.tags_json = json.dumps(data['tags'])
    db.session.commit()
    return jsonify({'message': 'Updated'})


# 图片上传接口
@app.route('/api/upload', methods=['POST'])
def upload_file():
    if 'file' not in request.files:
        return jsonify({'error': 'No file part'}), 400
    file = request.files['file']
    if file.filename == '':
        return jsonify({'error': 'No selected file'}), 400

    if file:
        # 使用时间戳防止文件名冲突
        timestamp = datetime.now().strftime('%Y%m%d%H%M%S')
        filename = secure_filename(f"{timestamp}_{file.filename}")
        file.save(os.path.join(app.config['UPLOAD_FOLDER'], filename))
        return jsonify({'filename': filename})
    return jsonify({'error': 'Upload failed'}), 500


# 访问图片的接口 (静态资源服务)
@app.route('/uploads/<filename>')
def uploaded_file(filename):
    return send_from_directory(app.config['UPLOAD_FOLDER'], filename)


# 常规卡片接口 (CRUD)
@app.route('/api/cards', methods=['GET'])
def get_cards():
    cards = Card.query.all()
    return jsonify([c.to_dict() for c in reversed(cards)])


@app.route('/api/cards', methods=['POST'])
def create_card():
    data = request.json
    new_card = Card(
        title=data.get('title'),
        content=data.get('content', ''),
        image_path=data.get('image_path', None),  # 接收文件名
        group_name=data.get('group_name', '默认清单'),
        tags=data.get('tags', ''),
        is_marked=data.get('is_marked', False),
        created_at=datetime.now(),
        reminder_type=data.get('reminder_type', 'none'),
        reminder_value=data.get('reminder_value', ''),
        last_reviewed=datetime.now()
    )
    db.session.add(new_card)
    db.session.commit()
    return jsonify(new_card.to_dict()), 201


@app.route('/api/cards/<int:id>', methods=['PUT'])
def update_card(id):
    card = Card.query.get_or_404(id)
    data = request.json

    card.title = data.get('title', card.title)
    card.content = data.get('content', card.content)
    # 只有当前端传了 image_path 且不为空时才更新，防止覆盖为空
    if 'image_path' in data:
        card.image_path = data['image_path']

    card.group_name = data.get('group_name', card.group_name)
    card.tags = data.get('tags', card.tags)
    card.is_marked = data.get('is_marked', card.is_marked)
    card.reminder_type = data.get('reminder_type', card.reminder_type)
    card.reminder_value = data.get('reminder_value', card.reminder_value)
    card.last_reviewed = datetime.now()

    db.session.commit()
    return jsonify(card.to_dict())


@app.route('/api/cards/<int:id>', methods=['DELETE'])
def delete_card(id):
    card = Card.query.get_or_404(id)
    db.session.delete(card)
    db.session.commit()
    return jsonify({'message': 'Deleted'})


if __name__ == '__main__':
    with app.app_context():
        db.create_all()
    app.run(debug=True, host='0.0.0.0', port=5000)
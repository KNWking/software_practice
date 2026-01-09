import json
from datetime import datetime

from extensions import db
from flask import request
from werkzeug.security import check_password_hash, generate_password_hash

# === 数据模型 ===

class User(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    username = db.Column(db.String(80), unique=True, nullable=False)
    password_hash = db.Column(db.String(128), nullable=False)

    def set_password(self, password):
        self.password_hash = generate_password_hash(password)

    def check_password(self, password):
        return check_password_hash(self.password_hash, password)


class Card(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('user.id'), nullable=False)  # 关联用户
    title = db.Column(db.String(100), nullable=False)
    content = db.Column(db.Text, nullable=True)
    images_json = db.Column(db.Text, default='[]')
    group_name = db.Column(db.String(50), default='默认清单')
    tags = db.Column(db.String(200), default='')
    is_marked = db.Column(db.Boolean, default=False)
    is_completed = db.Column(db.Boolean, default=False)
    created_at = db.Column(db.DateTime, default=datetime.now)
    reminder_type = db.Column(db.String(20), default='none')
    reminder_value = db.Column(db.String(50), default='')
    last_reviewed = db.Column(db.DateTime, default=datetime.now)

    def to_dict(self):
        try:
            filenames = json.loads(self.images_json)
        except:
            filenames = []
        # 云端部署时，注意这里 request.host_url 会自动适配域名/IP
        img_urls = [f"{request.host_url}uploads/{fn}" for fn in filenames]
        return {
            'id': self.id,
            'title': self.title,
            'content': self.content,
            'image_urls': img_urls,
            'group_name': self.group_name,
            'tags': self.tags,
            'is_marked': self.is_marked,
            'is_completed': self.is_completed,
            'created_at': self.created_at.isoformat(),
            'reminder_type': self.reminder_type,
            'reminder_value': self.reminder_value,
            'last_reviewed': self.last_reviewed.isoformat() if self.last_reviewed else None
        }


class MetaData(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('user.id'), nullable=False)  # 每个用户有自己的分组配置
    groups_json = db.Column(db.Text, default='["默认清单", "工作", "生活"]')
    tags_json = db.Column(db.Text, default='["高优先级", "中优先级", "低优先级"]')
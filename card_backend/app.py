from flask import Flask, request, jsonify
from flask_sqlalchemy import SQLAlchemy
from flask_cors import CORS
from datetime import datetime
import os

app = Flask(__name__)

# 允许跨域请求 (关键：让浏览器里的 Flutter 能访问后端)
CORS(app)

# 配置 SQLite 数据库
# 数据库文件 cards.db 会自动生成在当前项目文件夹下
basedir = os.path.abspath(os.path.dirname(__file__))
app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///' + os.path.join(basedir, 'cards.db')
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False

db = SQLAlchemy(app)


# === 1. 定义数据模型 ===
class Card(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    title = db.Column(db.String(100), nullable=False)
    content = db.Column(db.Text, nullable=False)
    is_marked = db.Column(db.Boolean, default=False)
    # 提醒相关字段
    reminder_type = db.Column(db.String(20), default='none')  # none, periodic, specific
    reminder_value = db.Column(db.String(50), default='')
    last_reviewed = db.Column(db.DateTime, default=datetime.now)

    def to_dict(self):
        """把数据库模型转换为字典，方便转成JSON传给前端"""
        return {
            'id': self.id,
            'title': self.title,
            'content': self.content,
            'is_marked': self.is_marked,
            'reminder_type': self.reminder_type,
            'reminder_value': self.reminder_value,
            'last_reviewed': self.last_reviewed.isoformat() if self.last_reviewed else None
        }


# === 2. 定义 API 接口 ===

# 获取所有卡片
@app.route('/api/cards', methods=['GET'])
def get_cards():
    cards = Card.query.all()
    # 倒序排列，最新的在前面
    return jsonify([c.to_dict() for c in reversed(cards)])


# 新建卡片
@app.route('/api/cards', methods=['POST'])
def create_card():
    data = request.json
    new_card = Card(
        title=data.get('title'),
        content=data.get('content'),
        is_marked=data.get('is_marked', False),
        reminder_type=data.get('reminder_type', 'none'),
        reminder_value=data.get('reminder_value', ''),
        last_reviewed=datetime.now()
    )
    db.session.add(new_card)
    db.session.commit()
    return jsonify(new_card.to_dict()), 201


# 更新卡片
@app.route('/api/cards/<int:id>', methods=['PUT'])
def update_card(id):
    card = Card.query.get_or_404(id)
    data = request.json

    card.title = data.get('title', card.title)
    card.content = data.get('content', card.content)
    card.is_marked = data.get('is_marked', card.is_marked)
    card.reminder_type = data.get('reminder_type', card.reminder_type)
    card.reminder_value = data.get('reminder_value', card.reminder_value)

    # 只要编辑了，就更新一下“上次查看时间”
    card.last_reviewed = datetime.now()

    db.session.commit()
    return jsonify(card.to_dict())


# 删除卡片
@app.route('/api/cards/<int:id>', methods=['DELETE'])
def delete_card(id):
    card = Card.query.get_or_404(id)
    db.session.delete(card)
    db.session.commit()
    return jsonify({'message': 'Deleted'})


# === 3. 启动程序 ===
if __name__ == '__main__':
    with app.app_context():
        db.create_all()  # 首次运行会自动创建 cards.db 文件
    # 启动服务，端口 5000
    app.run(debug=True, host='0.0.0.0', port=5000)


import json
import os
from datetime import datetime, timedelta

from data_models import Card, MetaData, User
from extensions import cors, db, jwt
from flask import Flask, Response, jsonify, request, send_from_directory
from flask_jwt_extended import (create_access_token, get_jwt_identity,
                                jwt_required)
from werkzeug.utils import secure_filename

# === 配置部分 (适配云端部署) ===
BASE_DIR = os.path.abspath(os.path.dirname(__file__))
UPLOAD_FOLDER = os.path.join(BASE_DIR, 'uploads')
if not os.path.exists(UPLOAD_FOLDER):
    os.makedirs(UPLOAD_FOLDER)

# === 创建 Flask 应用实例 ===
app = Flask(__name__)

# 生产环境建议将密钥放入环境变量
app.config['SECRET_KEY'] = os.environ.get('SECRET_KEY', 'default-dev-secret-key')
app.config['JWT_SECRET_KEY'] = os.environ.get('JWT_SECRET_KEY', 'default-jwt-secret-key')
app.config['JWT_ACCESS_TOKEN_EXPIRES'] = timedelta(days=7)  # Token 7天有效，方便测试

app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///' + os.path.join(BASE_DIR, 'cards.db')
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
app.config['UPLOAD_FOLDER'] = UPLOAD_FOLDER


# === 初始化扩展 ===
db.init_app(app)
jwt.init_app(app)

# 允许所有来源，允许 Content-Type 和 Authorization 头，允许跨域携带凭证
cors.init_app(app,
     resources={r"/*": {"origins": "*"}},
     supports_credentials=True,
     allow_headers=["Content-Type", "Authorization", "Access-Control-Allow-Credentials"],
     max_age=timedelta(hours=1))


# === 辅助函数 ===

def delete_card_logic(card):
    # 注意：这里有个策略问题。
    # 如果多个用户可能上传同一个图片名，直接删除文件会误删。
    # 简单起见，本课程实验暂时保留物理文件，或者假设文件名因为带时间戳而唯一。
    # 真正的生产环境应该使用对象存储 (如华为云 OBS)。
    try:
        filenames = json.loads(card.images_json)
        for fn in filenames:
            file_path = os.path.join(app.config['UPLOAD_FOLDER'], fn)
            if os.path.exists(file_path):
                try:
                    os.remove(file_path)
                except:
                    pass
    except Exception as e:
        print(f"Error deleting files: {e}")
    db.session.delete(card)


def get_or_create_meta(user_id):
    meta = MetaData.query.filter_by(user_id=user_id).first()
    if not meta:
        # 调试日志
        print(f"--- Creating default meta for user {user_id} ---")
        # 定义默认 JSON 字符串
        default_groups = json.dumps(["默认清单", "学习", "工作"], ensure_ascii=False)
        default_tags = json.dumps(["高优先级", "中优先级", "低优先级"], ensure_ascii=False)

        # 创建时显式赋值，而不是依赖数据库的 default
        meta = MetaData(
            user_id=user_id,
            groups_json=default_groups,
            tags_json=default_tags
        )
        db.session.add(meta)
        db.session.commit()

        # 再次刷新对象，确保数据与数据库同步
        db.session.refresh(meta)

    return meta


# === 预检请求 ===

@app.before_request
def process_options_request():
    if request.method != "OPTIONS":
        return

    # 预检请求无需响应体，保持空返回
    # 此处不应当使用 204 No Content，因为某些浏览器错误地认为该资源同样为空，不发送后续请求以获取该资源
    # Flask 目前不支持移除 Content-Length 头，此处不做修改，保持默认行为 (Content-Length: 0)
    response = Response(status=200)
    response.headers.pop('Content-Type', None)
    return response


# === 认证接口 ===

@app.route('/api/auth/register', methods=['POST'])
def register():
    data = request.json
    username = data.get('username')
    password = data.get('password')

    if not username or not password:
        return jsonify({'error': '用户名和密码不能为空'}), 400

    if User.query.filter_by(username=username).first():
        return jsonify({'error': '用户名已存在'}), 400

    new_user = User(username=username)
    new_user.set_password(password)
    db.session.add(new_user)
    db.session.commit()

    return jsonify({'message': '注册成功'}), 201

@app.route('/api/auth/login', methods=['POST'])
def login():
    data = request.json
    username = data.get('username')
    password = data.get('password')

    user = User.query.filter_by(username=username).first()
    if not user or not user.check_password(password):
        return jsonify({'error': '用户名或密码错误'}), 401

    # identity 存 user_id
    # identity 必须是字符串，所以用 str() 包裹 user.id
    access_token = create_access_token(identity=str(user.id))
    return jsonify({'access_token': access_token, 'username': username}), 200


# === 业务接口 (全部增加 @jwt_required) ===

@app.route('/api/meta', methods=['GET'])
@jwt_required()
def get_meta():
    current_user_id = get_jwt_identity()
    meta = get_or_create_meta(current_user_id)
    return jsonify({'groups': json.loads(meta.groups_json), 'tags': json.loads(meta.tags_json)})


@app.route('/api/meta', methods=['POST'])
@jwt_required()
def update_meta():
    current_user_id = get_jwt_identity()
    meta = get_or_create_meta(current_user_id)
    data = request.json
    if 'groups' in data: meta.groups_json = json.dumps(data['groups'], ensure_ascii=False)
    if 'tags' in data: meta.tags_json = json.dumps(data['tags'], ensure_ascii=False)
    db.session.commit()
    return jsonify({'message': 'Updated'})


@app.route('/api/meta/delete_group', methods=['POST'])
@jwt_required()
def delete_group_api():
    current_user_id = get_jwt_identity()
    target_group = request.json.get('name')
    # 只删除属于当前用户的卡片
    cards = Card.query.filter_by(user_id=current_user_id, group_name=target_group).all()
    for c in cards: delete_card_logic(c)

    meta = get_or_create_meta(current_user_id)
    groups = json.loads(meta.groups_json)
    if target_group in groups:
        groups.remove(target_group)
        meta.groups_json = json.dumps(groups, ensure_ascii=False)
    db.session.commit()
    return jsonify({'message': 'Group deleted'})


@app.route('/api/meta/delete_tag', methods=['POST'])
@jwt_required()
def delete_tag_api():
    current_user_id = get_jwt_identity()
    target_tag = request.json.get('name')
    all_cards = Card.query.filter_by(user_id=current_user_id).all()
    for c in all_cards:
        if not c.tags: continue
        tag_list = c.tags.split(',')
        if target_tag in tag_list:
            tag_list.remove(target_tag)
            c.tags = ','.join(tag_list)

    meta = get_or_create_meta(current_user_id)
    tags = json.loads(meta.tags_json)
    if target_tag in tags:
        tags.remove(target_tag)
        meta.tags_json = json.dumps(tags, ensure_ascii=False)
    db.session.commit()
    return jsonify({'message': 'Tag deleted'})


# 图片上传不需要严格鉴权，或者可以鉴权但允许任何登录用户上传
@app.route('/api/upload', methods=['POST'])
def upload_file():
    if 'file' not in request.files: return jsonify({'error': 'No file part'}), 400
    file = request.files['file']
    if file.filename == '': return jsonify({'error': 'No selected file'}), 400
    if file:
        timestamp = datetime.now().strftime('%Y%m%d%H%M%S%f')
        filename = secure_filename(f"{timestamp}_{file.filename}")
        file.save(os.path.join(app.config['UPLOAD_FOLDER'], filename))
        return jsonify({'filename': filename})
    return jsonify({'error': 'Upload failed'}), 500


@app.route('/uploads/<filename>')
def uploaded_file(filename):
    return send_from_directory(app.config['UPLOAD_FOLDER'], filename)


@app.route('/api/cards', methods=['GET'])
@jwt_required()
def get_cards():
    current_user_id = get_jwt_identity()
    # 关键：只查询当前用户的卡片
    cards = Card.query.filter_by(user_id=current_user_id).all()
    return jsonify([c.to_dict() for c in reversed(cards)])


@app.route('/api/cards', methods=['POST'])
@jwt_required()
def create_card():
    current_user_id = get_jwt_identity()
    data = request.json
    new_card = Card(
        user_id=current_user_id,  # 绑定用户
        title=data.get('title'),
        content=data.get('content', ''),
        images_json=json.dumps(data.get('image_paths', []), ensure_ascii=False),
        group_name=data.get('group_name', '默认清单'),
        tags=data.get('tags', ''),
        is_marked=data.get('is_marked', False),
        is_completed=data.get('is_completed', False),
        created_at=datetime.now(),
        reminder_type=data.get('reminder_type', 'none'),
        reminder_value=data.get('reminder_value', ''),
        last_reviewed=datetime.now()
    )
    db.session.add(new_card)
    db.session.commit()
    return jsonify(new_card.to_dict()), 201


@app.route('/api/cards/<int:id>', methods=['PUT'])
@jwt_required()
def update_card(id):
    current_user_id = get_jwt_identity()
    # 确保只能修改自己的卡片
    card = Card.query.filter_by(id=id, user_id=current_user_id).first_or_404()

    data = request.json
    card.title = data.get('title', card.title)
    card.content = data.get('content', card.content)
    if 'image_paths' in data:
        card.images_json = json.dumps(data['image_paths'], ensure_ascii=False)
    card.group_name = data.get('group_name', card.group_name)
    card.tags = data.get('tags', card.tags)
    card.is_marked = data.get('is_marked', card.is_marked)
    card.is_completed = data.get('is_completed', card.is_completed)
    card.reminder_type = data.get('reminder_type', card.reminder_type)
    card.reminder_value = data.get('reminder_value', card.reminder_value)
    card.last_reviewed = datetime.now()
    db.session.commit()
    return jsonify(card.to_dict())


@app.route('/api/cards/<int:id>', methods=['DELETE'])
@jwt_required()
def delete_card(id):
    current_user_id = get_jwt_identity()
    # 确保只能删除自己的卡片
    card = Card.query.filter_by(id=id, user_id=current_user_id).first_or_404()
    delete_card_logic(card)
    db.session.commit()
    return jsonify({'message': 'Deleted'})


if __name__ == '__main__':
    with app.app_context():
        db.create_all()

    # 注意：部署到云端时通常使用 Gunicorn，不直接用 app.run
    app.run(debug=True, host='localhost', port=5000)
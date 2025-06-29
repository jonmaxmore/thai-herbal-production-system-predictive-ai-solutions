# backend/app/models.py (SQLAlchemy)
class Certification(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    herb = db.Column(db.String(100))
    farm = db.Column(db.String(100))
    status = db.Column(db.String(20))

# backend/app/ai/routes.py (Python Flask)
@ai_bp.route('/analyze', methods=['POST'])
def analyze_image():
    image = request.files['image'].read()
    # AI processing
    quality_score = ai_model.predict_quality(image)
    pests = ai_model.detect_pests(image)
    return jsonify({
        'quality_score': quality_score,
        'pests_detected': pests
    })

// backend/services/prediction.go (Golang)
func PredictYield(c *gin.Context) {
  var data PredictionData
  if err := c.ShouldBindJSON(&data); err != nil {
    c.JSON(400, gin.H{"error": err.Error()})
    return
  }
  prediction := mlModel.Predict(data)
  c.JSON(200, prediction)
}

// backend/routes/traceability.js (Node.js)
router.get('/:qrCode', async (req, res) => {
  const trace = await Traceability.findOne({ qrCode: req.params.qrCode });
  if (!trace) return res.status(404).json({ error: 'Not found' });
  res.json(trace);
});

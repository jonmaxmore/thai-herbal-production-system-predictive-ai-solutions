import React, { useState, useEffect } from 'react';
import { Container, Row, Col, Card, Spinner, Alert } from 'react-bootstrap';
import axios from 'axios';
import HerbsChart from '../components/charts/HerbsChart';
import QualityMetrics from '../components/QualityMetrics';
import RecentActivities from '../components/RecentActivities';

const Dashboard = () => {
  const [dashboardData, setDashboardData] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  useEffect(() => {
    const fetchDashboardData = async () => {
      try {
        const response = await axios.get('/api/admin/dashboard');
        setDashboardData(response.data);
        setLoading(false);
      } catch (err) {
        setError('Failed to load dashboard data');
        setLoading(false);
        console.error('Dashboard error:', err);
      }
    };

    fetchDashboardData();
    const interval = setInterval(fetchDashboardData, 300000); // Refresh every 5 minutes
    
    return () => clearInterval(interval);
  }, []);

  if (loading) {
    return (
      <Container className="d-flex justify-content-center align-items-center" style={{ height: '80vh' }}>
        <Spinner animation="border" role="status">
          <span className="visually-hidden">Loading...</span>
        </Spinner>
      </Container>
    );
  }

  if (error) {
    return (
      <Container className="mt-5">
        <Alert variant="danger">{error}</Alert>
      </Container>
    );
  }

  return (
    <Container fluid className="mt-4">
      <h1 className="mb-4">ระบบบริหารจัดการสมุนไพรไทย</h1>
      
      <Row className="mb-4">
        <Col md={3}>
          <Card className="h-100">
            <Card.Body>
              <Card.Title>ผู้ใช้ทั้งหมด</Card.Title>
              <Card.Text className="display-6">
                {dashboardData?.users?.total || 0}
              </Card.Text>
              <Card.Subtitle className="text-muted">
                (+{dashboardData?.users?.newThisWeek || 0} ในสัปดาห์นี้)
              </Card.Subtitle>
            </Card.Body>
          </Card>
        </Col>
        
        <Col md={3}>
          <Card className="h-100">
            <Card.Body>
              <Card.Title>การผลิต</Card.Title>
              <Card.Text className="display-6">
                {dashboardData?.production?.batches || 0}
              </Card.Text>
              <Card.Subtitle className="text-muted">
                {dashboardData?.production?.inProgress || 0} กำลังดำเนินการ
              </Card.Subtitle>
            </Card.Body>
          </Card>
        </Col>
        
        <Col md={3}>
          <Card className="h-100">
            <Card.Body>
              <Card.Title>คุณภาพเฉลี่ย</Card.Title>
              <Card.Text className="display-6">
                {dashboardData?.quality?.averageScore 
                  ? `${(dashboardData.quality.averageScore * 100).toFixed(1)}%` 
                  : 'N/A'}
              </Card.Text>
              <Card.Subtitle className="text-muted">
                {dashboardData?.quality?.assessments || 0} การประเมิน
              </Card.Subtitle>
            </Card.Body>
          </Card>
        </Col>
        
        <Col md={3}>
          <Card className="h-100">
            <Card.Body>
              <Card.Title>การรับรอง GACP</Card.Title>
              <Card.Text className="display-6">
                {dashboardData?.certifications?.valid || 0}
              </Card.Text>
              <Card.Subtitle className="text-muted">
                {dashboardData?.certifications?.expiringSoon || 0} ใกล้หมดอายุ
              </Card.Subtitle>
            </Card.Body>
          </Card>
        </Col>
      </Row>
      
      <Row className="mb-4">
        <Col md={8}>
          <Card className="h-100">
            <Card.Body>
              <Card.Title>การผลิตตามประเภทสมุนไพร</Card.Title>
              <HerbsChart data={dashboardData?.herbsChart || []} />
            </Card.Body>
          </Card>
        </Col>
        
        <Col md={4}>
          <Card className="h-100">
            <Card.Body>
              <Card.Title>เมตริกคุณภาพ</Card.Title>
              <QualityMetrics metrics={dashboardData?.qualityMetrics || {}} />
            </Card.Body>
          </Card>
        </Col>
      </Row>
      
      <Row>
        <Col>
          <Card>
            <Card.Body>
              <Card.Title>กิจกรรมล่าสุด</Card.Title>
              <RecentActivities activities={dashboardData?.recentActivities || []} />
            </Card.Body>
          </Card>
        </Col>
      </Row>
    </Container>
  );
};

export default Dashboard;

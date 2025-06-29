import http from '../utils/http';
import { handleApiError } from '../utils/errorHandler';

const HerbService = {
  async getAllHerbs(page = 1, pageSize = 20) {
    try {
      const response = await http.get('/herbs', {
        params: { page, pageSize },
      });
      return response.data;
    } catch (error) {
      handleApiError(error, 'Failed to fetch herbs');
      throw error;
    }
  },

  async getHerbById(id) {
    try {
      const response = await http.get(`/herbs/${id}`);
      return response.data;
    } catch (error) {
      handleApiError(error, `Failed to fetch herb ${id}`);
      throw error;
    }
  },

  async createHerb(herbData) {
    try {
      const response = await http.post('/herbs', herbData);
      return response.data;
    } catch (error) {
      handleApiError(error, 'Failed to create herb');
      throw error;
    }
  },

  async updateHerb(id, herbData) {
    try {
      const response = await http.put(`/herbs/${id}`, herbData);
      return response.data;
    } catch (error) {
      handleApiError(error, `Failed to update herb ${id}`);
      throw error;
    }
  },

  async addQualityAssessment(herbId, assessmentData) {
    try {
      const response = await http.post(
        `/herbs/${herbId}/quality-assessment`,
        assessmentData
      );
      return response.data;
    } catch (error) {
      handleApiError(error, 'Failed to add quality assessment');
      throw error;
    }
  },

  async getHerbQualityHistory(herbId) {
    try {
      const response = await http.get(`/herbs/${herbId}/quality-history`);
      return response.data;
    } catch (error) {
      handleApiError(error, 'Failed to fetch quality history');
      throw error;
    }
  },
};

export default HerbService;

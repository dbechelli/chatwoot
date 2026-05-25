import ApiClient from './ApiClient';
import axios from 'axios';

class CalendarEventsAPI extends ApiClient {
  constructor() {
    super('calendar_events', { accountScoped: true });
  }

  get(params) {
    return axios.get(this.url, { params });
  }
}

export default new CalendarEventsAPI();

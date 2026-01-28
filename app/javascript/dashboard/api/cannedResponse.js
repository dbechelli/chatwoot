/* global axios */

import ApiClient from './ApiClient';

class CannedResponse extends ApiClient {
  constructor() {
    super('canned_responses', { accountScoped: true });
  }

  get({ searchKey }) {
    const url = searchKey ? `${this.url}?search=${searchKey}` : this.url;
    return axios.get(url);
  }

  create(params) {
    const formData = new FormData();
    Object.keys(params).forEach(key => {
      if (key === 'attachments') {
        [...params[key]].forEach(file => {
          formData.append('canned_response[attachments][]', file);
        });
      } else {
        formData.append(`canned_response[${key}]`, params[key]);
      }
    });
    return axios.post(this.url, formData);
  }

  update(id, params) {
    const formData = new FormData();
    Object.keys(params).forEach(key => {
      if (key === 'attachments') {
        [...params[key]].forEach(file => {
          formData.append('canned_response[attachments][]', file);
        });
      } else {
        formData.append(`canned_response[${key}]`, params[key]);
      }
    });
    return axios.patch(`${this.url}/${id}`, formData);
  }
}

export default new CannedResponse();

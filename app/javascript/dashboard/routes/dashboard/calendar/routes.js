import { frontendURL } from '../../helper/URLHelper';
import Calendar from './Index.vue';

export const routes = [
  {
    path: frontendURL('accounts/:accountId/calendar'),
    name: 'calendar_dashboard',
    meta: {
      permissions: ['administrator', 'agent'],
    },
    component: Calendar,
  },
];

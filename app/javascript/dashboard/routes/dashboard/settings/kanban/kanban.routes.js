import { frontendURL } from '../../../../helper/URLHelper';
import SettingsWrapper from '../SettingsWrapper.vue';

export default {
  routes: [
    {
      path: frontendURL('accounts/:accountId/settings/kanban'),
      component: SettingsWrapper,
      children: [
        {
          path: '',
          name: 'kanban_settings',
          redirect: to => ({ name: 'kanban_funnels', params: to.params }),
          meta: {
            permissions: ['administrator'],
          },
        },
      ],
    },
  ],
};

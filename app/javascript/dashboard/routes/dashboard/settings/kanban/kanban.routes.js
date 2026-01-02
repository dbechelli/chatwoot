import { frontendURL } from '../../../../helper/URLHelper';
import SettingsWrapper from '../SettingsWrapper.vue';
import KanbanSettings from './Index.vue';

export default {
  routes: [
    {
      path: frontendURL('accounts/:accountId/settings/kanban'),
      component: SettingsWrapper,
      children: [
        {
          path: '',
          name: 'kanban_settings',
          component: KanbanSettings,
          meta: {
            permissions: ['administrator'],
          },
        },
      ],
    },
  ],
};

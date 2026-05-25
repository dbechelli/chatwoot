import { frontendURL } from '../../../helper/URLHelper';
import KanbanView from '../conversation/KanbanView.vue';
import KanbanPageRouteView from './pages/KanbanPageRouteView.vue';
import KanbanOverviewPage from './pages/KanbanOverviewPage.vue';
import KanbanFunnelsPage from './pages/KanbanFunnelsPage.vue';
import KanbanBoardEditorPage from './pages/KanbanBoardEditorPage.vue';

const meta = {
  permissions: ['administrator', 'agent', 'custom_role'],
};

const adminMeta = {
  permissions: ['administrator'],
};

export const routes = [
  {
    path: frontendURL('accounts/:accountId/kanban'),
    component: KanbanPageRouteView,
    name: 'kanban',
    meta,
    redirect: to => ({ name: 'kanban_overview', params: to.params }),
    children: [
      {
        path: 'overview',
        name: 'kanban_overview',
        component: KanbanOverviewPage,
        meta,
      },
      {
        path: 'funnels',
        name: 'kanban_funnels',
        component: KanbanFunnelsPage,
        meta,
      },
      {
        path: 'funnels/new',
        name: 'kanban_board_new',
        component: KanbanBoardEditorPage,
        meta: adminMeta,
      },
      {
        path: 'funnels/:boardId',
        name: 'kanban_board',
        component: KanbanView,
        meta,
      },
      {
        path: 'funnels/:boardId/edit',
        name: 'kanban_board_edit',
        component: KanbanBoardEditorPage,
        meta: adminMeta,
      },
      {
        path: 'reports',
        redirect: to => ({ name: 'kanban_overview', params: to.params }),
      },
    ],
  },
];

import * as types from '../mutation-types';

const buildKanbanError = error => {
  const responseData = error?.response?.data || {};
  const kanbanError = new Error(responseData.error || error?.message || '');

  if (responseData.error_code) {
    kanbanError.code = responseData.error_code;
  }

  return kanbanError;
};

const state = {
  records: [],
  uiFlags: {
    isFetching: false,
    isCreating: false,
    isUpdating: false,
    isDeleting: false,
  },
};

const getters = {
  getBoards: $state => $state.records,
  getBoardById: $state => id => $state.records.find(board => board.id === id),
  getUIFlags: $state => $state.uiFlags,
};

const actions = {
  fetch: async ({ commit, rootGetters }) => {
    commit(types.default.SET_KANBAN_UI_FLAG, { isFetching: true });
    try {
      const accountId = rootGetters.getCurrentAccountId;
      if (!accountId) return;
      const response = await window.axios.get(
        `/api/v1/accounts/${accountId}/kanban_settings`
      );
      commit(types.default.SET_KANBAN_BOARDS, response.data.boards || []);
    } catch (error) {
      // Ignore error
    } finally {
      commit(types.default.SET_KANBAN_UI_FLAG, { isFetching: false });
    }
  },

  create: async ({ commit, rootGetters }, boardData) => {
    commit(types.default.SET_KANBAN_UI_FLAG, { isCreating: true });
    try {
      const accountId = rootGetters.getCurrentAccountId;
      const response = await window.axios.post(
        `/api/v1/accounts/${accountId}/kanban_settings/boards`,
        { board: boardData }
      );
      commit(types.default.ADD_KANBAN_BOARD, response.data);
      return response.data;
    } catch (error) {
      throw buildKanbanError(error);
    } finally {
      commit(types.default.SET_KANBAN_UI_FLAG, { isCreating: false });
    }
  },

  update: async ({ commit, rootGetters }, { id, ...boardData }) => {
    commit(types.default.SET_KANBAN_UI_FLAG, { isUpdating: true });
    try {
      const accountId = rootGetters.getCurrentAccountId;
      const response = await window.axios.put(
        `/api/v1/accounts/${accountId}/kanban_settings/boards/${id}`,
        { board: boardData }
      );
      commit(types.default.UPDATE_KANBAN_BOARD, response.data);
      return response.data;
    } catch (error) {
      throw buildKanbanError(error);
    } finally {
      commit(types.default.SET_KANBAN_UI_FLAG, { isUpdating: false });
    }
  },

  delete: async ({ commit, rootGetters }, id) => {
    commit(types.default.SET_KANBAN_UI_FLAG, { isDeleting: true });
    try {
      const accountId = rootGetters.getCurrentAccountId;
      await window.axios.delete(
        `/api/v1/accounts/${accountId}/kanban_settings/boards/${id}`
      );
      commit(types.default.DELETE_KANBAN_BOARD, id);
    } catch (error) {
      throw buildKanbanError(error);
    } finally {
      commit(types.default.SET_KANBAN_UI_FLAG, { isDeleting: false });
    }
  },
};

const mutations = {
  [types.default.SET_KANBAN_UI_FLAG]($state, data) {
    $state.uiFlags = {
      ...$state.uiFlags,
      ...data,
    };
  },
  [types.default.SET_KANBAN_BOARDS](
    $state,
    boards
  ) {
    $state.records = boards;
  },
  [types.default.ADD_KANBAN_BOARD](
    $state,
    board
  ) {
    $state.records.push(board);
  },
  [types.default.UPDATE_KANBAN_BOARD](
    $state,
    updatedBoard
  ) {
    const index = $state.records.findIndex(b => b.id === updatedBoard.id);
    if (index !== -1) {
      $state.records.splice(index, 1, updatedBoard);
    }
  },
  [types.default.DELETE_KANBAN_BOARD](
    $state,
    id
  ) {
    $state.records = $state.records.filter(b => b.id !== id);
  },
};

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations,
};

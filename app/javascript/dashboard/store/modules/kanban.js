import * as types from '../mutation-types';
import axios from 'axios';

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
  fetch: async ({ commit }) => {
    commit(types.default.SET_KANBAN_UI_FLAG, { isFetching: true });
    try {
      const response = await axios.get(
        `/api/v1/accounts/${window.chatwootConfig.accountId}/kanban_settings`
      );
      commit(types.default.SET_KANBAN_BOARDS, response.data.boards || []);
    } catch (error) {
      // Ignore error
    } finally {
      commit(types.default.SET_KANBAN_UI_FLAG, { isFetching: false });
    }
  },

  create: async ({ commit }, boardData) => {
    commit(types.default.SET_KANBAN_UI_FLAG, { isCreating: true });
    try {
      const response = await axios.post(
        `/api/v1/accounts/${window.chatwootConfig.accountId}/kanban_settings/boards`,
        { board: boardData }
      );
      commit(types.default.ADD_KANBAN_BOARD, response.data);
      return response.data;
    } catch (error) {
      throw error;
    } finally {
      commit(types.default.SET_KANBAN_UI_FLAG, { isCreating: false });
    }
  },

  update: async ({ commit }, { id, ...boardData }) => {
    commit(types.default.SET_KANBAN_UI_FLAG, { isUpdating: true });
    try {
      const response = await axios.put(
        `/api/v1/accounts/${window.chatwootConfig.accountId}/kanban_settings/boards/${id}`,
        { board: boardData }
      );
      commit(types.default.UPDATE_KANBAN_BOARD, response.data);
      return response.data;
    } catch (error) {
      throw error;
    } finally {
      commit(types.default.SET_KANBAN_UI_FLAG, { isUpdating: false });
    }
  },

  delete: async ({ commit }, id) => {
    commit(types.default.SET_KANBAN_UI_FLAG, { isDeleting: true });
    try {
      await axios.delete(
        `/api/v1/accounts/${window.chatwootConfig.accountId}/kanban_settings/boards/${id}`
      );
      commit(types.default.DELETE_KANBAN_BOARD, id);
    } catch (error) {
      throw error;
    } finally {
      commit(types.default.SET_KANBAN_UI_FLAG, { isDeleting: false });
    }
  },
};

const mutations = {
  [types.default.SET_KANBAN_UI_FLAG](
    $state,
    { isFetching, isCreating, isUpdating, isDeleting }
  ) {
    $state.uiFlags = {
      ...$state.uiFlags,
      isFetching: isFetching || $state.uiFlags.isFetching,
      isCreating: isCreating || $state.uiFlags.isCreating,
      isUpdating: isUpdating || $state.uiFlags.isUpdating,
      isDeleting: isDeleting || $state.uiFlags.isDeleting,
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

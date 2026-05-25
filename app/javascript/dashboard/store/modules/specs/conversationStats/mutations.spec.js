import types from '../../../mutation-types';
import { mutations } from '../../conversationStats';

describe('#mutations', () => {
  describe('#SET_CONV_TAB_META', () => {
    it('set conversation stats correctly', () => {
      const state = {};
      mutations[types.SET_CONV_TAB_META](state, {
        mine_count: 1,
        unassigned_count: 1,
        all_count: 2,
        resolved_count: 3,
      });
      expect(state).toEqual({
        mineCount: 1,
        unAssignedCount: 1,
        allCount: 2,
        resolvedCount: 3,
        updatedOn: expect.any(Date),
      });
    });

    it('preserves existing counts when a partial payload is received', () => {
      const state = {
        mineCount: 4,
        unAssignedCount: 2,
        allCount: 8,
        resolvedCount: 5,
      };

      mutations[types.SET_CONV_TAB_META](state, {
        mine_count: 6,
      });

      expect(state).toEqual({
        mineCount: 6,
        unAssignedCount: 2,
        allCount: 8,
        resolvedCount: 5,
        updatedOn: expect.any(Date),
      });
    });
  });
});

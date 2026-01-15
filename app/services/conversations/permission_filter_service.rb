class Conversations::PermissionFilterService
  attr_reader :conversations, :user, :account

  def initialize(conversations, user, account)
    @conversations = conversations
    @user = user
    @account = account
  end

  def perform
    return conversations if user_role == 'administrator'

    accessible_conversations
  end

  private

  def accessible_conversations
    # Filter by inboxes the user has access to
    inbox_filtered = conversations.where(inbox: user.inboxes.where(account_id: account.id))

    # Additional filter by teams for agents
    team_filtered_conversations(inbox_filtered)
  end

  def team_filtered_conversations(base_conversations)
    # Get all team IDs the user belongs to
    user_team_ids = user.team_members.pluck(:team_id)

    # If user is not part of any team, return only conversations assigned to them
    return base_conversations.assigned_to(user) if user_team_ids.empty?

    # Return conversations that match ANY of these conditions:
    # 1. Belong to one of the user's teams
    # 2. Are assigned to the user (even if from a different team)
    # 3. Have no team assigned (team_id IS NULL)
    base_conversations.where(
      'team_id IN (?) OR assignee_id = ? OR team_id IS NULL',
      user_team_ids,
      user.id
    )
  end

  def account_user
    AccountUser.find_by(account_id: account.id, user_id: user.id)
  end

  def user_role
    account_user&.role
  end
end

Conversations::PermissionFilterService.prepend_mod_with('Conversations::PermissionFilterService')

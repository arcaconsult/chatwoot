# Arcaconsult: the counterpart to custom/app/policies/custom/conversation_policy.rb --
# that file only gates opening ONE conversation (Pundit's `show?`, e.g. GET /conversations/:id).
# The sidebar list (Minhas / Não atribuídas / Todos, and the unread badge counts) is built by
# a completely different path -- ConversationFinder calls this class directly, which never
# consults ConversationPolicy at all.
#
# Same dynamic rule as conversation_policy.rb, restated at the query level instead of per
# record: once a conversation carries a label whose name matches an existing team's name,
# only administrators, agent bots, and members of that team keep seeing it in lists and
# counts. The segregated-label set is read live from `account.teams` -- see the long comment
# in conversation_policy.rb for what that trades away and why it was chosen anyway, and for
# why Team#name / Label#title being downcased means no case-normalizing is needed here.
#
# `super` runs first every time, so this only ever narrows further whatever the base class
# (administrator short-circuit) or Enterprise::Conversations::PermissionFilterService (Custom
# Role filtering) already decided -- same "can only take away" contract as the show? patch.
module Custom::Conversations::PermissionFilterService
  def perform
    exclude_segregated_conversations(super)
  end

  private

  def exclude_segregated_conversations(scope)
    return scope if administrator? || agent_bot?
    return scope if forbidden_labels.empty?

    hidden_ids = account.conversations.tagged_with(forbidden_labels, any: true).pluck(:id)
    scope.where.not(id: hidden_ids)
  end

  def segregated_labels
    account&.teams&.pluck(:name) || []
  end

  # The labels this user is NOT exempt from -- an account team name, but matching none of
  # their own teams. An admin or agent bot never reaches this (short-circuited above);
  # everyone else loses visibility of exactly these.
  def forbidden_labels
    segregated_labels - exempt_labels
  end

  def exempt_labels
    user.teams.where(account_id: account&.id).pluck(:name) & segregated_labels
  end

  def administrator?
    account_user&.administrator?
  end

  def agent_bot?
    user.is_a?(AgentBot)
  end
end

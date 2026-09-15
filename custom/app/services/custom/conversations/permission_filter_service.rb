# Arcaconsult: the counterpart to custom/app/policies/custom/conversation_policy.rb --
# that file only gates opening ONE conversation (Pundit's `show?`, e.g. GET /conversations/:id).
# The sidebar list (Minhas / Não atribuídas / Todos, and the unread badge counts) is built by
# a completely different path -- ConversationFinder calls this class directly, which never
# consults ConversationPolicy at all. Without this file, a segregated-label conversation was
# still fully blocked if opened directly, but kept showing up in the list, which is how this
# gap first got caught: labeling a conversation "financeiro" hid it from nothing in the UI a
# non-Financeiro agent actually uses day to day.
#
# Same rule as the ConversationPolicy patch, restated at the query level instead of per
# record: once a conversation carries one of SEGREGATED_LABELS, only administrators, agent
# bots, and members of the identically-named team keep seeing it in lists and counts. See the
# long comment in conversation_policy.rb for why this lives here instead of as a Custom Role,
# and why Team#name / Label#title being downcased means the lowercase list below is not a
# style choice.
#
# `super` runs first every time, so this only ever narrows further whatever the base class
# (administrator short-circuit) or Enterprise::Conversations::PermissionFilterService (Custom
# Role filtering) already decided -- same "can only take away" contract as the show? patch.
module Custom::Conversations::PermissionFilterService
  SEGREGATED_LABELS = %w[financeiro suporte comercial].freeze

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

  # The labels this user is NOT exempt from -- present on the account's segregation list, but
  # matching none of their teams. An admin or agent bot never reaches this (short-circuited
  # above); everyone else loses visibility of exactly these.
  def forbidden_labels
    SEGREGATED_LABELS - exempt_labels
  end

  def exempt_labels
    user.teams.where(account_id: account&.id).pluck(:name) & SEGREGATED_LABELS
  end

  def administrator?
    account_user&.administrator?
  end

  def agent_bot?
    user.is_a?(AgentBot)
  end
end

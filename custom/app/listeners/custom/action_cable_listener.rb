# Arcaconsult: closes the real-time (WebSocket) side of the same gap the other two
# custom/ files close for direct access and for the sidebar list. Every one of these five
# events currently broadcasts the FULL conversation payload straight to
# `conversation.inbox.members` with no authorization check at all -- CE's own
# ActionCableListener was written on the assumption "an inbox member may see everything
# in that inbox", which our label-based segregation breaks. Without this file, a browser
# that already has the dashboard open receives the push the instant a segregating label is
# added or a segregated conversation is resolved, regardless of what ConversationPolicy or
# PermissionFilterService would say if asked -- neither of them sits anywhere on this path.
#
# Same dynamic rule as the other two custom/ files: the segregated-label set is not a fixed
# list, it is read live from `account.teams` on every call. See the long comment in
# conversation_policy.rb for what that trades away (any team name automatically starts
# restricting a same-named label, no separate review step) and why it was chosen anyway.
#
# Scope, deliberately narrowed: this only overrides the five handlers whose payload
# actually reaches what an agent sees in the sidebar/conversation header (created, updated,
# status_changed, assignee_changed, team_changed). Left untouched on purpose: typing
# indicators (carry no conversation content, only an id), unread-count broadcasts, message
# created/updated, and scheduled/recurring-message events. Those still broadcast unfiltered
# to inbox members; the residual exposure is a message body reaching an already-open old
# tab for a conversation that was visible when that tab loaded, which is narrower and lower
# stakes than the two bugs this patch was written for. Revisit if that stops being true.
#
# ActionCableListener is a de-facto singleton (BaseListener `include Singleton`, and Ruby's
# Singleton module makes the *subclass* single-instance too, not just the class that
# declared it) -- ONE shared instance handles every event for the whole process, so nothing
# here may stash conversation context in an instance variable to hand off between methods:
# two unrelated events could interleave and cross-contaminate each other's filter. Every
# value `visible_user_tokens` needs comes in through its own arguments and is computed
# fresh on each call, same as the show?/PermissionFilterService patches' "no shared state"
# rule, just restated for a class where breaking it would be a concurrency bug rather than
# a subtler correctness one.
#
# Both Team#name and Label#title are downcased by their own model callbacks before saving
# (before_validation), so comparing them directly (no explicit .downcase needed on either
# side) is correct by construction.
module Custom::ActionCableListener
  include Events::Types

  def conversation_created(event)
    conversation, account = extract_conversation_and_account(event)
    payload = conversation.push_event_data

    broadcast(account, visible_user_tokens(account, conversation), CONVERSATION_CREATED, payload)
    broadcast_to_contact(account, conversation, CONVERSATION_CREATED, payload)
  end

  def conversation_status_changed(event)
    conversation, account = extract_conversation_and_account(event)
    payload = conversation.push_event_data

    broadcast(account, visible_user_tokens(account, conversation), CONVERSATION_STATUS_CHANGED, payload)
    broadcast_to_contact(account, conversation, CONVERSATION_STATUS_CHANGED, payload)
  end

  def conversation_updated(event)
    conversation, account = extract_conversation_and_account(event)

    payload = conversation.push_event_data
    metadata = event.data[:broadcast_metadata]
    payload = payload.merge(event_metadata: metadata) if metadata.present?

    broadcast(account, visible_user_tokens(account, conversation), CONVERSATION_UPDATED, payload)
    broadcast_to_contact(account, conversation, CONVERSATION_UPDATED, payload)
  end

  def assignee_changed(event)
    conversation, account = extract_conversation_and_account(event)

    broadcast(account, visible_user_tokens(account, conversation), ASSIGNEE_CHANGED, conversation.push_event_data)
  end

  def team_changed(event)
    conversation, account = extract_conversation_and_account(event)

    broadcast(account, visible_user_tokens(account, conversation), TEAM_CHANGED, conversation.push_event_data)
  end

  private

  # `user_tokens` (CE, untouched) already adds every administrator's token unconditionally
  # -- since we only ever remove tokens belonging to `conversation.inbox.members`, and an
  # administrator's own membership token is never the one added on their behalf here, this
  # can never end up subtracting an administrator's access. Agent bots are not Inbox
  # `members` (that association is User-only), so they never appear in `tokens` via this
  # path and need no separate exemption the way the other two files require one.
  def visible_user_tokens(account, conversation)
    tokens = user_tokens(account, conversation.inbox.members)

    account_team_names = account.teams.pluck(:name)
    matching_labels = conversation.cached_label_list_array & account_team_names
    return tokens if matching_labels.empty?

    excluded_tokens = conversation.inbox.members.reject do |member|
      account_user = AccountUser.find_by(account_id: account.id, user_id: member.id)
      next true if account_user&.administrator?

      (member.teams.where(account_id: account.id).pluck(:name) & matching_labels).any?
    end.map(&:pubsub_token)

    notify_excluded_agents(account, conversation, excluded_tokens)

    tokens - excluded_tokens
  end

  # A stale copy left in an excluded agent's already-open sidebar cannot be fixed by simply
  # not sending them further updates about it (what `tokens - excluded_tokens` above
  # achieves on its own) -- the browser just keeps showing whatever it last knew, until the
  # agent switches tabs/filters or reloads. This sends the ones who just lost access a
  # separate, minimal signal to drop it from their local list immediately.
  #
  # 'conversation.removed' is not a registered Events::Types constant (no CE code emits or
  # listens for it) because it doesn't need to be -- ActionCableBroadcastJob only special-
  # cases event names it recognises (CONVERSATION_UPDATE_EVENTS, which rebuilds the payload
  # from a fresh read); anything else, this included, passes through exactly as given. The
  # payload carries nothing but the id the recipient's browser already has from before this
  # conversation became segregated, so this discloses nothing new. The matching frontend
  # handler lives in app/javascript/dashboard/helper/actionCable.js (outside custom/ -- see
  # that file's own comment for why this is the one part of the fix that isn't).
  def notify_excluded_agents(account, conversation, excluded_tokens)
    return if excluded_tokens.empty?

    broadcast(account, excluded_tokens, 'conversation.removed', { id: conversation.display_id })
  end
end

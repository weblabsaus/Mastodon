# frozen_string_literal: true

class Vacuum::InvitesVacuum
  def initialize(retention_period, max_uses)
    @retention_period = retention_period
    @max_uses = max_uses
  end

  def perform
    expire_invites! if retention_period?
  end

  private

  def expire_invites!
    invites = Invite.where('created_at < ?', retention_period.ago)
    invites = if max_uses.nil?
                invites.where(max_uses: nil)
              else
                invites.where('max_uses > ? OR max_uses IS NULL', max_uses)
              end

    invites.reorder(nil).in_batches(&:expire!)
  end
end

# frozen_string_literal: true

class ActivityPub::ActivityPresenter < ActiveModelSerializers::Model
  attributes :id, :type, :actor, :published, :to, :cc, :virtual_object, :collection_synchronization

  class << self
    def from_status(status, synchronization_domain: nil)
      new.tap do |presenter|
        presenter.id        = ActivityPub::TagManager.instance.activity_uri_for(status)
        presenter.type      = status.reblog? ? 'Announce' : 'Create'
        presenter.actor     = ActivityPub::TagManager.instance.uri_for(status.account)
        presenter.published = status.created_at
        presenter.to        = ActivityPub::TagManager.instance.to(status)
        presenter.cc        = ActivityPub::TagManager.instance.cc(status)

        presenter.collection_synchronization = begin
          if synchronization_domain.nil?
            nil
          else
            [
              ActivityPub::SynchronizationItemPresenter.new(
                domain: synchronization_domain,
                digest: status.account.followers_hash(synchronization_domain),
                account: status.account
              ),
            ]
          end
        end

        presenter.virtual_object = begin
          if status.reblog?
            if status.account == status.proper.account && status.proper.private_visibility? && status.local?
              status.proper
            else
              ActivityPub::TagManager.instance.uri_for(status.proper)
            end
          else
            status.proper
          end
        end
      end
    end

    def from_encrypted_message(encrypted_message)
      new.tap do |presenter|
        presenter.id = ActivityPub::TagManager.instance.generate_uri_for(nil)
        presenter.type = 'Create'
        presenter.actor = ActivityPub::TagManager.instance.uri_for(encrypted_message.source_account)
        presenter.published = Time.now.utc
        presenter.to = ActivityPub::TagManager.instance.uri_for(encrypted_message.target_account)
        presenter.virtual_object = encrypted_message
      end
    end
  end
end

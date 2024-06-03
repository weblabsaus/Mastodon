# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Notification do
  describe '#target_status' do
    let(:notification) { Fabricate(:notification, activity: activity) }
    let(:status)       { Fabricate(:status) }
    let(:reblog)       { Fabricate(:status, reblog: status) }
    let(:favourite)    { Fabricate(:favourite, status: status) }
    let(:mention)      { Fabricate(:mention, status: status) }

    context 'when Activity is reblog' do
      let(:activity) { reblog }

      it 'returns status' do
        expect(notification.target_status).to eq status
      end
    end

    context 'when Activity is favourite' do
      let(:type)     { :favourite }
      let(:activity) { favourite }

      it 'returns status' do
        expect(notification.target_status).to eq status
      end
    end

    context 'when Activity is mention' do
      let(:activity) { mention }

      it 'returns status' do
        expect(notification.target_status).to eq status
      end
    end
  end

  describe '#type' do
    it 'returns :reblog for a Status' do
      notification = described_class.new(activity: Status.new)
      expect(notification.type).to eq :reblog
    end

    it 'returns :mention for a Mention' do
      notification = described_class.new(activity: Mention.new)
      expect(notification.type).to eq :mention
    end

    it 'returns :favourite for a Favourite' do
      notification = described_class.new(activity: Favourite.new)
      expect(notification.type).to eq :favourite
    end

    it 'returns :follow for a Follow' do
      notification = described_class.new(activity: Follow.new)
      expect(notification.type).to eq :follow
    end
  end

  describe 'Setting account from activity_type' do
    context 'when activity_type is a Status' do
      it 'sets the notification from_account correctly' do
        status = Fabricate(:status)

        notification = Fabricate.build(:notification, activity_type: 'Status', activity: status)

        expect(notification.from_account).to eq(status.account)
      end
    end

    context 'when activity_type is a Follow' do
      it 'sets the notification from_account correctly' do
        follow = Fabricate(:follow)

        notification = Fabricate.build(:notification, activity_type: 'Follow', activity: follow)

        expect(notification.from_account).to eq(follow.account)
      end
    end

    context 'when activity_type is a Favourite' do
      it 'sets the notification from_account correctly' do
        favourite = Fabricate(:favourite)

        notification = Fabricate.build(:notification, activity_type: 'Favourite', activity: favourite)

        expect(notification.from_account).to eq(favourite.account)
      end
    end

    context 'when activity_type is a FollowRequest' do
      it 'sets the notification from_account correctly' do
        follow_request = Fabricate(:follow_request)

        notification = Fabricate.build(:notification, activity_type: 'FollowRequest', activity: follow_request)

        expect(notification.from_account).to eq(follow_request.account)
      end
    end

    context 'when activity_type is a Poll' do
      it 'sets the notification from_account correctly' do
        poll = Fabricate(:poll)

        notification = Fabricate.build(:notification, activity_type: 'Poll', activity: poll)

        expect(notification.from_account).to eq(poll.account)
      end
    end

    context 'when activity_type is a Report' do
      it 'sets the notification from_account correctly' do
        report = Fabricate(:report)

        notification = Fabricate.build(:notification, activity_type: 'Report', activity: report)

        expect(notification.from_account).to eq(report.account)
      end
    end

    context 'when activity_type is a Mention' do
      it 'sets the notification from_account correctly' do
        mention = Fabricate(:mention)

        notification = Fabricate.build(:notification, activity_type: 'Mention', activity: mention)

        expect(notification.from_account).to eq(mention.status.account)
      end
    end

    context 'when activity_type is an Account' do
      it 'sets the notification from_account correctly' do
        account = Fabricate(:account)

        notification = Fabricate.build(:notification, activity_type: 'Account', account: account)

        expect(notification.account).to eq(account)
      end
    end

    context 'when activity_type is an AccountWarning' do
      it 'sets the notification from_account to the recipient of the notification' do
        account = Fabricate(:account)
        account_warning = Fabricate(:account_warning, target_account: account)

        notification = Fabricate.build(:notification, activity_type: 'AccountWarning', activity: account_warning, account: account)

        expect(notification.from_account).to eq(account)
      end
    end
  end

  context 'with grouped notifications' do
    let(:account) { Fabricate(:account) }

    let!(:group_one_oldest) { Fabricate(:notification, account: account, group_key: 'group-1') }
    let!(:group_one_old) { Fabricate(:notification, account: account, group_key: 'group-1') }
    let!(:group_nil_old) { Fabricate(:notification, account: account, group_key: nil) }
    let!(:group_two_old) { Fabricate(:notification, account: account, group_key: 'group-2') }
    let!(:group_nil_new) { Fabricate(:notification, account: account, group_key: nil) }
    let!(:group_one_new) { Fabricate(:notification, account: account, group_key: 'group-1') }
    let!(:group_two_new) { Fabricate(:notification, account: account, group_key: 'group-2') }
    let!(:group_one_newest) { Fabricate(:notification, account: account, group_key: 'group-1') }

    describe '.paginate_groups_by_max_id' do
      context 'without since_id or max_id' do
        it 'returns the most recent notifications, only keeping one notification per group' do
          expect(described_class.without_suspended.paginate_groups_by_max_id(4))
            .to eq [group_one_newest, group_two_new, group_nil_new, group_nil_old]
        end
      end

      context 'with since_id' do
        it 'returns the most recent notifications, only keeping one notification per group' do
          expect(described_class.without_suspended.paginate_groups_by_max_id(4, since_id: group_nil_new.id))
            .to eq [group_one_newest, group_two_new]
        end
      end

      context 'with max_id' do
        it 'returns the most recent notifications after max_id, only keeping one notification per group' do
          expect(described_class.without_suspended.paginate_groups_by_max_id(4, max_id: group_one_newest.id))
            .to eq [group_two_new, group_one_new, group_nil_new, group_nil_old]
        end
      end
    end

    describe '.paginate_groups_by_min_id' do
      context 'without min_id or max_id' do
        it 'returns the oldest notifications, only keeping one notification per group' do
          expect(described_class.without_suspended.paginate_groups_by_min_id(4))
            .to eq [group_one_oldest, group_nil_old, group_two_old, group_nil_new]
        end
      end

      context 'with max_id' do
        it 'returns the oldest notifications, stopping at max_id, only keeping one notification per group' do
          expect(described_class.without_suspended.paginate_groups_by_min_id(4, max_id: group_nil_new.id))
            .to eq [group_one_oldest, group_nil_old, group_two_old]
        end
      end

      context 'with min_id' do
        it 'returns the most oldest notifications after min_id, only keeping one notification per group' do
          expect(described_class.without_suspended.paginate_groups_by_min_id(4, min_id: group_one_oldest.id))
            .to eq [group_one_old, group_nil_old, group_two_old, group_nil_new]
        end
      end
    end
  end

  describe '.preload_cache_collection_target_statuses' do
    subject do
      described_class.preload_cache_collection_target_statuses(notifications) do |target_statuses|
        # preload account for testing instead of using cache_collection
        Status.preload(:account).where(id: target_statuses.map(&:id))
      end
    end

    context 'when notifications are empty' do
      let(:notifications) { [] }

      it 'returns []' do
        expect(subject).to eq []
      end
    end

    context 'when notifications are present' do
      before do
        notifications.each(&:reload)
      end

      let(:mention) { Fabricate(:mention) }
      let(:status) { Fabricate(:status) }
      let(:reblog) { Fabricate(:status, reblog: Fabricate(:status)) }
      let(:follow) { Fabricate(:follow) }
      let(:follow_request) { Fabricate(:follow_request) }
      let(:favourite) { Fabricate(:favourite) }
      let(:poll) { Fabricate(:poll) }

      let(:notifications) do
        [
          Fabricate(:notification, type: :mention, activity: mention),
          Fabricate(:notification, type: :status, activity: status),
          Fabricate(:notification, type: :reblog, activity: reblog),
          Fabricate(:notification, type: :follow, activity: follow),
          Fabricate(:notification, type: :follow_request, activity: follow_request),
          Fabricate(:notification, type: :favourite, activity: favourite),
          Fabricate(:notification, type: :poll, activity: poll),
        ]
      end

      context 'with a preloaded target status' do
        it 'preloads mention' do
          expect(subject[0].type).to eq :mention
          expect(subject[0].association(:mention)).to be_loaded
          expect(subject[0].mention.association(:status)).to be_loaded
        end

        it 'preloads status' do
          expect(subject[1].type).to eq :status
          expect(subject[1].association(:status)).to be_loaded
        end

        it 'preloads reblog' do
          expect(subject[2].type).to eq :reblog
          expect(subject[2].association(:status)).to be_loaded
          expect(subject[2].status.association(:reblog)).to be_loaded
        end

        it 'preloads follow as nil' do
          expect(subject[3].type).to eq :follow
          expect(subject[3].target_status).to be_nil
        end

        it 'preloads follow_request as nill' do
          expect(subject[4].type).to eq :follow_request
          expect(subject[4].target_status).to be_nil
        end

        it 'preloads favourite' do
          expect(subject[5].type).to eq :favourite
          expect(subject[5].association(:favourite)).to be_loaded
          expect(subject[5].favourite.association(:status)).to be_loaded
        end

        it 'preloads poll' do
          expect(subject[6].type).to eq :poll
          expect(subject[6].association(:poll)).to be_loaded
          expect(subject[6].poll.association(:status)).to be_loaded
        end
      end

      context 'with a cached status' do
        it 'replaces mention' do
          expect(subject[0].type).to eq :mention
          expect(subject[0].target_status.association(:account)).to be_loaded
          expect(subject[0].target_status).to eq mention.status
        end

        it 'replaces status' do
          expect(subject[1].type).to eq :status
          expect(subject[1].target_status.association(:account)).to be_loaded
          expect(subject[1].target_status).to eq status
        end

        it 'replaces reblog' do
          expect(subject[2].type).to eq :reblog
          expect(subject[2].target_status.association(:account)).to be_loaded
          expect(subject[2].target_status).to eq reblog.reblog
        end

        it 'replaces follow' do
          expect(subject[3].type).to eq :follow
          expect(subject[3].target_status).to be_nil
        end

        it 'replaces follow_request' do
          expect(subject[4].type).to eq :follow_request
          expect(subject[4].target_status).to be_nil
        end

        it 'replaces favourite' do
          expect(subject[5].type).to eq :favourite
          expect(subject[5].target_status.association(:account)).to be_loaded
          expect(subject[5].target_status).to eq favourite.status
        end

        it 'replaces poll' do
          expect(subject[6].type).to eq :poll
          expect(subject[6].target_status.association(:account)).to be_loaded
          expect(subject[6].target_status).to eq poll.status
        end
      end
    end
  end
end
